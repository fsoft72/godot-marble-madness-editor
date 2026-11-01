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


## The language button is enabled.
func test_language_button_enabled() -> void:
	var root := await _make_editor()
	assert_true(not root.ui.get_button("lang_toggle_btn").disabled, "language enabled")
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


## Level JSON text with the given size and one block.
func _level_text(cols: int, rows: int) -> String:
	var level := LevelData.new()
	level.cols = cols
	level.rows = rows
	level.set_block(1, 1, BlockData.make(1, 1, {"elevation": 6.0}))
	return LevelIO.serialize(level)


## Invalid text returns false, shows an error and leaves level, history and view untouched.
func test_load_invalid_text_keeps_level() -> void:
	var root := await _make_editor()
	root.paint_cell(Vector2i(2, 2))
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	var before := root.level.snapshot()
	root.history = History.new()
	for text in ["{not json", "[1, 2]", "{\"cols\": 5}", "{\"blocks\": 3}"]:
		assert_true(not root.load_level_from_text(text), "rejected: %s" % text)
		assert_eq(root.level.snapshot(), before, "level untouched: %s" % text)
		assert_true(not root.history.can_undo(), "no snapshot: %s" % text)
		assert_true(root.ui.is_error_visible(), "error shown: %s" % text)
		assert_true(root.ui.get_error_text() != "", "error text: %s" % text)
	assert_true(root.view.block_node(2, 2) != null, "node kept")
	await _free_editor(root)


## A valid load replaces the level in place, and undo restores the old level, size and framing.
func test_load_valid_then_undo() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(9, 9))
	var level_ref := root.level
	var history_ref := root.history
	assert_true(root.load_level_from_text(_level_text(6, 6)), "load ok")
	assert_true(root.level == level_ref and root.history == history_ref, "references kept")
	assert_eq(root.level.cols, 6, "cols")
	assert_true(root.view.block_node(1, 1) != null, "loaded node")
	assert_true(root.view.block_node(9, 9) == null, "old node removed")
	assert_true(root.rig.focus.is_equal_approx(Vector3(9.0, BlockData.defaults()["elevation"], 9.0)), "reframed")
	root.undo()
	assert_eq(root.level.blocks.keys(), ["9,9"], "undo restores blocks")
	assert_eq(root.level.cols, 14, "size restored")
	assert_true(root.view.block_node(9, 9) != null, "old node back")
	assert_true(root.view.block_node(1, 1) == null, "loaded node gone")
	assert_true(root.rig.focus.is_equal_approx(Vector3(21.0, BlockData.defaults()["elevation"], 21.0)), "reframed back")
	root.redo()
	assert_eq(root.level.cols, 6, "redo reloads")
	await _free_editor(root)


## Loading a smaller level drops an out-of-range selection and ends a running stroke.
func test_load_revalidates_selection_and_stroke() -> void:
	var root := await _make_editor()
	root.state.selected = Vector2i(10, 10)
	root._stroke_active = true
	assert_true(root.load_level_from_text(_level_text(6, 6)), "load ok")
	assert_eq(root.state.selected, EditorState.NO_CELL, "selection cleared")
	assert_true(not root._stroke_active, "stroke ended")
	root.state.selected = Vector2i(1, 1)
	assert_true(root.load_level_from_text(_level_text(6, 6)), "load ok again")
	assert_eq(root.state.selected, Vector2i(1, 1), "valid selection kept")
	await _free_editor(root)


## Clear empties the level, keeps the size and is one undo step; clearing an empty level pushes nothing.
func test_clear_keeps_size_and_is_undoable() -> void:
	var root := await _make_editor()
	root.clear_level()
	assert_true(not root.history.can_undo(), "empty clear pushes no snapshot")
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(3, 3))
	root.paint_cell(Vector2i(4, 4))
	root.history = History.new()
	root.clear_level()
	assert_true(root.level.blocks.is_empty(), "blocks gone")
	assert_eq(root.level.cols, 14, "size kept")
	assert_true(root.view.block_node(3, 3) == null, "node removed")
	assert_true(root.history.can_undo(), "snapshot pushed")
	root.undo()
	assert_eq(root.level.blocks.size(), 2, "undo restores blocks")
	assert_true(root.view.block_node(4, 4) != null, "node back")
	await _free_editor(root)


## The grid is hidden by default, the toggle flips it and the Grid button shows the state.
func test_toggle_grid() -> void:
	var root := await _make_editor()
	var button := root.ui.get_button("toggle_grid")
	assert_true(not button.disabled, "button enabled")
	assert_true(not root.grid.visible and not button.button_pressed, "hidden by default")
	root.toggle_grid()
	assert_true(root.grid.visible and button.button_pressed, "shown")
	button.pressed.emit()
	assert_true(not root.grid.visible, "button press toggles")
	await _free_editor(root)


## The grid lines cover the grid area and follow a level size change.
func test_grid_follows_level_size() -> void:
	var root := await _make_editor()
	assert_eq(root.grid.get_aabb().size.x, 14.0 * Constants.BLOCK_SIZE, "width")
	assert_eq(root.grid.line_count(), 2 * 15, "lines for 14 cells")
	assert_true(root.grid.get_aabb().get_center().is_equal_approx(Vector3(21.0, 0.0, 21.0)), "centered on level")
	root.load_level_from_text(_level_text(6, 6))
	assert_eq(root.grid.line_count(), 2 * 7, "lines for 6 cells")
	assert_eq(root.grid.get_aabb().size.x, 6.0 * Constants.BLOCK_SIZE, "new width")
	root.undo()
	assert_eq(root.grid.line_count(), 2 * 15, "restored by undo")
	await _free_editor(root)


## The file buttons are enabled and a file round trip works; bad files show the error dialog.
func test_file_round_trip_and_errors() -> void:
	var root := await _make_editor()
	for key in ["clear_map", "open_json", "save_json"]:
		assert_true(not root.ui.get_button(key).disabled, "%s enabled" % key)
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(5, 5))
	var path := "user://test_task12_level.json"
	assert_true(root.save_level_to_file(path), "saved")
	root.clear_level()
	assert_true(root.load_level_from_file(path), "loaded")
	assert_true(not root.level.get_block(5, 5).is_empty(), "block back")
	DirAccess.remove_absolute(path)
	var snap := root.level.snapshot()
	assert_true(not root.load_level_from_file("user://missing_task12.json"), "missing file rejected")
	assert_true(root.ui.is_error_visible(), "error for missing file")
	root.ui.hide_error()
	assert_true(not root.save_level_to_file("user://no_such_dir_task12/x.json"), "save failure")
	assert_true(root.ui.is_error_visible(), "error for save failure")
	assert_eq(root.level.snapshot(), snap, "level untouched after failures")
	await _free_editor(root)


## The file dialogs filter *.json and open the right modes.
func test_file_dialogs_configured() -> void:
	var root := await _make_editor()
	var open_dialog := root.ui.open_dialog
	var save_dialog := root.ui.save_dialog
	assert_eq(open_dialog.file_mode, FileDialog.FILE_MODE_OPEN_FILE, "open mode")
	assert_eq(save_dialog.file_mode, FileDialog.FILE_MODE_SAVE_FILE, "save mode")
	assert_eq(open_dialog.access, FileDialog.ACCESS_FILESYSTEM, "open access")
	assert_eq(save_dialog.access, FileDialog.ACCESS_FILESYSTEM, "save access")
	assert_true("*.json" in open_dialog.filters[0] and "*.json" in save_dialog.filters[0], "json filter")
	await _free_editor(root)
