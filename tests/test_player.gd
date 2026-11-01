extends TestCase
## Tests for the player: rules, input mapping, marble physics, start from the editor, independence from the editor.

const PHYSICS_FPS := 60.0
## Sources that the published player build contains: they must not use editor classes.
const PLAYER_DIRS: Array[String] = ["res://scripts/game", "res://scripts/view", "res://scripts/geometry", "res://scripts/core"]
const EDITOR_CLASSES: Array[String] = ["EditorRoot", "EditorState", "EditorUI", "GridLines", "Tools"]


## Builds a level with a flat 5x5 floor at height 2, a start at (1,1) and optional extra blocks.
func _floor_level(extra: Array = []) -> LevelData:
	var level := LevelData.new()
	for x in range(5):
		for z in range(5):
			level.set_block(x, z, BlockData.make(x, z, {"elevation": 2.0}))
	level.get_block(1, 1)["element"] = "marble_start"
	for b in extra: level.set_block(b["bx"], b["bz"], b)
	return level


## Adds a player to the tree and returns it.
func _start_player(level: LevelData) -> PlayerRoot:
	var player := PlayerRoot.new()
	player.setup(level, true)
	tree.root.add_child(player)
	return player


## Waits a number of physics frames.
func _steps(count: int) -> void:
	for i in range(count): await tree.physics_frame


## Removes a player from the tree and releases all keys.
func _finish(player: PlayerRoot) -> void:
	for action in PlayerInput.BINDINGS: Input.action_release(action)
	player.free()


## The start is at the block center, above its surface; a level without start has none.
func test_start_position() -> void:
	var pos := LevelRules.start_position(_floor_level(), 0.5)
	assert_near(pos.x, 4.5, 0.001, "x")
	assert_near(pos.z, 4.5, 0.001, "z")
	assert_near(pos.y, 2.5 + LevelRules.START_LIFT, 0.001, "y")
	assert_eq(LevelRules.start_position(LevelData.new(), 0.5), Vector3.INF, "no start")


## The fall limit is below the lowest block, and never above the margin below zero.
func test_fall_limit() -> void:
	assert_near(LevelRules.fall_limit(_floor_level()), -LevelRules.FALL_MARGIN, 0.001, "positive heights")
	var level := _floor_level([BlockData.make(4, 4, {"elevation": -3.0})])
	assert_near(LevelRules.fall_limit(level), -3.0 - LevelRules.FALL_MARGIN, 0.001, "negative height")


## A goal counts only on its own cell and close to its surface.
func test_is_on_goal() -> void:
	var level := _floor_level([BlockData.make(3, 3, {"elevation": 2.0, "element": "goal_flags"})])
	assert_true(LevelRules.is_on_goal(level, Vector3(10.5, 2.5, 10.5)), "on goal")
	assert_true(not LevelRules.is_on_goal(level, Vector3(10.5, 9.0, 10.5)), "flying over")
	assert_true(not LevelRules.is_on_goal(level, Vector3(7.5, 2.5, 7.5)), "other cell")
	assert_true(not LevelRules.is_on_goal(level, Vector3(-1.0, 2.5, 100.0)), "outside")


## Every WASD and arrow key is bound, and steering is at most length 1.
func test_input_actions() -> void:
	PlayerInput.ensure_actions()
	for action in [PlayerInput.LEFT, PlayerInput.RIGHT, PlayerInput.UP, PlayerInput.DOWN]:
		assert_eq(InputMap.action_get_events(action).size(), 2, "two keys for %s" % action)
	Input.action_press(PlayerInput.UP)
	Input.action_press(PlayerInput.RIGHT)
	var steer := PlayerInput.steer_vector()
	Input.action_release(PlayerInput.UP)
	Input.action_release(PlayerInput.RIGHT)
	assert_near(steer.length(), 1.0, 0.001, "diagonal length")
	assert_true(steer.x > 0.0 and steer.y > 0.0, "right and forward")


