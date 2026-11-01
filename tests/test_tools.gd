extends TestCase
## Tests for EditorState and Tools (click tools and keyboard adjustments).

const NO_CELL := Vector2i(-1, -1)

var _level: LevelData
var _history: History
var _view: LevelView
var _state: EditorState


## Builds a fresh 14x14 level, history, bound view and editor state.
func _setup() -> void:
	_level = LevelData.new()
	_history = History.new()
	_view = LevelView.new()
	_view.bind(_level)
	_state = EditorState.new()


## Frees the nodes created by _setup.
func _teardown() -> void:
	_view.free()


## Applies a tool at a cell with the current fixtures.
func _click(tool: EditorState.Tool, cell: Vector2i) -> void:
	_state.tool = tool
	Tools.apply(_state, _level, _history, _view, cell)


## Initial brush and selection match state.brush in the JS source.
func test_state_defaults() -> void:
	var s := EditorState.new()
	assert_eq(s.selected, NO_CELL, "no selection")
	assert_eq(s.tool, EditorState.Tool.SELECT, "tool")
	assert_eq(s.brush["shape"], "flat", "shape")
	assert_near(s.brush["elevation"], 12.0, 0.0001, "elevation")
	assert_eq(s.brush["element"], "tube_corner", "element")
	assert_eq(s.brush["decal"], "arrow_wide_diag", "decal")
	assert_eq(s.brush["marbleColor"], "#e61922", "marble color")


## Paint block builds a block from the brush.
func test_paint_block_creates_from_brush() -> void:
	_setup()
	_state.brush["elevation"] = 7.5
	_state.brush["slope"] = 0.4
	_state.brush["tilt"] = -0.2
	_state.brush["rotation"] = 180
	_state.brush["shape"] = "fold_right"
	_click(EditorState.Tool.PAINT_BLOCK, Vector2i(3, 4))
	var b := _level.get_block(3, 4)
	assert_eq(b.get("shape"), "fold_right", "shape")
	assert_eq(b.get("shadePreset"), "turn_right", "preset via apply_shape")
	assert_near(b.get("elevation", 0.0), 7.5, 0.0001, "elevation")
	assert_near(b.get("slope", 0.0), 0.4, 0.0001, "slope")
	assert_near(b.get("tilt", 0.0), -0.2, 0.0001, "tilt")
	assert_eq(b.get("rotation"), 180, "rotation")
	assert_eq(b.get("isVoid"), false, "not void")
	assert_true(_history.can_undo(), "snapshot pushed")
	assert_true(_view.block_node(3, 4) != null, "view node")
	assert_eq(_state.selected, Vector2i(3, 4), "selection follows click")
	_teardown()


## Paint block drops corners and copies subHeights only for subtiles_custom.
func test_paint_block_corners_and_subheights() -> void:
	_setup()
	_level.set_block(1, 1, BlockData.make(1, 1, {"corners": [1, 2, 3, 4]}))
	_state.brush["shape"] = "subtiles_custom"
	_state.brush["subHeights"] = [[1, 2, 3], [0, 0, 0], [0, 0, 0]]
	_click(EditorState.Tool.PAINT_BLOCK, Vector2i(1, 1))
	var b := _level.get_block(1, 1)
	assert_true(not b.has("corners"), "corners removed")
	assert_eq(b.get("subHeights"), [[1, 2, 3], [0, 0, 0], [0, 0, 0]], "subHeights copied")
	_state.brush["subHeights"][0][0] = 9
	assert_eq(b["subHeights"][0][0], 1, "subHeights is a copy")
	_teardown()


## A click outside the grid, or the no-cell sentinel, changes nothing and pushes nothing.
func test_paint_outside_grid_ignored_no_snapshot() -> void:
	_setup()
	for tool in [EditorState.Tool.PAINT_BLOCK, EditorState.Tool.PAINT_ELEMENT, EditorState.Tool.PAINT_DECAL, EditorState.Tool.ERASE, EditorState.Tool.SELECT, EditorState.Tool.PICK]:
		for cell in [NO_CELL, Vector2i(14, 0), Vector2i(0, 14), Vector2i(-1, 3), Vector2i(3, -2), Vector2i(99, 99)]:
			_click(tool, cell)
	assert_true(not _history.can_undo(), "no snapshot")
	assert_true(_level.blocks.is_empty(), "no blocks")
	assert_eq(_state.selected, NO_CELL, "selection untouched")
	_teardown()


## Erase removes the block from the dictionary and undo restores it with its node.
func test_erase_removes_block_and_undo_restores() -> void:
	_setup()
	_level.set_block(2, 2, BlockData.make(2, 2, {"elevation": 5.0}))
	_view.rebuild_all()
	_click(EditorState.Tool.ERASE, Vector2i(2, 2))
	assert_true(not _level.blocks.has("2,2"), "key removed")
	assert_true(_view.block_node(2, 2) == null, "node removed")
	assert_true(_history.undo(_level), "undo")
	_view.rebuild_all()
	assert_near(_level.get_block(2, 2).get("elevation", 0.0), 5.0, 0.0001, "block back")
	assert_true(_view.block_node(2, 2) != null, "node back")
	_teardown()


