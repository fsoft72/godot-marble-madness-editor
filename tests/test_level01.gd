extends TestCase
## Tests for the Level 1 preset (data/level01.json), the loader and the reference overlay.

const LEVEL_PATH := "res://data/level01.json"
const GOLDEN_PATH := "res://tests/golden/level01_surface.json"
const SCENE_PATH := "res://scenes/editor.tscn"
const GOLDEN_EPS := 1e-4


## Reads the golden file written by tools/gen_golden.mjs: {block_count, samples}.
func _load_golden() -> Dictionary:
	var file := FileAccess.open(GOLDEN_PATH, FileAccess.READ)
	assert_true(file != null, "level01 golden opens")
	if file == null: return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	assert_true(parsed is Dictionary, "level01 golden is an object")
	if not parsed is Dictionary: return {}
	return parsed


## Loads the preset through LevelIO and returns the level (null on failure).
func _load_level() -> LevelData:
	var res := LevelIO.load_file(LEVEL_PATH)
	assert_true(res["ok"], "level01 loads: %s" % res["error"])
	return res["level"]


## Instantiates the editor scene in the tree and waits a frame.
func _make_editor() -> EditorRoot:
	var root := (load(SCENE_PATH) as PackedScene).instantiate() as EditorRoot
	tree.root.add_child(root)
	await tree.process_frame
	return root


## Frees the scene and waits for the deletion to complete.
func _free_editor(root: EditorRoot) -> void:
	root.free()
	await tree.process_frame


## The preset is a 14x14 level with as many blocks as the JS preset.
func test_level01_loads() -> void:
	var level := _load_level()
	if level == null: return
	assert_eq(level.cols, 14, "cols")
	assert_eq(level.rows, 14, "rows")
	var golden := _load_golden()
	assert_true(int(golden.get("block_count", 0)) > 0, "golden block count recorded")
	assert_eq(level.blocks.size(), int(golden.get("block_count", -1)), "block count")


## Every non-void block that is not a bare pit produces a non-empty mesh.
func test_level01_every_block_builds_mesh() -> void:
	var level := _load_level()
	if level == null: return
	var built := 0
	for k in level.blocks:
		var block: Dictionary = level.blocks[k]
		if block.get("isVoid", false) == true or block.get("shape", "") == "pit": continue
		var mesh := BlockMeshBuilder.build(block)
		assert_true(mesh.get_surface_count() > 0, "mesh for %s" % k)
		assert_true(BlockMeshBuilder.build_collision_faces(block).size() > 0, "collision for %s" % k)
		built += 1
	assert_true(built > 0, "some blocks built")


## Serialize then parse gives the same dictionary.
func test_level01_round_trip() -> void:
	var level := _load_level()
	if level == null: return
	var res := LevelIO.parse(LevelIO.serialize(level))
	assert_true(res["ok"], "reparse ok")
	assert_true(res["level"].to_dict() == level.to_dict(), "round trip equal")


## surface_y samples taken from the JS preset match.
func test_level01_surface_golden() -> void:
	var level := _load_level()
	if level == null: return
	var golden := _load_golden()
	var samples: Array = golden.get("samples", [])
	assert_true(samples.size() > 100, "golden has samples")
	for s in samples:
		var block := level.get_block(int(s["bx"]), int(s["bz"]))
		assert_true(not block.is_empty(), "block %s,%s exists" % [s["bx"], s["bz"]])
		assert_near(BlockSurface.surface_y(block, s["u"], s["v"]), s["y"], GOLDEN_EPS, "y at %s,%s u=%s v=%s" % [s["bx"], s["bz"], s["u"], s["v"]])


## load_level01 fills the level, is one undo step and undo restores the empty level.
func test_load_level01_is_undoable() -> void:
	var root := await _make_editor()
	assert_true(root.load_level01(), "load ok")
	assert_eq(root.level.blocks.size(), int(_load_golden().get("block_count", -1)), "blocks loaded")
	assert_true(root.view.block_node(5, 5) != null or root.view.get_child_count() > 0, "view rebuilt")
	root.undo()
	assert_eq(root.level.blocks.size(), 0, "undo empties")
	root.redo()
	assert_true(root.level.blocks.size() > 0, "redo restores")
	await _free_editor(root)


## load_level01 resets the camera to the arcade view around the level center.
func test_load_level01_reframes() -> void:
	var root := await _make_editor()
	root.rig.focus_on(Vector3(1, 2, 3))
	root.load_level01()
	var half := 14 * Constants.BLOCK_SIZE / 2.0
	assert_true(root.rig.focus.is_equal_approx(Vector3(half, BlockData.defaults()["elevation"], half)), "focus recentered")
	await _free_editor(root)


## The Level 1 button is enabled and loads the preset.
func test_level01_button_loads() -> void:
	var root := await _make_editor()
	var btn := root.ui.get_button("load_preset")
	assert_true(btn != null and not btn.disabled, "button enabled")
	btn.pressed.emit()
	assert_true(root.level.blocks.size() > 0, "level loaded by button")
	await _free_editor(root)


## The overlay is a hidden, mouse-transparent, semi-transparent TextureRect with the reference texture.
func test_overlay_defaults() -> void:
	var root := await _make_editor()
	var overlay := root.ui.get_overlay()
	assert_true(overlay != null, "overlay exists")
	if overlay != null:
		assert_true(overlay is TextureRect, "is TextureRect")
		assert_true(not overlay.visible, "hidden by default")
		assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE, "ignores mouse")
		assert_true(overlay.texture != null, "has texture")
		assert_true(overlay.modulate.a > 0.0 and overlay.modulate.a < 1.0, "semi-transparent")
	await _free_editor(root)


## The overlay toggle button shows and hides the overlay.
func test_overlay_toggle() -> void:
	var root := await _make_editor()
	var btn := root.ui.get_button("toggle_overlay")
	assert_true(btn != null, "toggle button exists")
	if btn != null:
		btn.button_pressed = true
		btn.pressed.emit()
		assert_true(root.ui.get_overlay().visible, "shown")
		btn.button_pressed = false
		btn.pressed.emit()
		assert_true(not root.ui.get_overlay().visible, "hidden again")
	await _free_editor(root)
