class_name PlayerRoot
extends Node3D
## Root of the player: runs a level given by the editor, or loads one when started as an app.
## Must not reference editor classes: the published build does not contain them.

## Emitted when the player asks to go back to the editor (only when started from it).
signal exit_requested

## Game phases.
enum Phase { NO_LEVEL, PLAYING, WON }

## Level played by the standalone app. Replace this file to publish another level.
const DEFAULT_LEVEL_PATH := "res://data/level01.json"
## User argument choosing another level file on desktop: -- --level=path.
const LEVEL_ARG_PREFIX := "--level="
## Wheel steps of the initial zoom: closer than the editor view, which shows the whole level.
const START_ZOOM_STEPS := 6.0

## The level being played; null until it is set or loaded.
var level: LevelData = null
## Current phase.
var phase := Phase.NO_LEVEL
## Seconds since the last restart.
var elapsed := 0.0
## Times the marble fell since the last restart.
var falls := 0
## Marble body; null without a playable level.
var marble: Marble = null
## Renders the level and its colliders.
var view := LevelView.new()
## Camera following the marble.
var rig := CameraRig.new()
## Overlay.
var hud: PlayerHud

var _from_editor := false
var _start := Vector3.INF
var _fall_limit := 0.0


## Sets the level to play; call before adding the player to the tree.
func setup(new_level: LevelData, from_editor: bool) -> void:
	level = new_level
	_from_editor = from_editor


## Loads the level when needed, then builds the world, or shows why it cannot start.
func _ready() -> void:
	PlayerInput.ensure_actions()
	if not _from_editor: I18n.set_language(OS.get_locale_language())
	hud = PlayerHud.new(_from_editor)
	add_child(hud)
	LevelEnvironment.add_to(self)
	rig.name = "CameraRig"
	add_child(rig)
	rig.zoom(START_ZOOM_STEPS)
	if level == null and not _load_standalone_level(): return
	view.name = "LevelView"
	view.solid_elements = true
	add_child(view)
	view.bind(level)
	_start = LevelRules.start_position(level, Marble.RADIUS)
	if _start == Vector3.INF:
		hud.set_message(I18n.t("play_err_no_start"))
		return
	_hide_static_marbles()
	_fall_limit = LevelRules.fall_limit(level)
	var start_cell: Vector2i = LevelRules.cells_with_element(level, LevelRules.START_ELEMENT)[0]
	marble = Marble.new(level.get_block(start_cell.x, start_cell.y).get("marbleColor"))
	add_child(marble)
	restart()


## Starts the level over: marble at the start, time and falls at zero.
func restart() -> void:
	if marble == null: return
	phase = Phase.PLAYING
	elapsed = 0.0
	falls = 0
	marble.place_at(_start)
	hud.set_message("")
	hud.set_status(elapsed, falls)


## Reads the steering, applies the rules and moves the camera.
func _physics_process(delta: float) -> void:
	if phase != Phase.PLAYING: return
	elapsed += delta
	var cam_basis := rig.current_camera().global_transform.basis
	marble.steer_direction = PlayerInput.world_direction(PlayerInput.steer_vector(), cam_basis)
	if marble.global_position.y < _fall_limit:
		falls += 1
		marble.place_at(_start)
	elif LevelRules.is_on_goal(level, marble.global_position):
		_win()
	hud.set_status(elapsed, falls)


## Keeps the camera on the marble.
func _process(_delta: float) -> void:
	if marble != null: rig.focus_on(marble.global_position)


## Rotates the view on a left drag (the rig handles the right drag) and handles restart and exit.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rig.orbit(event.relative)
	elif event.is_action_pressed(PlayerInput.RESTART, false, true):
		restart()
	elif event.is_action_pressed(PlayerInput.EXIT, false, true) and _from_editor:
		exit_requested.emit()


## Ends the run and shows the time.
func _win() -> void:
	phase = Phase.WON
	marble.steer_direction = Vector3.ZERO
	hud.set_message("%s\n%s" % [I18n.t("play_won"), PlayerHud.format_time(elapsed)])


## Loads the level of the standalone app. Shows the error and returns false on failure.
func _load_standalone_level() -> bool:
	var path := DEFAULT_LEVEL_PATH
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with(LEVEL_ARG_PREFIX): path = arg.trim_prefix(LEVEL_ARG_PREFIX)
	var result := LevelIO.load_file(path)
	if result["ok"]:
		level = result["level"]
		return true
	hud.set_message("%s%s" % [I18n.t("err_invalid_json"), result["error"]])
	return false


## Hides the marble drawn by the start element, since the real one replaces it.
func _hide_static_marbles() -> void:
	for cell in LevelRules.cells_with_element(level, LevelRules.START_ELEMENT):
		var marble_node := view.block_node(cell.x, cell.y).get_node_or_null("%s/Marble" % LevelView.ELEMENT_NAME)
		if marble_node != null: marble_node.visible = false
