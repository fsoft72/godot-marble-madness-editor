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


## Applies a key action to the selected block: height_up, height_down, slope_up, slope_down,
## tilt_up, tilt_down, rotate or delete. No-op without a valid selection on an existing block.
static func adjust_selected(tool_state: EditorState, level: LevelData, history: History, view: LevelView, action: String) -> void:
	var cell := tool_state.selected
	if cell == EditorState.NO_CELL or not level.in_bounds(cell.x, cell.y): return
	var block := level.get_block(cell.x, cell.y)
	if block.is_empty(): return
	if action == "delete":
		history.push(level)
		level.remove_block(cell.x, cell.y)
		view.rebuild_block(cell.x, cell.y)
		return
	var prop := ""
	var value: Variant
	match action:
		"height_up": prop = "elevation"; value = _round2(float(block.get("elevation", tool_state.brush["elevation"])) + HEIGHT_STEP)
		"height_down": prop = "elevation"; value = _round2(float(block.get("elevation", tool_state.brush["elevation"])) - HEIGHT_STEP)
		"slope_up": prop = "slope"; value = _round2(float(block.get("slope", 0.0)) + SLOPE_TILT_STEP)
		"slope_down": prop = "slope"; value = _round2(float(block.get("slope", 0.0)) - SLOPE_TILT_STEP)
		"tilt_up": prop = "tilt"; value = _round2(float(block.get("tilt", 0.0)) + SLOPE_TILT_STEP)
		"tilt_down": prop = "tilt"; value = _round2(float(block.get("tilt", 0.0)) - SLOPE_TILT_STEP)
		"rotate": prop = "rotation"; value = (int(block.get("rotation", 0)) + ROTATE_STEP) % 360
	if prop == "": return
	history.push(level)
	block["isVoid"] = false
	block[prop] = value
	if prop != "elevation":
		block.erase("corners")
		block.erase("vGrid")
	view.rebuild_block(cell.x, cell.y)
	tool_state.brush[prop] = value
	tool_state.brush_changed.emit()


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
