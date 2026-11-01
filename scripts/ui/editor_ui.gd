class_name EditorUI
extends Control
## Editor interface built in code: top bar, palettes, inspector, HUD and coordinates badge.
## It only reads the editor state and emits signals; EditorRoot applies every edit.

## Emitted when a tool button is pressed (value is an EditorState.Tool).
signal tool_requested(tool: int)
## Emitted when a camera mode button is pressed (value is a CameraRig.Mode).
signal camera_mode_requested(mode: int)
## Emitted when the Arcade View button is pressed.
signal camera_reset_requested
## Emitted when the undo button is pressed.
signal undo_requested
## Emitted when the redo button is pressed.
signal redo_requested
## Emitted when a palette item is clicked (kind is "shape", "element" or "decal").
signal palette_picked(kind: String, id: String)
## Emitted when an inspector value is committed (prop is a block property name).
signal inspector_changed(prop: String, value: Variant)
## Emitted when a sub-height field is committed.
signal subtile_changed(row: int, col: int, value: float)
## Emitted when the Grid button is pressed.
signal grid_toggle_requested
## Emitted when the Clear button is pressed.
signal clear_requested
## Emitted when a file is chosen in the open dialog.
signal open_path_chosen(path: String)
## Emitted when a file is chosen in the save dialog.
signal save_path_chosen(path: String)

## Width of the side panels in pixels.
const LEFT_PANEL_WIDTH := 236
const RIGHT_PANEL_WIDTH := 272
## Palette grid columns.
const PALETTE_COLUMNS := 2
## Rotation choices of the rotation button groups.
const ROTATIONS: Array[int] = [0, 90, 180, 270]
## Sub-height matrix size.
const SUBTILE_SIZE := 3
## Colors adapted from css/style.css.
const COLOR_BG_DARK := Color("0f1117")
const COLOR_BG_PANEL := Color("171a24")
const COLOR_BG_CARD := Color("202534")
const COLOR_BG_HOVER := Color("2a3146")
const COLOR_BORDER := Color("2e364f")
const COLOR_ACCENT := Color("ff4757")
const COLOR_TEXT := Color("f1f2f6")
const COLOR_MUTED := Color("9aa3b8")
const COLOR_DISABLED := Color("5b6378")
## Default UI font size.
const FONT_SIZE := 13

