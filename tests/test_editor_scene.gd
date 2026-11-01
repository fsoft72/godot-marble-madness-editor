extends TestCase
## Smoke tests for the editor scene (EditorRoot and EditorUI wiring).

const SCENE_PATH := "res://scenes/editor.tscn"


## Instantiates the editor scene in the tree and waits a frame so _ready has run.
func _make_editor() -> EditorRoot:
	var root := (load(SCENE_PATH) as PackedScene).instantiate() as EditorRoot
	tree.root.add_child(root)
	await tree.process_frame
	return root


## Frees the scene and waits for the deletion to complete.
func _free_editor(root: EditorRoot) -> void:
	root.free()
	await tree.process_frame


## Builds a left mouse button event at a position.
func _click(pos: Vector2, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.position = pos
	ev.global_position = pos
	return ev


## The scene loads, paint_cell adds a block and the view builds its node.
func test_scene_loads_and_paints() -> void:
	var root := await _make_editor()
	assert_true(root.level != null and root.history != null and root.state != null, "core fields")
	assert_true(root.view != null and root.rig != null and root.ui != null, "node fields")
	assert_eq(root.level.cols, 14, "default cols")
	assert_eq(root.level.rows, 14, "default rows")
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(3, 4))
	assert_true(not root.level.get_block(3, 4).is_empty(), "block in level")
	assert_true(root.view.block_node(3, 4) != null, "block node built")
	await _free_editor(root)


## The camera focuses on the level center.
func test_camera_focus_is_level_center() -> void:
	var root := await _make_editor()
	var half := 14 * Constants.BLOCK_SIZE / 2.0
	var expected := Vector3(half, BlockData.defaults()["elevation"], half)
	assert_true(root.rig.focus.is_equal_approx(expected), "focus %s expected %s" % [root.rig.focus, expected])
	await _free_editor(root)


## Painting outside the grid pushes no snapshot.
func test_paint_outside_grid_is_ignored() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(40, 2))
	assert_true(not root.history.can_undo(), "no snapshot")
	await _free_editor(root)


## Buttons for later tasks exist and are disabled.
func test_later_task_buttons_disabled() -> void:
	var root := await _make_editor()
	for key in ["toggle_grid", "clear_map", "export_json", "load_preset", "lang_toggle_btn"]:
		var btn := root.ui.get_button(key)
		assert_true(btn != null and btn.disabled, "%s disabled" % key)
	await _free_editor(root)


## Tool buttons change the tool in the state.
func test_tool_button_selects_tool() -> void:
	var root := await _make_editor()
	root.ui.get_button("tool_erase").pressed.emit()
	assert_eq(root.state.tool, EditorState.Tool.ERASE, "erase tool")
	await _free_editor(root)


## Keys 1-5 select tools, Ctrl+Z undoes a paint, and a focused text field blocks shortcuts.
func test_keyboard_shortcuts() -> void:
	var root := await _make_editor()
	var key := InputEventKey.new()
	key.keycode = KEY_3
	key.pressed = true
	root._unhandled_key_input(key)
	assert_eq(root.state.tool, EditorState.Tool.PAINT_ELEMENT, "key 3")
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(1, 1))
	var undo := InputEventKey.new()
	undo.keycode = KEY_Z
	undo.ctrl_pressed = true
	undo.pressed = true
	root._unhandled_key_input(undo)
	assert_true(root.level.get_block(1, 1).is_empty(), "undone")
	assert_true(root.view.block_node(1, 1) == null, "node removed after undo")
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await tree.process_frame
	key.keycode = KEY_1
	root._unhandled_key_input(key)
	assert_eq(root.state.tool, EditorState.Tool.PAINT_BLOCK, "key ignored while typing")
	await _free_editor(root)


## A left drag over empty viewport paints several cells as a single undo step.
func test_drag_paint_is_one_undo_step() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	var cam := root.rig.current_camera()
	var cells: Array[Vector2i] = [Vector2i(5, 5), Vector2i(6, 5), Vector2i(7, 5)]
	var first := true
	for c in cells:
		var world := LevelView.grid_to_world(c.x, c.y) + Vector3(1.5, BlockData.defaults()["elevation"], 1.5)
		var pos := cam.unproject_position(world)
		if first:
			root._handle_mouse_button(_click(pos, true))
			first = false
		else:
			var motion := InputEventMouseMotion.new()
			motion.position = pos
			motion.global_position = pos
			motion.button_mask = MOUSE_BUTTON_MASK_LEFT
			root._handle_mouse_motion(motion)
	root._handle_mouse_button(_click(Vector2.ZERO, false))
	for c in cells:
		assert_true(not root.level.get_block(c.x, c.y).is_empty(), "painted %s" % c)
	assert_true(root.history.undo(root.level), "one undo")
	assert_true(not root.history.can_undo(), "only one snapshot")
	await _free_editor(root)


