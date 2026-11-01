extends TestCase
## Tests for the EN/IT translation table and its use by the editor UI.

const UI_SOURCES: Array[String] = ["res://scripts/ui/editor_ui.gd", "res://scripts/editor/editor_root.gd"]
const SCENE_PATH := "res://scenes/editor.tscn"


## Both languages define exactly the same keys.
func test_en_and_it_have_same_keys() -> void:
	var en := I18n.keys_of("en")
	var it := I18n.keys_of("it")
	assert_true(en.size() > 50, "table is not empty")
	for key in en: assert_true(it.has(key), "it has %s" % key)
	for key in it: assert_true(en.has(key), "en has %s" % key)
	assert_eq(I18n.keys().size(), en.size(), "keys() lists each key once")


## A missing key returns the key itself.
func test_missing_key_returns_key() -> void:
	assert_eq(I18n.t("no_such_key_xyz"), "no_such_key_xyz", "missing key")
	assert_true(not I18n.has("no_such_key_xyz"), "has is false")


## Switching language changes the text, and the default language is English.
func test_switch_language_changes_text() -> void:
	assert_eq(I18n.language(), "en", "default language")
	var english := I18n.t("tool_select")
	I18n.set_language("it")
	var italian := I18n.t("tool_select")
	assert_eq(I18n.language(), "it", "language is it")
	I18n.set_language("en")
	assert_true(english != italian, "tool_select differs")
	assert_eq(I18n.t("tool_select"), english, "back to english")


## An unsupported language keeps the current one.
func test_unsupported_language_keeps_current() -> void:
	I18n.set_language("it")
	I18n.set_language("fr")
	assert_eq(I18n.language(), "it", "still it")
	I18n.set_language("en")
	I18n.set_language("")
	assert_eq(I18n.language(), "en", "still en")


## Every palette label key resolves to real text in both languages.
func test_every_palette_label_key_exists() -> void:
	var groups := [["shape_", Constants.SHAPE_IDS], ["elem_", Constants.ELEMENT_IDS], ["decal_", Constants.DECAL_IDS]]
	for lang in I18n.LANGUAGES:
		I18n.set_language(lang)
		for group in groups:
			for id in group[1]:
				var key: String = group[0] + id
				assert_true(I18n.t(key) != key, "%s resolves in %s" % [key, lang])
	I18n.set_language("en")


## No text contains the long dash character.
func test_no_long_dash() -> void:
	for lang in I18n.LANGUAGES:
		for key in I18n.keys_of(lang):
			assert_true(not I18n.table_of(lang)[key].contains("—"), "no long dash in %s/%s" % [lang, key])


## Every key the UI uses (registered controls and literal lookups in the sources) exists in both languages.
func test_every_ui_key_exists_in_both_languages() -> void:
	var root := await _make_editor()
	var used: Array = root.ui.used_keys()
	var regex := RegEx.create_from_string("(?:_t|show_error)\\(\"(\\w+)\"")
	for path in UI_SOURCES:
		for m in regex.search_all(FileAccess.get_file_as_string(path)):
			assert_true(used.has(m.get_string(1)), "used_keys lists %s from %s" % [m.get_string(1), path])
	assert_true(used.size() > 50, "used keys collected")
	for lang in I18n.LANGUAGES:
		for key in used:
			assert_true(I18n.keys_of(lang).has(key), "%s defined in %s" % [key, lang])
	await _free_editor(root)


## The language button cycles EN and IT and re-labels buttons, tooltips, inspector, coords, HUD and dialogs.
func test_language_button_relabels_ui() -> void:
	var root := await _make_editor()
	var ui: EditorUI = root.ui
	var btn := ui.get_button("lang_toggle_btn")
	assert_true(not btn.disabled, "language button enabled")
	assert_eq(btn.text, "EN", "shows EN")
	var select_en := ui.get_button("tool_select").text
	var tip_en := ui.get_button("tool_select").tooltip_text
	var palette_en := ui.get_button("shape_flat").text
	var coords_en := ui.get_coords_text()
	var inspector_en := ui.get_inspector_title()
	var hud_en := ui.get_hud_text()
	ui.show_error("err_invalid_json", "x")
	var error_en := ui.get_error_text()
	btn.pressed.emit()
	assert_eq(I18n.language(), "it", "switched to it")
	assert_eq(btn.text, "IT", "shows IT")
	assert_eq(ui.get_button("tool_select").text, I18n.t("tool_select"), "tool text")
	assert_true(ui.get_button("tool_select").text != select_en, "tool text changed")
	assert_true(ui.get_button("tool_select").tooltip_text != tip_en, "tooltip changed")
	assert_true(ui.get_button("shape_flat").text != palette_en, "palette text changed")
	assert_true(ui.get_coords_text() != coords_en, "coords changed")
	assert_true(ui.get_inspector_title() != inspector_en, "inspector changed")
	assert_true(ui.get_hud_text() != hud_en, "hud changed")
	assert_true(ui.get_error_text() != error_en, "error dialog changed")
	assert_eq(ui.get_dialog_title("open"), I18n.t("dlg_open_title"), "open dialog title")
	assert_true(ui.get_dialog_filter().contains(I18n.t("file_filter")), "filter label")
	btn.pressed.emit()
	assert_eq(I18n.language(), "en", "back to en")
	assert_eq(ui.get_button("tool_select").text, select_en, "english restored")
	assert_eq(ui.get_coords_text(), coords_en, "coords restored")
	I18n.set_language("en")
	await _free_editor(root)


## The hovered cell info uses translated labels.
func test_coords_follow_language() -> void:
	var root := await _make_editor()
	root.state.tool = EditorState.Tool.PAINT_BLOCK
	root.paint_cell(Vector2i(2, 2))
	root.ui.set_hover_cell(Vector2i(2, 2))
	assert_true(root.ui.get_coords_text().contains(" S:"), "english slope label")
	I18n.set_language("it")
	root.ui.refresh_texts()
	assert_true(root.ui.get_coords_text().contains(" P:"), "italian slope label")
	assert_true(root.ui.get_coords_text().begins_with(I18n.t("coords_prefix")), "italian prefix")
	I18n.set_language("en")
	await _free_editor(root)


## Instantiates the editor scene in the tree and waits a frame so _ready has run.
func _make_editor() -> EditorRoot:
	I18n.set_language("en")
	var root := (load(SCENE_PATH) as PackedScene).instantiate() as EditorRoot
	tree.root.add_child(root)
	await tree.process_frame
	return root


## Frees the scene and waits for the deletion to complete.
func _free_editor(root: EditorRoot) -> void:
	root.free()
	await tree.process_frame