## Tool buttons: text key and tool value.
const TOOL_BUTTONS: Array = [
	["tool_select", EditorState.Tool.SELECT],
	["tool_paint_block", EditorState.Tool.PAINT_BLOCK],
	["tool_paint_element", EditorState.Tool.PAINT_ELEMENT],
	["tool_paint_decal", EditorState.Tool.PAINT_DECAL],
	["tool_erase", EditorState.Tool.ERASE],
	["tool_pick", EditorState.Tool.PICK],
]
## Slider rows: text key, block property, min, max, slider step, +/- button step.
const SLIDER_ROWS: Array = [
	["lbl_elevation", "elevation", -4.0, 24.0, 0.25, 0.25],
	["lbl_slope", "slope", -4.0, 4.0, 0.1, 0.2],
	["lbl_tilt", "tilt", -4.0, 4.0, 0.1, 0.2],
]
## Rotation groups: text key and brush property.
const ROTATION_ROWS: Array = [
	["lbl_block_rot", "rotation"],
	["lbl_elem_rot", "elemRotation"],
	["lbl_decal_rot", "decalRotation"],
]
## Palette sections: title key, brush key, ids and label key prefix.
const PALETTES: Array = [
	["sec_shapes_title", "shape", Constants.SHAPE_IDS, "shape_"],
	["sec_elements_title", "element", Constants.ELEMENT_IDS, "elem_"],
	["sec_decals_title", "decal", Constants.DECAL_IDS, "decal_"],
]
## English texts, keyed like the I18N table in js/main.js (no emoji: the default font lacks them).
const TEXTS := {
	"brand_title": "MARBLE MADNESS 3D EDITOR",
	"brand_badge": "3x3 BLOCK GRID",
	"tool_select": "Select",
	"tool_select_title": "Select and edit block (Key 1)",
	"tool_paint_block": "Block Brush",
	"tool_paint_block_title": "Paint 3x3 blocks (Key 2)",
	"tool_paint_element": "Place Element",
	"tool_paint_element_title": "Place 3D Elements like tubes, cones, flags (Key 3)",
	"tool_paint_decal": "Place Decal",
	"tool_paint_decal_title": "Apply Decals like arrows, GOAL, numbers 4-5-6 (Key 4)",
	"tool_erase": "Eraser",
	"tool_erase_title": "Remove block / Create void (Key 5)",
	"tool_pick": "Copy",
	"tool_pick_title": "Eyedropper: copy properties from block",
	"cam_ortho": "Isometric",
	"cam_ortho_title": "Arcade-faithful Isometric Orthographic Camera",
	"cam_persp": "Perspective",
	"cam_persp_title": "3D Perspective Camera",
	"cam_reset": "Arcade View",
	"cam_reset_title": "Align view to original Arcade framing",
	"toggle_grid": "Grid",
	"toggle_grid_title": "Show/Hide base grid",
	"undo": "Undo",
	"undo_title": "Undo (Ctrl+Z)",
	"redo": "Redo",
	"redo_title": "Redo (Ctrl+Y)",
	"load_preset": "Level 1",
	"load_preset_title": "Reload full Level 01 map from reference image",
	"clear_map": "Clear",
	"clear_map_title": "Clear the map",
	"export_json": "JSON open",
	"export_json_title": "Import a 3D Level (JSON)",
	"save_json": "JSON save",
	"save_json_title": "Export the 3D Level (JSON)",
	"file_filter": "Level JSON (*.json)",
	"dlg_open_title": "Open level JSON",
	"dlg_save_title": "Save level JSON",
	"dlg_error_title": "Error",
	"err_invalid_json": "Invalid level: ",
	"err_save_failed": "Cannot save the level: ",
	"err_load_failed": "Cannot read the file: ",
	"lang_toggle_btn": "EN",
	"lang_toggle_title": "Switch language to Italiano (IT)",
	"sec_shapes_title": "1. 3x3 Block Profile",
	"sec_elements_title": "2. 3D Elements on Block",
	"sec_decals_title": "3. Surface Decals",
	"coords_prefix": "3x3 Block",
	"coords_empty": "Empty",
	"slope_short": "S",
	"hud_mouse": "L-Click Select / Apply   -   R-Drag Rotate   -   M-Drag Pan   -   Wheel Zoom",
	"hud_keys": "W/S Block Height   -   A/D Slope   -   Q/E Tilt   -   R Rotate 90   -   Del Delete",
	"inspector_no_block": "No Block",
	"inspector_block": "Block",
	"inspector_empty_suffix": "(Empty)",
	"lbl_elevation": "Base Height (Y)",
	"lbl_slope": "Slope (Primary)",
	"lbl_tilt": "Lateral Tilt",
	"lbl_block_rot": "Block & Slope Rotation (Key R)",
	"sec_orient_title": "Element & Decal Orientation",
	"lbl_elem_rot": "3D Element Rotation (Tubes / Cones / Flags)",
	"lbl_decal_rot": "Surface Decal Rotation (Arrows / Numbers)",
	"sec_subtiles_title": "3x3 Sub-Blocks (Offset dY)",
	"shape_flat": "Flat / Ramp",
	"shape_chute_leg_x": "White Ramp R",
	"shape_chute_leg_z": "Shadow Chute L",
	"shape_fold_right": "Sharp Turn R",
	"shape_fold_left": "Dark Turn L",
	"shape_wing_left": "45 deg Wing Tip L",
	"shape_chute_funnel": "Chute Funnel",
	"shape_pit_stepped": "Stepped Pit",
	"shape_goal_bevel": "GOAL Tip",
	"shape_pit": "Pit (Rim Wall)",
	"shape_subtiles_custom": "3x3 Sub-Grid",
	"elem_none": "No Element",
	"elem_tube_straight": "Straight Tube",
	"elem_tube_corner": "L-Corner Tube",
	"elem_tube_u": "U-Shape Tube",
	"elem_cone_small": "Small Pyramid",
	"elem_cone_large": "Large Pyramid",
	"elem_goal_flags": "GOAL Flags",
	"elem_marble_start": "Start Marble",
	"decal_none": "No Decal",
	"decal_arrow_wide_diag": "Large Arrow",
	"decal_arrow_wide_ortho": "Straight Arrow",
	"decal_arrow_long_chevrons": "Chevron Arrow",
	"decal_arrow_shaft_only": "Arrow Shaft",
	"decal_pad_456": "Numbers 4-5-6",
	"decal_goal_banner": "GOAL Banner",
}