## Forward follows the camera: it moves away from the viewer on the ground, whatever the pitch.
func test_world_direction_follows_camera() -> void:
	var from := Vector3(10.0, 10.0, 10.0)
	var cam := Basis.looking_at(-from, Vector3.UP)
	var forward := PlayerInput.world_direction(Vector2(0.0, 1.0), cam)
	assert_near(forward.y, 0.0, 0.001, "on the ground")
	assert_near(forward.x, -sqrt(0.5), 0.001, "forward x")
	assert_near(forward.z, -sqrt(0.5), 0.001, "forward z")
	var right := PlayerInput.world_direction(Vector2(1.0, 0.0), cam)
	assert_near(right.dot(forward), 0.0, 0.001, "right is perpendicular")
	assert_near(right.x, sqrt(0.5), 0.001, "right x")


## The marble rests on the floor, instead of falling through it.
func test_marble_rests_on_floor() -> void:
	var player := _start_player(_floor_level())
	await _steps(int(PHYSICS_FPS))
	assert_near(player.marble.global_position.y, 2.0 + Marble.RADIUS, 0.03, "rest height")
	assert_eq(player.falls, 0, "no falls")
	_finish(player)


## A steering key moves the marble in the direction shown by the camera.
func test_key_moves_marble() -> void:
	var player := _start_player(_floor_level())
	await _steps(10)
	var before := player.marble.global_position
	Input.action_press(PlayerInput.UP)
	await _steps(20)
	var cam := player.rig.current_camera().global_transform.basis
	var moved := player.marble.global_position - before
	assert_true(moved.length() > 0.1, "moved %s" % str(moved))
	assert_true(moved.dot(PlayerInput.world_direction(Vector2(0.0, 1.0), cam)) > 0.0, "moved forward")
	_finish(player)


## Dragging with the mouse rotates the view and changes what forward means.
func test_mouse_rotates_view() -> void:
	var player := _start_player(_floor_level())
	await _steps(1)
	var before := player.rig.current_camera().global_transform.basis
	var drag := InputEventMouseMotion.new()
	drag.button_mask = MOUSE_BUTTON_MASK_LEFT
	drag.relative = Vector2(200.0, 0.0)
	player._unhandled_input(drag)
	var after := player.rig.current_camera().global_transform.basis
	var old_forward := PlayerInput.world_direction(Vector2(0.0, 1.0), before)
	var new_forward := PlayerInput.world_direction(Vector2(0.0, 1.0), after)
	assert_true(old_forward.dot(new_forward) < 0.9, "forward rotated")
	_finish(player)


## Off the edge the marble falls, then comes back to the start with one fall counted.
func test_fall_respawns_at_start() -> void:
	var player := _start_player(_floor_level())
	await _steps(5)
	player.marble.place_at(Vector3(40.0, 0.0, 40.0))
	await _steps(int(PHYSICS_FPS * 2.0))
	assert_eq(player.falls, 1, "one fall")
	assert_true(player.marble.global_position.distance_to(player._start) < 3.0, "back at the start")
	_finish(player)


## Reaching the goal stops the time and shows it; restart begins a new run.
func test_goal_wins_and_restart() -> void:
	var level := _floor_level([BlockData.make(3, 3, {"elevation": 2.0, "element": "goal_flags"})])
	var player := _start_player(level)
	await _steps(5)
	player.marble.place_at(Vector3(10.5, 3.0, 10.5))
	await _steps(3)
	assert_eq(player.phase, PlayerRoot.Phase.WON, "won")
	var time_at_win := player.elapsed
	assert_true(player.hud.message().contains(PlayerHud.format_time(time_at_win)), "time shown")
	await _steps(5)
	assert_eq(player.elapsed, time_at_win, "time stopped")
	player.restart()
	assert_eq(player.phase, PlayerRoot.Phase.PLAYING, "playing again")
	assert_eq(player.hud.message(), "", "message cleared")
	_finish(player)


