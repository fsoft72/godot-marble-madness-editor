class_name EditorRoot
extends Node3D
## Root of the editor scene: owns the level, history, state, view, camera rig and UI,
## routes mouse picking and keyboard shortcuts, and applies the UI edits.

## Shape of the hover and selection cursors, slightly above the surface.
const CURSOR_LIFT := 0.08
const HOVER_COLOR := Color(1.0, 1.0, 1.0, 0.28)
const SELECT_COLOR := Color(0.93, 0.8, 0.41, 0.45)
## Sun and ambient settings from js/main.js.
const AMBIENT_ENERGY := 0.72
const SUN_COLOR := Color("fffaf0")
const SUN_ENERGY := 1.15
const SUN_POSITION := Vector3(-22.0, 48.0, 12.0)
const FILL_COLOR := Color("90a8ff")
const FILL_ENERGY := 0.25
const FILL_POSITION := Vector3(25.0, 20.0, -20.0)
## Shadow range of the sun.
const SHADOW_DISTANCE := 160.0
## Block properties whose edit invalidates the corner offsets of a block.
const SHAPE_PROPS: Array[String] = ["slope", "tilt", "rotation"]
## Block properties stored as integers.
const INT_PROPS: Array[String] = ["rotation", "elemRotation", "decalRotation"]
## Tool selected by a palette click, per brush key.
const PALETTE_TOOLS := {
	"shape": EditorState.Tool.PAINT_BLOCK,
	"element": EditorState.Tool.PAINT_ELEMENT,
	"decal": EditorState.Tool.PAINT_DECAL,
}
## Rotation property rotated by a second palette click, per brush key.
const ROTATION_PROPS := {"shape": "rotation", "element": "elemRotation", "decal": "decalRotation"}
## Tool for each number key.
const TOOL_KEYS := {
	KEY_1: EditorState.Tool.SELECT,
	KEY_2: EditorState.Tool.PAINT_BLOCK,
	KEY_3: EditorState.Tool.PAINT_ELEMENT,
	KEY_4: EditorState.Tool.PAINT_DECAL,
	KEY_5: EditorState.Tool.ERASE,
}
## Tools.adjust_selected action for each key (main.js keydown handler).
const ADJUST_KEYS := {
	KEY_W: "height_up",
	KEY_S: "height_down",
	KEY_A: "slope_down",
	KEY_D: "slope_up",
	KEY_Q: "tilt_down",
	KEY_E: "tilt_up",
	KEY_R: "rotate",
	KEY_DELETE: "delete",
	KEY_BACKSPACE: "delete",
}

## The level being edited.
var level := LevelData.new()
## Undo and redo snapshots.
var history := History.new()
## Tool, selection and brush.
var state := EditorState.new()
## Renders the level.
var view := LevelView.new()
## Orbit camera.
var rig := CameraRig.new()
## Interface.
var ui := EditorUI.new()
## Wireframe grid, hidden by default like showGridHelper in the JS.
var grid := GridLines.new()

var _hover_cursor := MeshInstance3D.new()
var _select_cursor := MeshInstance3D.new()
var _hover_cell := EditorState.NO_CELL
## True while a left drag started on the 3D view.
var _stroke_active := false
## True once the current stroke has pushed its undo snapshot.
var _stroke_has_snapshot := false
## Last cell painted by the current stroke.
var _stroke_cell := EditorState.NO_CELL
## Grid size the camera is centered on.
var _centered_size := Vector2i.ZERO


## Builds the scene: lights, background, view, camera, cursors and UI.
func _ready() -> void:
	_build_environment()
	view.name = "LevelView"
	add_child(view)
	view.bind(level)
	rig.name = "CameraRig"
	add_child(rig)
	center_camera(true)
	grid.visible = false
	add_child(grid)
	grid.rebuild(level.cols, level.rows)
	_build_cursor(_hover_cursor, HOVER_COLOR)
	_build_cursor(_select_cursor, SELECT_COLOR)
	var layer := CanvasLayer.new()
	layer.name = "UILayer"
	add_child(layer)
	layer.add_child(ui)
	ui.bind(state, level, history)
	_connect_ui()
	state.selection_changed.connect(func(_cell: Vector2i) -> void: _after_edit())
	state.tool_changed.connect(func(_tool: int) -> void: _end_stroke(); ui.refresh())
	state.brush_changed.connect(func() -> void: ui.refresh())