var _state: EditorState
var _level: LevelData
var _history: History
## Buttons by text key (tool_*, cam_*, undo, ...), used by tests and by refresh.
var _buttons: Dictionary = {}
## Tool buttons by tool value.
var _tool_buttons: Dictionary = {}
## Camera mode buttons by CameraRig.Mode value.
var _mode_buttons: Dictionary = {}
## Palette buttons by brush key, then by id.
var _palette_buttons: Dictionary = {}
## Inspector sliders, value labels and +/- buttons by property.
var _sliders: Dictionary = {}
var _slider_labels: Dictionary = {}
## Rotation buttons by property, then by angle.
var _rotation_buttons: Dictionary = {}
## Sub-height fields in row-major order.
var _subtile_fields: Array[SpinBox] = []
## Controls with text from the TEXTS table: [control, key, property].
var _texts: Array = []
var _title_label: Label
## File dialogs and the error dialog, created in _build_dialogs.
var open_dialog: FileDialog
var save_dialog: FileDialog
var _error_dialog: AcceptDialog
var _coords_label: Label
## True while refresh writes values, so widgets do not emit change signals.
var _syncing := false
## True while a mouse button is held: slider and spin box changes are committed on release.
var _mouse_down := false
## Sub-height edits made during the current mouse press, as [row, col] -> value.
var _pending_subtiles: Dictionary = {}


## Builds the whole interface. Call once, then bind.
func _init() -> void:
	name = "EditorUI"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = _build_theme()
	_build_layout()
	_build_dialogs()
	_apply_texts()


## Tracks the mouse button state and commits held spin box edits on release.
func _input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton): return
	_mouse_down = event.pressed
	if event.pressed: return
	var pending := _pending_subtiles
	_pending_subtiles = {}
	for cell in pending: subtile_changed.emit(cell[0], cell[1], pending[cell])


## Connects the UI to the editor state and refreshes every widget.
func bind(state: EditorState, level: LevelData, history: History) -> void:
	_state = state
	_level = level
	_history = history
	refresh()


## Returns the button registered under a text key, or null.
func get_button(key: String) -> Button:
	return _buttons.get(key)


## Returns the inspector slider of a block property.
func get_slider(prop: String) -> HSlider:
	return _sliders[prop]


## Returns the sub-height field at a row-major index.
func get_subtile_field(index: int) -> SpinBox:
	return _subtile_fields[index]


## Updates every widget from the state, the selected block and the history.
func refresh() -> void:
	if _state == null: return
	_syncing = true
	_refresh_tools()
	_refresh_palettes()
	_refresh_inspector()
	_buttons["undo"].disabled = not _history.can_undo()
	_buttons["redo"].disabled = not _history.can_redo()
	_syncing = false


## Shows the pressed state of the Grid button without emitting.
func set_grid_active(active: bool) -> void:
	_buttons["toggle_grid"].set_pressed_no_signal(active)


## Shows a modal error dialog. The text key gives the message prefix and detail is appended to it.
func show_error(text_key: String, detail: String) -> void:
	_error_dialog.dialog_text = _t(text_key) + detail
	_error_dialog.popup_centered()


## Returns true while the error dialog is open.
func is_error_visible() -> bool:
	return _error_dialog.visible


## Returns the text of the error dialog.
func get_error_text() -> String:
	return _error_dialog.dialog_text