## Tubes and cones stop the marble: their colliders exist, flags and start marble have none.
func test_solid_elements() -> void:
	var tube := BlockData.make(0, 0, {"elevation": 2.0, "element": "tube_straight"})
	var cone := BlockData.make(1, 0, {"elevation": 2.0, "element": "cone_large"})
	var flags := BlockData.make(2, 0, {"elevation": 2.0, "element": "goal_flags"})
	var start := BlockData.make(3, 0, {"elevation": 2.0, "element": "marble_start"})
	for entry in [[tube, true], [cone, true], [flags, false], [start, false]]:
		var element := ElementBuilder.build(entry[0])
		var solid := not ElementBuilder.collision_faces(element, entry[0]).is_empty()
		assert_eq(solid, entry[1], "solid %s" % entry[0]["element"])
		element.free()


## A guard tube stops a fast marble instead of letting it climb over.
func test_tube_stops_marble() -> void:
	var player := _start_player(_floor_level([BlockData.make(2, 1, {"elevation": 2.0, "element": "tube_straight"})]))
	await _steps(10)
	player.marble.linear_velocity = Vector3(8.0, 0.0, 0.0)
	await _steps(int(PHYSICS_FPS))
	assert_true(player.marble.global_position.x < 6.18, "stopped by the rail at x=%s" % player.marble.global_position.x)
	_finish(player)


## A level without a start shows an error and creates no marble.
func test_level_without_start_shows_error() -> void:
	var level := LevelData.new()
	level.set_block(0, 0, BlockData.make(0, 0, {}))
	var player := _start_player(level)
	assert_true(player.marble == null, "no marble")
	assert_eq(player.hud.message(), I18n.t("play_err_no_start"), "error shown")
	_finish(player)


## The standalone scene loads the bundled level by itself.
func test_standalone_scene_loads_level() -> void:
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as PlayerRoot
	tree.root.add_child(player)
	assert_true(player.marble != null, "marble")
	assert_true(player.level.blocks.size() > 0, "level loaded")
	assert_eq(player.phase, PlayerRoot.Phase.PLAYING, "playing")
	var marble_node := player.view.block_node(1, 1).get_node("Element/Marble") as Node3D
	assert_true(not marble_node.visible, "static marble hidden")
	_finish(player)


## Play from the editor runs its current level, edits included, and Esc comes back with everything intact.
func test_play_from_editor_and_back() -> void:
	var editor := (load("res://scenes/editor.tscn") as PackedScene).instantiate() as EditorRoot
	tree.root.add_child(editor)
	editor.level.copy_from(_floor_level())
	editor.view.rebuild_all()
	editor.history.push(editor.level)
	var player := editor.start_play()
	assert_true(player != null, "player started")
	assert_true(not editor.is_inside_tree(), "editor out of the tree")
	assert_eq(tree.current_scene, player, "current scene")
	assert_eq(player.level.blocks.size(), 25, "edited level")
	assert_true(player.level != editor.level, "plays a copy")
	assert_true(editor.start_play() == null, "cannot start twice")
	await _steps(2)
	player.exit_requested.emit()
	assert_true(editor.is_inside_tree(), "editor back")
	assert_eq(tree.current_scene, editor, "editor is the scene")
	assert_true(editor.history.can_undo(), "undo history kept")
	assert_true(editor.rig.current_camera().current, "editor camera active")
	await tree.process_frame
	editor.free()


## Sources that ship in the player do not use editor classes.
func test_player_does_not_use_editor() -> void:
	for dir_path in PLAYER_DIRS:
		for file_name in DirAccess.get_files_at(dir_path):
			if not file_name.ends_with(".gd"): continue
			var source := FileAccess.get_file_as_string("%s/%s" % [dir_path, file_name])
			for cls in EDITOR_CLASSES:
				assert_true(not RegEx.create_from_string("\\b%s\\b" % cls).search(source), "%s uses %s" % [file_name, cls])