## Ends a paint stroke on any left button release, even over the UI.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed): return
	_end_stroke()


## Handles clicks and motion that the UI did not consume.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton: _handle_mouse_button(event)
	elif event is InputEventMouseMotion: _handle_mouse_motion(event)


## Handles tool shortcuts, adjust keys and undo/redo unless a text field has focus.
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo): return
	if get_viewport().gui_get_focus_owner() is LineEdit or get_viewport().gui_get_focus_owner() is TextEdit: return
	if event.ctrl_pressed or event.meta_pressed:
		_handle_ctrl_key(event)
		return
	if event.alt_pressed: return
	if TOOL_KEYS.has(event.keycode):
		state.tool = TOOL_KEYS[event.keycode]
		return
	if not ADJUST_KEYS.has(event.keycode): return
	Tools.adjust_selected(state, level, history, view, ADJUST_KEYS[event.keycode])
	_after_edit()


## Applies the active tool to a cell as a click (no drag).
func paint_cell(cell: Vector2i) -> void:
	Tools.apply(state, level, history, view, cell, false)
	_after_edit()


## Moves the camera focus to the level center; reset_view also restores the arcade view.
func center_camera(reset_view: bool = false) -> void:
	_centered_size = Vector2i(level.cols, level.rows)
	rig.focus_on(Vector3(
		level.cols * Constants.BLOCK_SIZE / 2.0,
		BlockData.defaults()["elevation"],
		level.rows * Constants.BLOCK_SIZE / 2.0))
	if reset_view: rig.reset_arcade_view()


## Undoes the last step and rebuilds the view.
func undo() -> void:
	_end_stroke()
	if not history.undo(level): return
	_after_level_replaced()


## Redoes the last undone step and rebuilds the view.
func redo() -> void:
	_end_stroke()
	if not history.redo(level): return
	_after_level_replaced()


## Parses level JSON and replaces the level contents in place, as one undo step.
## On a parse error shows the error dialog, returns false and changes nothing.
func load_level_from_text(text: String) -> bool:
	var result := LevelIO.parse(text)
	if not result["ok"]:
		ui.show_error("err_invalid_json", result["error"])
		return false
	history.push(level)
	level.copy_from(result["level"])
	_after_level_replaced()
	return true