## Closes the error dialog.
func hide_error() -> void:
	_error_dialog.hide()


## Updates the camera mode buttons.
func set_camera_mode(mode: int) -> void:
	for m in _mode_buttons:
		_mode_buttons[m].set_pressed_no_signal(m == mode)


## Shows the hovered cell in the coordinates badge; NO_CELL shows dashes.
func set_hover_cell(cell: Vector2i) -> void:
	var prefix := _t("coords_prefix")
	if cell == EditorState.NO_CELL or _level == null:
		_coords_label.text = "%s [-, -]" % prefix
		return
	var block := _level.get_block(cell.x, cell.y)
	var info := _t("coords_empty")
	if not block.is_empty() and block.get("isVoid", false) != true:
		info = "Y:%.1f %s:%.1f" % [float(block["elevation"]), _t("slope_short"), float(block["slope"])]
	_coords_label.text = "%s [%d, %d] - %s" % [prefix, cell.x, cell.y, info]


## Returns the English text of a key. Task 13 replaces the body with the translation lookup.
func _t(key: String) -> String:
	return TEXTS.get(key, key)


## Re-applies every registered text, for example after a language change.
func _apply_texts() -> void:
	for entry in _texts:
		entry[0].set(entry[2], _t(entry[1]))


## Registers a control property that shows the text of a key.
func _bind_text(control: Object, key: String, property: String = "text") -> void:
	_texts.append([control, key, property])


## Creates a label showing the text of a key.
func _make_label(key: String, muted: bool = false, wrap: bool = false) -> Label:
	var label := Label.new()
	if wrap: label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if muted: label.add_theme_color_override("font_color", COLOR_MUTED)
	_bind_text(label, key)
	return label


## Creates a button with text and tooltip keys, registered under the text key.
func _make_button(key: String, toggle: bool = false) -> Button:
	var button := Button.new()
	button.toggle_mode = toggle
	button.focus_mode = Control.FOCUS_NONE
	_bind_text(button, key)
	if TEXTS.has(key + "_title"): _bind_text(button, key + "_title", "tooltip_text")
	_buttons[key] = button
	return button


## Creates a layout container that lets the mouse through to the 3D view.
func _pass_through(container: Control) -> Control:
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


## Builds the three areas: top bar, side panels and the central overlay.
func _build_layout() -> void:
	var column := _pass_through(VBoxContainer.new())
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(column)
	column.add_child(_build_top_bar())
	var middle := _pass_through(HBoxContainer.new())
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(middle)
	middle.add_child(_build_left_panel())
	middle.add_child(_build_center())
	middle.add_child(_build_right_panel())


## Builds the top bar with tools, camera buttons and actions.
func _build_top_bar() -> Control:
	var panel := PanelContainer.new()
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)
	panel.add_child(flow)
	var brand := _make_label("brand_title")
	brand.add_theme_color_override("font_color", COLOR_ACCENT)
	flow.add_child(brand)
	flow.add_child(_make_label("brand_badge", true))
	for entry in TOOL_BUTTONS:
		var button := _make_button(entry[0], true)
		button.pressed.connect(func() -> void: tool_requested.emit(entry[1]); refresh())
		_tool_buttons[entry[1]] = button
		flow.add_child(button)
	flow.add_child(VSeparator.new())
	_add_camera_buttons(flow)
	var grid := _make_button("toggle_grid", true)
	grid.pressed.connect(func() -> void: grid_toggle_requested.emit())
	flow.add_child(grid)
	var undo := _make_button("undo")
	undo.pressed.connect(func() -> void: undo_requested.emit())
	flow.add_child(undo)
	var redo := _make_button("redo")
	redo.pressed.connect(func() -> void: redo_requested.emit())
	flow.add_child(redo)
	flow.add_child(VSeparator.new())
	for key in ["load_preset", "clear_map", "export_json", "save_json", "lang_toggle_btn"]:
		flow.add_child(_make_button(key))
	_buttons["clear_map"].pressed.connect(func() -> void: clear_requested.emit())
	_buttons["export_json"].pressed.connect(func() -> void: open_dialog.popup_centered_ratio(0.6))
	_buttons["save_json"].pressed.connect(func() -> void: save_dialog.popup_centered_ratio(0.6))
	for key in ["load_preset", "lang_toggle_btn"]:
		_buttons[key].disabled = true
	return panel


