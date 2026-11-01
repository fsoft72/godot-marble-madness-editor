class_name EditorState
extends RefCounted
## Editor-side state: current tool, selected cell and brush (port of state.* in js/main.js).

## Emitted when the active tool changes.
signal tool_changed(new_tool: Tool)
## Emitted when the selected cell changes.
signal selection_changed(cell: Vector2i)
## Emitted when any brush value changes.
signal brush_changed

## Available editing tools.
enum Tool { SELECT, PAINT_BLOCK, PAINT_ELEMENT, PAINT_DECAL, ERASE, PICK }

## Value of `selected` when no cell is selected.
const NO_CELL := Vector2i(-1, -1)

## Active tool.
var tool: Tool = Tool.SELECT:
	set(value):
		if value == tool: return
		tool = value
		tool_changed.emit(tool)
## Selected cell, or NO_CELL.
var selected: Vector2i = NO_CELL:
	set(value):
		if value == selected: return
		selected = value
		selection_changed.emit(selected)
## Brush values, same keys and initial values as state.brush in the JS source.
var brush: Dictionary = {
	"shape": "flat",
	"elevation": 12.0,
	"slope": 0.0,
	"tilt": 0.0,
	"rotation": 0,
	"element": "tube_corner",
	"elemRotation": 0,
	"marbleColor": "#e61922",
	"decal": "arrow_wide_diag",
	"decalRotation": 0,
	"subHeights": [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
}
