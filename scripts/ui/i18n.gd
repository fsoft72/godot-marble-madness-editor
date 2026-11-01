class_name I18n
extends RefCounted
## EN/IT translation table ported from the I18N table in js/main.js. No emoji: the default font lacks them.
## The language is static state; the default is English, as in the JS editor.

## Supported language codes.
const LANGUAGES: Array[String] = ["en", "it"]
## Default language code.
const DEFAULT_LANGUAGE := "en"

## Translated texts by language, then by key.
const TABLES := {
	"en": {
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
		"open_json": "JSON open",
		"open_json_title": "Import a 3D Level (JSON)",
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
		"coords_y": "Y",
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
	},
	"it": {
		"brand_title": "MARBLE MADNESS 3D EDITOR",
		"brand_badge": "GRIGLIA BLOCCHI 3x3",
		"tool_select": "Seleziona",
		"tool_select_title": "Seleziona e modifica blocco (Tasto 1)",
		"tool_paint_block": "Pennello Blocco",
		"tool_paint_block_title": "Disegna blocchi 3x3 (Tasto 2)",
		"tool_paint_element": "Posiziona Elemento",
		"tool_paint_element_title": "Posiziona Elementi 3D come tubi, coni, bandiere (Tasto 3)",
		"tool_paint_decal": "Posiziona Decal",
		"tool_paint_decal_title": "Applica Decal come frecce, GOAL, numeri 4-5-6 (Tasto 4)",
		"tool_erase": "Gomma",
		"tool_erase_title": "Rimuovi blocco / Crea vuoto (Tasto 5)",
		"tool_pick": "Copia",
		"tool_pick_title": "Contagocce: copia proprietà dal blocco",
		"cam_ortho": "Isometrica",
		"cam_ortho_title": "Telecamera Isometrica Ortografica fedele all'Arcade",
		"cam_persp": "Prospettiva",
		"cam_persp_title": "Telecamera Prospettica 3D",
		"cam_reset": "Inquadratura Arcade",
		"cam_reset_title": "Allinea vista all'inquadratura originale Arcade",
		"toggle_grid": "Griglia",
		"toggle_grid_title": "Mostra/Nascondi griglia base",
		"undo": "Annulla",
		"undo_title": "Annulla (Ctrl+Z)",
		"redo": "Ripeti",
		"redo_title": "Ripeti (Ctrl+Y)",
		"load_preset": "Livello 1",
		"load_preset_title": "Ricarica la mappa completa Level 01 dall'immagine",
		"clear_map": "Svuota",
		"clear_map_title": "Svuota la mappa",
		"open_json": "Apri JSON",
		"open_json_title": "Importa un Livello 3D (JSON)",
		"save_json": "Salva JSON",
		"save_json_title": "Esporta il Livello 3D (JSON)",
		"file_filter": "Livello JSON (*.json)",
		"dlg_open_title": "Apri livello JSON",
		"dlg_save_title": "Salva livello JSON",
		"dlg_error_title": "Errore",
		"err_invalid_json": "Livello non valido: ",
		"err_save_failed": "Impossibile salvare il livello: ",
		"err_load_failed": "Impossibile leggere il file: ",
		"lang_toggle_btn": "IT",
		"lang_toggle_title": "Switch language to English (EN)",
		"sec_shapes_title": "1. Profilo Blocco 3x3",
		"sec_elements_title": "2. Elementi 3D sul Blocco",
		"sec_decals_title": "3. Decals di Superficie",
		"coords_prefix": "Blocco 3x3",
		"coords_empty": "Vuoto",
		"coords_y": "Y",
		"slope_short": "P",
		"hud_mouse": "Click SX Seleziona / Applica   -   Trascina DX Ruota   -   Trascina Centrale Panoramica   -   Rotella Zoom",
		"hud_keys": "W/S Altezza Blocco   -   A/D Pendenza   -   Q/E Angolazione   -   R Ruota 90   -   Canc Elimina",
		"inspector_no_block": "Nessun Blocco",
		"inspector_block": "Blocco",
		"inspector_empty_suffix": "(Vuoto)",
		"lbl_elevation": "Altezza Base (Y)",
		"lbl_slope": "Pendenza (Slope Principale)",
		"lbl_tilt": "Angolazione Laterale (Tilt)",
		"lbl_block_rot": "Rotazione Blocco & Pendenza (Tasto R)",
		"sec_orient_title": "Orientamento Elementi & Decal",
		"lbl_elem_rot": "Rotazione Elemento 3D (Tubi / Coni / Bandiere)",
		"lbl_decal_rot": "Rotazione Decal Superficie (Frecce / Numeri)",
		"sec_subtiles_title": "Sub-Blocchi 3x3 (Offset dY)",
		"shape_flat": "Piano / Rampa",
		"shape_chute_leg_x": "Rampa Bianca DX",
		"shape_chute_leg_z": "Canale Ombra SX",
		"shape_fold_right": "Curva Punta DX",
		"shape_fold_left": "Curva Scura SX",
		"shape_wing_left": "Ala Punta 45 gradi SX",
		"shape_chute_funnel": "Imbocco Scivolo",
		"shape_pit_stepped": "Gradoni Fossa",
		"shape_goal_bevel": "Punta GOAL",
		"shape_pit": "Buca (con Bordo)",
		"shape_subtiles_custom": "Sub-Griglia 3x3",
		"elem_none": "Nessun Elem.",
		"elem_tube_straight": "Tubo Dritto",
		"elem_tube_corner": "Tubo Angolo L",
		"elem_tube_u": "Tubo a U",
		"elem_cone_small": "Piramide Piccola",
		"elem_cone_large": "Piramide Grande",
		"elem_goal_flags": "Bandiere GOAL",
		"elem_marble_start": "Biglia Start",
		"decal_none": "Nessuna Decal",
		"decal_arrow_wide_diag": "Freccia Grande",
		"decal_arrow_wide_ortho": "Freccia Dritta",
		"decal_arrow_long_chevrons": "Freccia 3 Punte",
		"decal_arrow_shaft_only": "Asta Freccia",
		"decal_pad_456": "Griglia 4-5-6",
		"decal_goal_banner": "Scritta GOAL",
	},
}

static var _language := DEFAULT_LANGUAGE


## Returns the text of a key in the current language, falling back to English, then to the key itself.
static func t(key: String) -> String:
	var current: Dictionary = TABLES[_language]
	if current.has(key): return current[key]
	var fallback: Dictionary = TABLES[DEFAULT_LANGUAGE]
	return fallback.get(key, key)


## Returns true when the key is defined in the current language.
static func has(key: String) -> bool:
	var current: Dictionary = TABLES[_language]
	return current.has(key)


## Sets the current language ("en" or "it"). An unsupported code keeps the current language.
static func set_language(lang: String) -> void:
	if not LANGUAGES.has(lang): return
	_language = lang


## Returns the current language code.
static func language() -> String:
	return _language


## Returns every key of the default language table.
static func keys() -> Array:
	return keys_of(DEFAULT_LANGUAGE)


## Returns every key defined for a language ("en" or "it"); empty for an unknown language.
static func keys_of(lang: String) -> Array:
	if not TABLES.has(lang): return []
	var table: Dictionary = TABLES[lang]
	return table.keys()


## Returns the whole table of a language; empty for an unknown language.
static func table_of(lang: String) -> Dictionary:
	if not TABLES.has(lang): return {}
	return TABLES[lang]