## Erasing an empty cell is a no-op without snapshot.
func test_erase_empty_cell_no_snapshot() -> void:
	_setup()
	_click(EditorState.Tool.ERASE, Vector2i(5, 5))
	assert_true(not _history.can_undo(), "no snapshot")
	_teardown()


## Pick copies the block into the brush without a snapshot; empty cells leave the brush alone.
func test_pick_copies_into_brush() -> void:
	_setup()
	_level.set_block(4, 4, BlockData.make(4, 4, {"elevation": 3.0, "slope": 0.6, "tilt": 0.2, "rotation": 90, "shape": "ramp", "element": "cone", "elemRotation": 270, "decal": "arrow", "decalRotation": 90}))
	_click(EditorState.Tool.PICK, Vector2i(4, 4))
	assert_eq(_state.brush["shape"], "ramp", "shape")
	assert_near(_state.brush["elevation"], 3.0, 0.0001, "elevation")
	assert_near(_state.brush["slope"], 0.6, 0.0001, "slope")
	assert_near(_state.brush["tilt"], 0.2, 0.0001, "tilt")
	assert_eq(_state.brush["rotation"], 90, "rotation")
	assert_eq(_state.brush["element"], "cone", "element")
	assert_eq(_state.brush["elemRotation"], 270, "elemRotation")
	assert_eq(_state.brush["decal"], "arrow", "decal")
	assert_eq(_state.brush["decalRotation"], 90, "decalRotation")
	assert_true(not _history.can_undo(), "no snapshot")
	_click(EditorState.Tool.PICK, Vector2i(9, 9))
	assert_eq(_state.brush["shape"], "ramp", "empty cell leaves brush")
	_teardown()


## Select sets the selection, copies the block into the brush and pushes nothing.
func test_select_sets_selection_no_snapshot() -> void:
	_setup()
	_level.set_block(6, 7, BlockData.make(6, 7, {"elevation": 9.0}))
	_click(EditorState.Tool.SELECT, Vector2i(6, 7))
	assert_eq(_state.selected, Vector2i(6, 7), "selected")
	assert_near(_state.brush["elevation"], 9.0, 0.0001, "brush synced like the JS inspector")
	assert_true(not _history.can_undo(), "no snapshot")
	_teardown()


## Paint element on an empty cell creates a block with the brush elevation.
func test_paint_element_on_empty_cell_creates_block() -> void:
	_setup()
	_state.brush["element"] = "cone"
	_state.brush["elemRotation"] = 90
	_click(EditorState.Tool.PAINT_ELEMENT, Vector2i(0, 0))
	var b := _level.get_block(0, 0)
	assert_eq(b.get("element"), "cone", "element")
	assert_eq(b.get("elemRotation"), 90, "rotation")
	assert_near(b.get("elevation", 0.0), 12.0, 0.0001, "brush elevation")
	assert_eq(b.get("shape"), "flat", "default shape")
	assert_true(_history.can_undo(), "snapshot")
	_teardown()


## Painting the same element again rotates it by 90 and updates the brush; a drag does not.
func test_paint_element_again_rotates() -> void:
	_setup()
	_state.brush["element"] = "cone"
	_state.brush["elemRotation"] = 0
	_click(EditorState.Tool.PAINT_ELEMENT, Vector2i(1, 1))
	_click(EditorState.Tool.PAINT_ELEMENT, Vector2i(1, 1))
	assert_eq(_level.get_block(1, 1).get("elemRotation"), 90, "rotated")
	assert_eq(_state.brush["elemRotation"], 90, "brush follows")
	Tools.apply(_state, _level, _history, _view, Vector2i(1, 1), true)
	assert_eq(_level.get_block(1, 1).get("elemRotation"), 90, "drag overwrites with brush, no rotate")
	_teardown()


## Painting a decal sets decal fields, and repeating rotates it.
func test_paint_decal_and_rotate() -> void:
	_setup()
	_state.brush["decal"] = "arrow"
	_click(EditorState.Tool.PAINT_DECAL, Vector2i(2, 3))
	assert_eq(_level.get_block(2, 3).get("decal"), "arrow", "decal")
	_click(EditorState.Tool.PAINT_DECAL, Vector2i(2, 3))
	assert_eq(_level.get_block(2, 3).get("decalRotation"), 90, "rotated")
	_teardown()


## Painting over a void block revives it.
func test_paint_over_void_clears_void() -> void:
	_setup()
	_level.set_block(2, 2, BlockData.make(2, 2, {"isVoid": true}))
	_click(EditorState.Tool.PAINT_DECAL, Vector2i(2, 2))
	assert_eq(_level.get_block(2, 2).get("isVoid"), false, "revived")
	_teardown()


