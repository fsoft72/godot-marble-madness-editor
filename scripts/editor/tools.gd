class_name Tools
extends RefCounted
## Click tools and keyboard adjustments (port of applyToolAtCell and the keydown handler in js/main.js).

## Elevation step for the height keys (main.js keydown, W/S).
const HEIGHT_STEP := 0.5
## Step for slope and tilt keys (main.js keydown, A/D and Q/E).
const SLOPE_TILT_STEP := 0.2
## Degrees added by the rotate key and by repainting the same element or decal.
const ROTATE_STEP := 90


## Applies the tool of tool_state at a cell. Cells outside the grid are ignored with no snapshot.
## is_drag mirrors the JS drag flag: no snapshot and no repaint rotation.
static func apply(tool_state: EditorState, level: LevelData, history: History, view: LevelView, cell: Vector2i, is_drag: bool = false) -> void:
	if cell == EditorState.NO_CELL or not level.in_bounds(cell.x, cell.y): return
	tool_state.selected = cell
	var existing := level.get_block(cell.x, cell.y)
	match tool_state.tool:
		EditorState.Tool.SELECT:
			_sync_brush(tool_state, existing)
		EditorState.Tool.PICK:
			_sync_brush(tool_state, existing)
		EditorState.Tool.ERASE:
			if existing.is_empty(): return
			if not is_drag: history.push(level)
			level.remove_block(cell.x, cell.y)
			view.rebuild_block(cell.x, cell.y)
		_:
			if not is_drag: history.push(level)
			var block := _ensure_block(tool_state, level, cell)
			block["isVoid"] = false
			_paint(tool_state, block, is_drag)
			view.rebuild_block(cell.x, cell.y)
			_sync_brush(tool_state, block)


## Applies a key action: height_up, height_down, slope_up, slope_down, tilt_up, tilt_down, rotate
## or delete. Like the JS, the new value starts from the brush (which mirrors the selected block),
## the brush always follows, and an empty selected cell gets a block created from the brush.
## Without a valid selection only the brush changes. A snapshot is pushed only when the level changes.
static func adjust_selected(tool_state: EditorState, level: LevelData, history: History, view: LevelView, action: String) -> void:
	var cell := tool_state.selected
	var valid := cell != EditorState.NO_CELL and level.in_bounds(cell.x, cell.y)
	var block := level.get_block(cell.x, cell.y) if valid else {}
	if action == "delete":
		if block.is_empty(): return
		history.push(level)
		level.remove_block(cell.x, cell.y)
		view.rebuild_block(cell.x, cell.y)
		return
	var prop := _action_prop(action)
	if prop == "": return
	var base: Variant = block[prop] if block.has(prop) else tool_state.brush[prop]
	var value: Variant = _action_value(action, base)
	tool_state.brush[prop] = value
	tool_state.brush_changed.emit()
	if not valid: return
	history.push(level)
	if block.is_empty(): block = _ensure_block(tool_state, level, cell)
	block["isVoid"] = false
	block[prop] = value
	if prop != "elevation":
		block.erase("corners")
		block.erase("vGrid")
	view.rebuild_block(cell.x, cell.y)


## Copies the selected block into the brush, like syncInspectorFromSelection in the JS.
## Does nothing without a valid selection, or when the selected block is empty or void.
static func sync_brush_from_selection(tool_state: EditorState, level: LevelData) -> void:
	var cell := tool_state.selected
	if cell == EditorState.NO_CELL or not level.in_bounds(cell.x, cell.y): return
	_sync_brush(tool_state, level.get_block(cell.x, cell.y))


## Returns the block property changed by a key action, or "" for an unknown action.
static func _action_prop(action: String) -> String:
	match action:
		"height_up", "height_down": return "elevation"
		"slope_up", "slope_down": return "slope"
		"tilt_up", "tilt_down": return "tilt"
		"rotate": return "rotation"
	return ""


## Returns the value after applying a key action to the base value.
static func _action_value(action: String, base: Variant) -> Variant:
	match action:
		"height_up": return _round2(float(base) + HEIGHT_STEP)
		"height_down": return _round2(float(base) - HEIGHT_STEP)
		"slope_up", "tilt_up": return _round2(float(base) + SLOPE_TILT_STEP)
		"slope_down", "tilt_down": return _round2(float(base) - SLOPE_TILT_STEP)
	return (int(base) + ROTATE_STEP) % 360


## Returns the block at the cell, creating it from the brush elevation when absent (ensureBlockAt).
static func _ensure_block(tool_state: EditorState, level: LevelData, cell: Vector2i) -> Dictionary:
	var block := level.get_block(cell.x, cell.y)
	if not block.is_empty(): return block
	block = BlockData.make(cell.x, cell.y, {
		"elevation": tool_state.brush["elevation"],
		"subHeights": [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
	})
	level.set_block(cell.x, cell.y, block)
	return block


## Writes the brush fields used by the active paint tool into the block.
static func _paint(tool_state: EditorState, block: Dictionary, is_drag: bool) -> void:
	var brush := tool_state.brush
	match tool_state.tool:
		EditorState.Tool.PAINT_BLOCK:
			BlockData.apply_shape(block, brush["shape"])
			block["elevation"] = brush["elevation"]
			block["slope"] = brush["slope"]
			block["tilt"] = brush["tilt"]
			block["rotation"] = brush["rotation"]
			block.erase("corners")
			if brush["shape"] == "subtiles_custom":
				block["subHeights"] = brush["subHeights"].duplicate(true)
		EditorState.Tool.PAINT_ELEMENT:
			if not is_drag and block.get("element") == brush["element"] and block.get("element") != "none":
				block["elemRotation"] = (int(block.get("elemRotation", 0)) + ROTATE_STEP) % 360
			else:
				block["element"] = brush["element"]
				block["elemRotation"] = brush["elemRotation"]
		EditorState.Tool.PAINT_DECAL:
			if not is_drag and block.get("decal") == brush["decal"] and block.get("decal") != "none":
				block["decalRotation"] = (int(block.get("decalRotation", 0)) + ROTATE_STEP) % 360
			else:
				block["decal"] = brush["decal"]
				block["decalRotation"] = brush["decalRotation"]


## Copies a non-void block into the brush (syncInspectorFromSelection). Empty or void blocks are ignored.
static func _sync_brush(tool_state: EditorState, block: Dictionary) -> void:
	if block.is_empty() or block.get("isVoid", false) == true: return
	var brush := tool_state.brush
	brush["shape"] = block.get("shape", "flat")
	brush["elevation"] = float(block.get("elevation", 12.0))
	brush["slope"] = float(block.get("slope", 0.0))
	brush["tilt"] = float(block.get("tilt", 0.0))
	brush["rotation"] = int(block.get("rotation", 0))
	brush["element"] = block.get("element", "none")
	brush["elemRotation"] = int(block.get("elemRotation", 0))
	brush["decal"] = block.get("decal", "none")
	brush["decalRotation"] = int(block.get("decalRotation", 0))
	if block.has("subHeights"): brush["subHeights"] = block["subHeights"].duplicate(true)
	tool_state.brush_changed.emit()


## Rounds to 2 decimals like Math.round(v * 100) / 100 (halves round up).
static func _round2(v: float) -> float:
	return floorf(v * 100.0 + 0.5) / 100.0