## Creates the open and save file dialogs and the error dialog.
func _build_dialogs() -> void:
	open_dialog = _make_file_dialog("OpenDialog", FileDialog.FILE_MODE_OPEN_FILE, "dlg_open_title")
	open_dialog.file_selected.connect(func(path: String) -> void: open_path_chosen.emit(path))
	save_dialog = _make_file_dialog("SaveDialog", FileDialog.FILE_MODE_SAVE_FILE, "dlg_save_title")
	save_dialog.file_selected.connect(func(path: String) -> void: save_path_chosen.emit(path))
	_error_dialog = AcceptDialog.new()
	_error_dialog.name = "ErrorDialog"
	_bind_text(_error_dialog, "dlg_error_title", "title")
	add_child(_error_dialog)


## Creates one file dialog on the real file system filtered to JSON files.
func _make_file_dialog(dialog_name: String, mode: FileDialog.FileMode, title_key: String) -> FileDialog:
	var dialog := FileDialog.new()
	dialog.name = dialog_name
	dialog.file_mode = mode
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.filters = PackedStringArray(["*.json ; %s" % _t("file_filter")])
	_bind_text(dialog, title_key, "title")
	add_child(dialog)
	return dialog


## Adds the Isometric, Perspective and Arcade View buttons.
func _add_camera_buttons(parent: Control) -> void:
	var ortho := _make_button("cam_ortho", true)
	ortho.pressed.connect(func() -> void: camera_mode_requested.emit(CameraRig.Mode.ORTHO); set_camera_mode(CameraRig.Mode.ORTHO))
	var persp := _make_button("cam_persp", true)
	persp.pressed.connect(func() -> void: camera_mode_requested.emit(CameraRig.Mode.PERSP); set_camera_mode(CameraRig.Mode.PERSP))
	var reset := _make_button("cam_reset")
	reset.pressed.connect(func() -> void: camera_reset_requested.emit())
	_mode_buttons[CameraRig.Mode.ORTHO] = ortho
	_mode_buttons[CameraRig.Mode.PERSP] = persp
	ortho.set_pressed_no_signal(true)
	for button in [ortho, persp, reset]: parent.add_child(button)


## Builds the left panel with the three palettes.
func _build_left_panel() -> Control:
	var panel := _make_panel(LEFT_PANEL_WIDTH)
	var box := _panel_box(panel)
	for entry in PALETTES:
		var title := _make_label(entry[0], false, true)
		title.add_theme_color_override("font_color", COLOR_MUTED)
		box.add_child(title)
		box.add_child(_build_palette(entry[1], entry[2], entry[3]))
	return panel


## Builds one palette grid whose buttons set a brush value.
func _build_palette(brush_key: String, ids: Array, prefix: String) -> Control:
	var grid := GridContainer.new()
	grid.columns = PALETTE_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	_palette_buttons[brush_key] = {}
	for id in ids:
		var button := _make_button(prefix + id, true)
		button.clip_text = true
		button.custom_minimum_size = Vector2(100, 30)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: palette_picked.emit(brush_key, id); refresh())
		_palette_buttons[brush_key][id] = button
		grid.add_child(button)
	return grid


## Builds the transparent center area holding the coordinates badge and the HUD hints.
func _build_center() -> Control:
	var center := _pass_through(MarginContainer.new())
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("margin_left", 10)
	center.add_theme_constant_override("margin_right", 10)
	center.add_theme_constant_override("margin_top", 8)
	center.add_theme_constant_override("margin_bottom", 8)
	var column := _pass_through(VBoxContainer.new())
	center.add_child(column)
	_coords_label = Label.new()
	_coords_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_coords_label.text = "3x3 Block [-, -]"
	_add_outline(_coords_label)
	column.add_child(_coords_label)
	var spacer := _pass_through(Control.new())
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(spacer)
	for key in ["hud_mouse", "hud_keys"]:
		var hint := _make_label(key, true, true)
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_add_outline(hint)
		column.add_child(hint)
	return center