## An inspector slider commit on a selected block rebuilds it and pushes one snapshot.
func test_inspector_change_edits_selected_block() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.state.tool = EditorState.Tool.SELECT
	root.history = History.new()
	root.apply_inspector_value("elevation", 6.0)
	assert_near(root.level.get_block(2, 2)["elevation"], 6.0, 0.0001, "elevation applied")
	assert_true(root.history.can_undo(), "snapshot pushed")
	await _free_editor(root)


## The center of the window is not a UI control, the side panels and the top bar are.
func test_pointer_over_ui_detection() -> void:
	var old_size := tree.root.size
	tree.root.size = Vector2i(1152, 648)
	var root := await _make_editor()
	var size := tree.root.get_visible_rect().size
	var probes := {"center": [size / 2.0, false], "left panel": [Vector2(40, size.y / 2.0), true], "right panel": [Vector2(size.x - 40.0, size.y / 2.0), true], "top bar": [Vector2(size.x / 2.0, 10), true]}
	for label in probes:
		var motion := InputEventMouseMotion.new()
		motion.position = probes[label][0]
		motion.global_position = probes[label][0]
		tree.root.push_input(motion)
		await tree.process_frame
		assert_eq(root._pointer_over_ui(), probes[label][1], "over ui at %s: %s size %s" % [label, tree.root.gui_get_hovered_control(), size])
	await _free_editor(root)
	tree.root.size = old_size


## A second click on the active palette item rotates the brush by 90 degrees.
func test_second_palette_click_rotates() -> void:
	var root := await _make_editor()
	var cases := {"shape": ["pit", "rotation"], "element": ["tube_u", "elemRotation"], "decal": ["pad_456", "decalRotation"]}
	for kind in cases:
		var id: String = cases[kind][0]
		var prop: String = cases[kind][1]
		root.state.brush[prop] = 0
		root.apply_palette_pick(kind, id)
		assert_eq(root.state.brush[prop], 0, "%s first click keeps rotation" % kind)
		root.apply_palette_pick(kind, id)
		assert_eq(root.state.brush[prop], 90, "%s second click rotates" % kind)
		root.state.brush[prop] = 270
		root.apply_palette_pick(kind, id)
		assert_eq(root.state.brush[prop], 0, "%s wraps" % kind)
	await _free_editor(root)


## Returns the screen position of the center of a cell at the default elevation.
func _cell_pos(root: EditorRoot, cell: Vector2i) -> Vector2:
	var world := LevelView.grid_to_world(cell.x, cell.y) + Vector3(1.5, BlockData.defaults()["elevation"], 1.5)
	return root.rig.current_camera().unproject_position(world)


## Builds a left-drag motion event at a position.
func _drag_motion(pos: Vector2) -> InputEventMouseMotion:
	var motion := InputEventMouseMotion.new()
	motion.position = pos
	motion.global_position = pos
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	return motion


## An eraser stroke that starts on an empty cell still pushes one undo step when it erases.
func test_erase_drag_from_empty_cell_is_undoable() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(6, 5))
	root.paint_cell(Vector2i(7, 5))
	root.history = History.new()
	root.state.tool = EditorState.Tool.ERASE
	root._handle_mouse_button(_click(_cell_pos(root, Vector2i(5, 5)), true))
	root._handle_mouse_motion(_drag_motion(_cell_pos(root, Vector2i(6, 5))))
	root._handle_mouse_motion(_drag_motion(_cell_pos(root, Vector2i(7, 5))))
	root._handle_mouse_button(_click(Vector2.ZERO, false))
	assert_true(root.level.get_block(6, 5).is_empty() and root.level.get_block(7, 5).is_empty(), "erased")
	assert_true(root.history.undo(root.level), "erase stroke has a snapshot")
	assert_true(not root.level.get_block(6, 5).is_empty() and not root.level.get_block(7, 5).is_empty(), "restored by one undo")
	assert_true(not root.history.can_undo(), "exactly one snapshot")
	await _free_editor(root)


## A tool change or an undo ends the stroke so the drag no longer edits the level.
func test_stroke_ends_on_tool_change_and_undo() -> void:
	var root := await _make_editor()
	root._handle_mouse_button(_click(_cell_pos(root, Vector2i(5, 5)), true))
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root._handle_mouse_motion(_drag_motion(_cell_pos(root, Vector2i(6, 5))))
	assert_true(root.level.get_block(6, 5).is_empty(), "no paint after tool change")
	root._handle_mouse_button(_click(_cell_pos(root, Vector2i(5, 5)), true))
	root.undo()
	root._handle_mouse_motion(_drag_motion(_cell_pos(root, Vector2i(8, 5))))
	assert_true(root.level.get_block(8, 5).is_empty(), "no paint after undo")
	await _free_editor(root)