## Reads a level file and loads it. Shows the error dialog and returns false on failure.
func load_level_from_file(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		ui.show_error("err_load_failed", "%s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	return load_level_from_text(file.get_as_text())


## Writes the level to a file. Shows the error dialog and returns false on failure; the level is never changed.
func save_level_to_file(path: String) -> bool:
	var err := LevelIO.save_file(path, level)
	if err == OK: return true
	ui.show_error("err_save_failed", "%s (error %d)" % [path, err])
	return false


## Removes every block and keeps the grid size, as one undo step. Does nothing on an empty level.
func clear_level() -> void:
	if level.blocks.is_empty(): return
	history.push(level)
	level.clear()
	_after_level_replaced()


## Shows or hides the wireframe grid.
func toggle_grid() -> void:
	grid.visible = not grid.visible
	ui.set_grid_active(grid.visible)


## Commits an inspector value: the brush always follows, a selected cell is edited with one snapshot.
func apply_inspector_value(prop: String, value: Variant) -> void:
	state.brush[prop] = int(value) if prop in INT_PROPS else value
	if _selection_valid():
		history.push(level)
		var block := _ensure_selected_block()
		block[prop] = state.brush[prop]
		if prop in SHAPE_PROPS:
			block.erase("corners")
			block.erase("vGrid")
		view.rebuild_block(state.selected.x, state.selected.y)
	state.brush_changed.emit()
	_after_edit()


## Commits one sub-height field: the brush shape becomes subtiles_custom and a selected cell follows.
func apply_subtile_value(row: int, col: int, value: float) -> void:
	state.brush["subHeights"][row][col] = value
	state.brush["shape"] = "subtiles_custom"
	if _selection_valid():
		history.push(level)
		var block := _ensure_selected_block()
		block["shape"] = "subtiles_custom"
		block["subHeights"] = state.brush["subHeights"].duplicate(true)
		view.rebuild_block(state.selected.x, state.selected.y)
	state.brush_changed.emit()
	_after_edit()


## Sets a brush value from a palette click; in Select mode with a selection the block is edited too.
func apply_palette_pick(kind: String, id: String) -> void:
	if state.brush[kind] == id:
		_rotate_active_item(kind)
		return
	state.brush[kind] = id
	if state.tool == EditorState.Tool.SELECT and _selection_valid():
		history.push(level)
		var block := _ensure_selected_block()
		if kind == "shape":
			BlockData.apply_shape(block, id)
			if id == "subtiles_custom" and not block.has("subHeights"):
				block["subHeights"] = state.brush["subHeights"].duplicate(true)
		else:
			block[kind] = id
		view.rebuild_block(state.selected.x, state.selected.y)
	else:
		state.tool = PALETTE_TOOLS[kind]
	state.brush_changed.emit()
	_after_edit()


## Handles a click on the active palette item: rotates its brush rotation by 90 degrees.
## In Select mode a selected block follows (one snapshot); otherwise only the brush and tool change.
func _rotate_active_item(kind: String) -> void:
	var prop: String = ROTATION_PROPS[kind]
	var next := (int(state.brush[prop]) + Tools.ROTATE_STEP) % 360
	if state.tool == EditorState.Tool.SELECT and _selection_valid():
		apply_inspector_value(prop, next)
		return
	state.brush[prop] = next
	state.tool = PALETTE_TOOLS[kind]
	state.brush_changed.emit()
	_after_edit()


## Starts a stroke with a left click on the 3D view.
func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if event.pressed and not _pointer_over_ui(): _release_text_focus()
	if event.button_index != MOUSE_BUTTON_LEFT: return
	if not event.pressed:
		_end_stroke()
		return
	if event.alt_pressed or event.shift_pressed or _pointer_over_ui(): return
	var cell := _cell_at(event.position)
	if cell == EditorState.NO_CELL: return
	_stroke_active = true
	_stroke_cell = cell
	_stroke_has_snapshot = _will_push_snapshot(cell)
	paint_cell(cell)


## Updates the hover cursor and continues a paint or erase drag.
func _handle_mouse_motion(event: InputEventMouseMotion) -> void:
	if _pointer_over_ui():
		_set_hover(EditorState.NO_CELL)
		return
	var cell := _cell_at(event.position)
	_set_hover(cell)
	if cell == EditorState.NO_CELL or not _stroke_active or cell == _stroke_cell: return
	if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT): return
	if state.tool != EditorState.Tool.PAINT_BLOCK and state.tool != EditorState.Tool.ERASE: return
	_stroke_cell = cell
	var pushes := _will_push_snapshot(cell)
	Tools.apply(state, level, history, view, cell, _stroke_has_snapshot)
	_stroke_has_snapshot = _stroke_has_snapshot or pushes
	_after_edit()


## Handles Ctrl+Z (undo) and Ctrl+Y or Ctrl+Shift+Z (redo).
func _handle_ctrl_key(event: InputEventKey) -> void:
	if event.keycode == KEY_Y or (event.keycode == KEY_Z and event.shift_pressed): redo()
	elif event.keycode == KEY_Z: undo()


## Ends the current paint stroke.
func _end_stroke() -> void:
	_stroke_active = false
	_stroke_has_snapshot = false
	_stroke_cell = EditorState.NO_CELL


## Returns true when applying the active tool without drag would push an undo snapshot.
func _will_push_snapshot(cell: Vector2i) -> bool:
	if state.tool == EditorState.Tool.PAINT_BLOCK: return true
	return state.tool == EditorState.Tool.ERASE and not level.get_block(cell.x, cell.y).is_empty()


## Drops the keyboard focus of a text field so shortcuts work after a click on the 3D view.
func _release_text_focus() -> void:
	var owner := get_viewport().gui_get_focus_owner()
	if owner != null: owner.release_focus()


## Returns true when the mouse is over an interface control.
func _pointer_over_ui() -> bool:
	return get_viewport().gui_get_hovered_control() != null


## Returns the cell under a screen position: block geometry first, then the ground plane.
func _cell_at(screen_pos: Vector2) -> Vector2i:
	var ray := rig.ray_from_screen(screen_pos)
	var cell := view.pick_cell(ray["origin"], ray["dir"])
	if cell != LevelView.NO_CELL: return cell
	return view.cell_from_ground_ray(ray["origin"], ray["dir"])


## Stores the hovered cell, moves the cursor and updates the badge.
func _set_hover(cell: Vector2i) -> void:
	_hover_cell = cell
	_place_cursor(_hover_cursor, cell)
	ui.set_hover_cell(cell)


## Refreshes cursors, badge and UI after any edit.
func _after_edit() -> void:
	_place_cursor(_select_cursor, state.selected)
	_place_cursor(_hover_cursor, _hover_cell)
	ui.set_hover_cell(_hover_cell)
	ui.refresh()


## Brings view, grid, selection, camera and UI in line after the level contents were replaced
## (undo, redo, load or clear). Recenters only if the level size changed.
func _after_level_replaced() -> void:
	_end_stroke()
	if state.selected != EditorState.NO_CELL and not level.in_bounds(state.selected.x, state.selected.y):
		state.selected = EditorState.NO_CELL
	view.rebuild_all()
	grid.rebuild(level.cols, level.rows)
	Tools.sync_brush_from_selection(state, level)
	if _centered_size != Vector2i(level.cols, level.rows): center_camera(false)
	_after_edit()


## Returns true when the selected cell exists in the grid.
func _selection_valid() -> bool:
	return state.selected != EditorState.NO_CELL and level.in_bounds(state.selected.x, state.selected.y)


## Returns the block of the selected cell, creating it from the brush when absent, and marks it non-void.
func _ensure_selected_block() -> Dictionary:
	var cell := state.selected
	var block := level.get_block(cell.x, cell.y)
	if block.is_empty():
		block = BlockData.make(cell.x, cell.y, {
			"elevation": state.brush["elevation"],
			"subHeights": [[0, 0, 0], [0, 0, 0], [0, 0, 0]],
		})
		level.set_block(cell.x, cell.y, block)
	block["isVoid"] = false
	return block


## Connects the UI signals to the editor actions.
func _connect_ui() -> void:
	ui.tool_requested.connect(func(tool: int) -> void: state.tool = tool as EditorState.Tool)
	ui.camera_mode_requested.connect(func(mode: int) -> void: rig.set_mode(mode as CameraRig.Mode))
	ui.camera_reset_requested.connect(func() -> void: rig.reset_arcade_view())
	ui.undo_requested.connect(undo)
	ui.redo_requested.connect(redo)
	ui.palette_picked.connect(apply_palette_pick)
	ui.inspector_changed.connect(apply_inspector_value)
	ui.subtile_changed.connect(apply_subtile_value)
	ui.grid_toggle_requested.connect(toggle_grid)
	ui.clear_requested.connect(clear_level)
	ui.open_path_chosen.connect(func(path: String) -> void: load_level_from_file(path))
	ui.save_path_chosen.connect(func(path: String) -> void: save_level_to_file(path))


## Adds black background, ambient light, the sun with shadows and the blue fill light.
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = AMBIENT_ENERGY
	var world_env := WorldEnvironment.new()
	world_env.name = "WorldEnvironment"
	world_env.environment = env
	add_child(world_env)
	var sun := _make_light("Sun", SUN_COLOR, SUN_ENERGY, SUN_POSITION)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	sun.shadow_bias = 0.05
	add_child(sun)
	add_child(_make_light("Fill", FILL_COLOR, FILL_ENERGY, FILL_POSITION))


## Creates a directional light that shines from a position toward the origin.
func _make_light(light_name: String, color: Color, energy: float, from: Vector3) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.name = light_name
	light.light_color = color
	light.light_energy = energy
	light.transform = Transform3D(Basis.looking_at(-from, Vector3.UP), from)
	return light


## Prepares a flat translucent cursor quad the size of one cell.
func _build_cursor(cursor: MeshInstance3D, color: Color) -> void:
	var quad := PlaneMesh.new()
	quad.size = Vector2.ONE * Constants.BLOCK_SIZE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = color
	quad.material = mat
	cursor.mesh = quad
	cursor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cursor.visible = false
	add_child(cursor)


## Moves a cursor onto a cell, or hides it for a cell outside the grid.
func _place_cursor(cursor: MeshInstance3D, cell: Vector2i) -> void:
	cursor.visible = cell != EditorState.NO_CELL and level.in_bounds(cell.x, cell.y)
	if not cursor.visible: return
	var block := level.get_block(cell.x, cell.y)
	var height: float = block.get("elevation", BlockData.defaults()["elevation"])
	cursor.position = LevelView.grid_to_world(cell.x, cell.y) + Vector3(Constants.BLOCK_SIZE / 2.0, height + CURSOR_LIFT, Constants.BLOCK_SIZE / 2.0)