## Gives an overlay label a dark outline so it stays readable over the 3D view.
func _add_outline(label: Label) -> void:
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)


## Builds the right panel with the block inspector.
func _build_right_panel() -> Control:
	var panel := _make_panel(RIGHT_PANEL_WIDTH)
	var box := _panel_box(panel)
	_title_label = Label.new()
	_title_label.add_theme_color_override("font_color", COLOR_ACCENT)
	_title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_title_label)
	for entry in SLIDER_ROWS: box.add_child(_build_slider_row(entry))
	box.add_child(_build_rotation_row(ROTATION_ROWS[0]))
	box.add_child(HSeparator.new())
	box.add_child(_make_label("sec_orient_title", false, true))
	box.add_child(_build_rotation_row(ROTATION_ROWS[1]))
	box.add_child(_build_rotation_row(ROTATION_ROWS[2]))
	box.add_child(HSeparator.new())
	box.add_child(_make_label("sec_subtiles_title", false, true))
	box.add_child(_build_subtile_grid())
	return panel


## Creates a side panel holding a scroll area with a vertical box.
func _make_panel(width: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = width
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	scroll.add_child(box)
	return panel


## Returns the vertical box inside a panel made by _make_panel.
func _panel_box(panel: PanelContainer) -> VBoxContainer:
	return panel.get_child(0).get_child(0)


## Builds a labelled slider with -/+ buttons for one block property.
func _build_slider_row(entry: Array) -> Control:
	var prop: String = entry[1]
	var column := VBoxContainer.new()
	var header := HBoxContainer.new()
	var name_label := _make_label(entry[0], false, true)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(name_label)
	var value_label := Label.new()
	value_label.custom_minimum_size.x = 48
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", COLOR_ACCENT)
	header.add_child(value_label)
	column.add_child(header)
	var row := HBoxContainer.new()
	var slider := HSlider.new()
	slider.min_value = entry[2]
	slider.max_value = entry[3]
	slider.step = entry[4]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.scrollable = false
	slider.drag_ended.connect(func(changed: bool) -> void: _on_slider_drag_ended(prop, slider, changed))
	slider.value_changed.connect(func(value: float) -> void: _on_slider_value_changed(prop, value))
	for sign_value in [-1.0, 1.0]:
		var step_button := Button.new()
		step_button.text = "-" if sign_value < 0.0 else "+"
		step_button.focus_mode = Control.FOCUS_NONE
		step_button.custom_minimum_size.x = 28
		step_button.pressed.connect(func() -> void: _on_step_pressed(prop, sign_value * entry[5]))
		if sign_value < 0.0: row.add_child(step_button)
		else:
			row.add_child(slider)
			row.add_child(step_button)
	column.add_child(row)
	_sliders[prop] = slider
	_slider_labels[prop] = value_label
	return column


## Builds a labelled row of four rotation buttons for one brush property.
func _build_rotation_row(entry: Array) -> Control:
	var prop: String = entry[1]
	var column := VBoxContainer.new()
	column.add_child(_make_label(entry[0], false, true))
	var row := HBoxContainer.new()
	_rotation_buttons[prop] = {}
	for angle in ROTATIONS:
		var button := Button.new()
		button.text = "%d" % angle
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(func() -> void: inspector_changed.emit(prop, angle); refresh())
		_rotation_buttons[prop][angle] = button
		row.add_child(button)
	column.add_child(row)
	return column


## Builds the 3x3 grid of sub-height number fields.
func _build_subtile_grid() -> Control:
	var grid := GridContainer.new()
	grid.columns = SUBTILE_SIZE
	for r in SUBTILE_SIZE:
		for c in SUBTILE_SIZE:
			var field := SpinBox.new()
			field.min_value = -50.0
			field.max_value = 50.0
			field.step = 0.5
			field.custom_minimum_size.x = 76
			field.value_changed.connect(func(value: float) -> void: _on_subtile_changed(r, c, value))
			_subtile_fields.append(field)
			grid.add_child(field)
	return grid


## Updates the value label while the slider moves and commits keyboard changes.
func _on_slider_value_changed(prop: String, value: float) -> void:
	_slider_labels[prop].text = "%.1f" % value
	if _syncing or _mouse_down: return
	inspector_changed.emit(prop, value)


## Commits a slider drag once, when the mouse is released.
func _on_slider_drag_ended(prop: String, slider: HSlider, changed: bool) -> void:
	if not changed: return
	inspector_changed.emit(prop, slider.value)


## Commits a +/- button press as a new absolute value.
func _on_step_pressed(prop: String, delta: float) -> void:
	if _state == null: return
	var value := floorf((float(_state.brush[prop]) + delta) * 100.0 + 0.5) / 100.0
	inspector_changed.emit(prop, value)


## Commits a sub-height field edit.
func _on_subtile_changed(row: int, col: int, value: float) -> void:
	if _syncing: return
	if _mouse_down:
		_pending_subtiles[[row, col]] = value
		return
	subtile_changed.emit(row, col, value)


## Presses the button of the active tool and releases the others.
func _refresh_tools() -> void:
	for t in _tool_buttons:
		_tool_buttons[t].set_pressed_no_signal(t == _state.tool)


## Highlights the palette item matching each brush value.
func _refresh_palettes() -> void:
	for brush_key in _palette_buttons:
		for id in _palette_buttons[brush_key]:
			_palette_buttons[brush_key][id].set_pressed_no_signal(id == _state.brush[brush_key])


## Updates the inspector title, sliders, rotation buttons and sub-height fields.
func _refresh_inspector() -> void:
	var cell := _state.selected
	if cell == EditorState.NO_CELL:
		_title_label.text = _t("inspector_no_block")
	else:
		var block := _level.get_block(cell.x, cell.y)
		var empty: bool = block.is_empty() or block.get("isVoid", false) == true
		_title_label.text = "%s [%d, %d] %s" % [_t("inspector_block"), cell.x, cell.y, _t("inspector_empty_suffix") if empty else ""]
	for prop in _sliders:
		var value := float(_state.brush[prop])
		_sliders[prop].value = value
		_slider_labels[prop].text = "%.1f" % value
	for prop in _rotation_buttons:
		for angle in _rotation_buttons[prop]:
			_rotation_buttons[prop][angle].set_pressed_no_signal(angle == int(_state.brush[prop]))
	var heights: Array = _state.brush["subHeights"]
	for i in _subtile_fields.size():
		_subtile_fields[i].value = float(heights[floori(float(i) / SUBTILE_SIZE)][i % SUBTILE_SIZE])


## Builds the dark UI theme adapted from css/style.css.
func _build_theme() -> Theme:
	var built := Theme.new()
	built.default_font_size = FONT_SIZE
	built.set_color("font_color", "Label", COLOR_TEXT)
	for state_name in ["normal", "hover", "pressed", "disabled", "hover_pressed"]:
		built.set_stylebox(state_name, "Button", _box(_button_color(state_name), COLOR_BORDER, 4, 6))
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		built.set_color(color_name, "Button", COLOR_TEXT)
	built.set_color("font_disabled_color", "Button", COLOR_DISABLED)
	built.set_stylebox("panel", "PanelContainer", _box(COLOR_BG_PANEL, COLOR_BORDER, 0, 8))
	return built


## Returns the background color of a button state.
func _button_color(state_name: String) -> Color:
	match state_name:
		"hover": return COLOR_BG_HOVER
		"pressed", "hover_pressed": return COLOR_ACCENT.darkened(0.35)
		"disabled": return COLOR_BG_DARK
	return COLOR_BG_CARD


## Returns a flat style box with border, radius and content margin.
func _box(fill: Color, border: Color, radius: int, margin: int) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(radius)
	box.set_content_margin_all(margin)
	return box