## Undo and redo re-sync the brush and the inspector with the selected block.
func test_undo_resyncs_inspector() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.state.tool = EditorState.Tool.SELECT
	root.apply_inspector_value("elevation", 6.0)
	assert_near(root.state.brush["elevation"], 6.0, 0.0001, "brush after edit")
	root.undo()
	var block_elevation: float = root.level.get_block(2, 2)["elevation"]
	assert_near(root.state.brush["elevation"], block_elevation, 0.0001, "brush after undo")
	assert_near(root.ui.get_slider("elevation").value, block_elevation, 0.0001, "slider after undo")
	root.redo()
	assert_near(root.state.brush["elevation"], 6.0, 0.0001, "brush after redo")
	await _free_editor(root)


## Presses the mouse as the UI sees it, and releases it.
func _ui_mouse(root: EditorRoot, pressed: bool) -> void:
	root.ui._input(_click(Vector2.ZERO, pressed))


## Pushes a mouse button event through the viewport so the GUI and the UI see it.
func _push_button(pos: Vector2, pressed: bool) -> void:
	tree.root.push_input(_click(pos, pressed))
	await tree.process_frame


## Pushes a left-drag motion event through the viewport.
func _push_motion(pos: Vector2) -> void:
	tree.root.push_input(_drag_motion(pos))
	await tree.process_frame


## One slider drag commits once, whatever the order of the slider signals.
func test_slider_drag_is_one_snapshot() -> void:
	var old_size := tree.root.size
	tree.root.size = Vector2i(1152, 648)
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.state.tool = EditorState.Tool.SELECT
	root.history = History.new()
	var slider := root.ui.get_slider("elevation")
	assert_true(not slider.scrollable, "slider ignores the wheel")
	var rect := slider.get_global_rect()
	var y := rect.position.y + rect.size.y / 2.0
	await _push_button(Vector2(rect.position.x + rect.size.x * 0.3, y), true)
	for f in [0.4, 0.5, 0.6]:
		await _push_motion(Vector2(rect.position.x + rect.size.x * f, y))
	await _push_button(Vector2(rect.position.x + rect.size.x * 0.6, y), false)
	assert_true(root.history.undo(root.level), "one snapshot")
	assert_true(not root.history.can_undo(), "not two")
	await _free_editor(root)
	tree.root.size = old_size


## Several sub-height changes during one mouse press make one snapshot with the final value.
func test_spinbox_gesture_is_one_snapshot() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.state.tool = EditorState.Tool.SELECT
	root.history = History.new()
	var field := root.ui.get_subtile_field(0)
	_ui_mouse(root, true)
	for v in [0.5, 1.0, 1.5]: field.value = v
	_ui_mouse(root, false)
	assert_near(root.level.get_block(2, 2)["subHeights"][0][0], 1.5, 0.0001, "final value")
	assert_true(root.history.undo(root.level), "one snapshot")
	assert_true(not root.history.can_undo(), "not several")
	await _free_editor(root)


## A second palette click outside Select mode changes only the brush and the tool.
func test_second_palette_click_outside_select_does_not_edit_level() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.history = History.new()
	root.apply_palette_pick("shape", "flat")
	assert_eq(root.level.get_block(2, 2)["rotation"], 0, "painted block untouched")
	assert_eq(root.state.brush["rotation"], 90, "brush rotated")
	assert_true(not root.history.can_undo(), "no snapshot in paint mode")
	root.state.tool = EditorState.Tool.ERASE
	root.paint_cell(Vector2i(2, 2))
	root.history = History.new()
	root.apply_palette_pick("shape", "flat")
	assert_true(root.level.get_block(2, 2).is_empty(), "erased cell stays empty")
	assert_true(not root.history.can_undo(), "no snapshot after erase")
	assert_eq(root.state.tool, EditorState.Tool.PAINT_BLOCK, "tool switched")
	await _free_editor(root)


## A click on the 3D view releases the focus of a text field so shortcuts work again.
func test_click_on_view_releases_text_focus() -> void:
	var root := await _make_editor()
	var field := LineEdit.new()
	root.add_child(field)
	field.grab_focus()
	await tree.process_frame
	assert_true(tree.root.gui_get_focus_owner() == field, "field focused")
	root._handle_mouse_button(_click(_cell_pos(root, Vector2i(5, 5)), true))
	assert_true(tree.root.gui_get_focus_owner() == null, "focus released")
	await _free_editor(root)