## Rotate adds 90 degrees modulo 360.
func test_rotate_cycles_360() -> void:
	_setup()
	_level.set_block(3, 3, BlockData.make(3, 3))
	_state.selected = Vector2i(3, 3)
	for i in 4:
		Tools.adjust_selected(_state, _level, _history, _view, "rotate")
	assert_eq(_level.get_block(3, 3).get("rotation"), 0, "full circle")
	Tools.adjust_selected(_state, _level, _history, _view, "rotate")
	assert_eq(_level.get_block(3, 3).get("rotation"), 90, "one step")
	_teardown()


## Height keys change elevation by 0.5; slope and tilt keys by 0.2 (rounded to 2 decimals).
func test_height_step_changes_elevation() -> void:
	_setup()
	_level.set_block(3, 3, BlockData.make(3, 3, {"elevation": 10.0}))
	_state.selected = Vector2i(3, 3)
	Tools.adjust_selected(_state, _level, _history, _view, "height_up")
	assert_near(_level.get_block(3, 3).get("elevation", 0.0), 10.5, 0.0001, "up")
	Tools.adjust_selected(_state, _level, _history, _view, "height_down")
	Tools.adjust_selected(_state, _level, _history, _view, "height_down")
	assert_near(_level.get_block(3, 3).get("elevation", 0.0), 9.5, 0.0001, "down")
	for i in 3:
		Tools.adjust_selected(_state, _level, _history, _view, "slope_up")
	assert_eq(_level.get_block(3, 3).get("slope"), 0.6, "slope rounded to 2 decimals")
	Tools.adjust_selected(_state, _level, _history, _view, "slope_down")
	assert_eq(_level.get_block(3, 3).get("slope"), 0.4, "slope down")
	Tools.adjust_selected(_state, _level, _history, _view, "tilt_up")
	Tools.adjust_selected(_state, _level, _history, _view, "tilt_down")
	Tools.adjust_selected(_state, _level, _history, _view, "tilt_down")
	assert_eq(_level.get_block(3, 3).get("tilt"), -0.2, "tilt")
	assert_near(_state.brush["elevation"], 9.5, 0.0001, "brush follows")
	_teardown()


## Slope, tilt and rotation changes drop corners and vGrid.
func test_adjust_drops_corners() -> void:
	_setup()
	_level.set_block(3, 3, BlockData.make(3, 3, {"corners": [1], "vGrid": [1]}))
	_state.selected = Vector2i(3, 3)
	Tools.adjust_selected(_state, _level, _history, _view, "slope_up")
	var b := _level.get_block(3, 3)
	assert_true(not b.has("corners") and not b.has("vGrid"), "dropped")
	_teardown()


## Adjust with no selection, a bad selection, or an empty cell does nothing and pushes nothing.
func test_adjust_noop_cases() -> void:
	_setup()
	Tools.adjust_selected(_state, _level, _history, _view, "height_up")
	_state.selected = Vector2i(40, 2)
	Tools.adjust_selected(_state, _level, _history, _view, "delete")
	_state.selected = Vector2i(5, 5)
	Tools.adjust_selected(_state, _level, _history, _view, "rotate")
	Tools.adjust_selected(_state, _level, _history, _view, "delete")
	assert_true(not _history.can_undo(), "no snapshot")
	assert_true(_level.blocks.is_empty(), "nothing created")
	_teardown()


## Delete removes the selected block and undo brings it back.
func test_delete_selected() -> void:
	_setup()
	_level.set_block(3, 3, BlockData.make(3, 3))
	_view.rebuild_all()
	_state.selected = Vector2i(3, 3)
	Tools.adjust_selected(_state, _level, _history, _view, "delete")
	assert_true(not _level.blocks.has("3,3"), "removed")
	assert_true(_view.block_node(3, 3) == null, "node gone")
	_history.undo(_level)
	assert_true(_level.blocks.has("3,3"), "restored")
	_teardown()


## After paint then undo and rebuild_all, the view node is gone again.
func test_undo_after_paint_restores_view_node() -> void:
	_setup()
	_click(EditorState.Tool.PAINT_BLOCK, Vector2i(5, 5))
	assert_true(_view.block_node(5, 5) != null, "painted node")
	assert_true(_history.undo(_level), "undo")
	_view.rebuild_all()
	assert_true(_view.block_node(5, 5) == null, "node removed after undo")
	assert_true(_level.blocks.is_empty(), "level empty")
	_teardown()


## Signals fire on tool, selection and brush changes.
func test_state_signals() -> void:
	var s := EditorState.new()
	var counts := {"tool": 0, "sel": 0}
	s.tool_changed.connect(func(_t): counts["tool"] += 1)
	s.selection_changed.connect(func(_c): counts["sel"] += 1)
	s.tool = EditorState.Tool.ERASE
	s.tool = EditorState.Tool.ERASE
	s.selected = Vector2i(1, 1)
	s.selected = Vector2i(1, 1)
	assert_eq(counts["tool"], 1, "tool once")
	assert_eq(counts["sel"], 1, "selection once")
