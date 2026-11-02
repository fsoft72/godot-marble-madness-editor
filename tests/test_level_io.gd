extends TestCase
## Tests for BlockData, LevelData and LevelIO.


## Serialize then parse gives an equal level.
func test_round_trip_semantic() -> void:
	var level := LevelData.new()
	level.set_block(1, 2, BlockData.make(1, 2, {"elevation": 10.5, "element": "cone_small"}))
	level.set_block(3, 4, BlockData.make(3, 4, {"rotation": 2}))
	var res := LevelIO.parse(LevelIO.serialize(level))
	assert_true(res["ok"], "parse ok")
	assert_true(res["level"].to_dict() == level.to_dict(), "dicts equal")
	assert_eq(res["level"].get_block(3, 4)["rotation"], 2, "rotation int")


## Missing cols and rows default to 14.
func test_missing_cols_rows_default_14() -> void:
	var res := LevelIO.parse('{"blocks": {}}')
	assert_true(res["ok"], "ok")
	assert_eq(res["level"].cols, 14, "cols")
	assert_eq(res["level"].rows, 14, "rows")


## Missing block fields are filled with defaults.
func test_missing_block_fields_get_defaults() -> void:
	var res := LevelIO.parse('{"blocks": {"1,2": {"bx": 1, "bz": 2}}}')
	var b: Dictionary = res["level"].get_block(1, 2)
	assert_eq(b["shape"], "flat", "shape")
	assert_eq(b["elevation"], 14.0, "elevation")
	assert_eq(b["bx"], 1, "bx int")


## Unknown keys survive a round trip.
func test_unknown_keys_preserved() -> void:
	var text := '{"extra": 1, "blocks": {"0,0": {"bx": 0, "bz": 0, "diagSplit": "main", "vGrid": [[1, 2], [3, 4]]}}}'
	var res := LevelIO.parse(LevelIO.serialize(LevelIO.parse(text)["level"]))
	var b: Dictionary = res["level"].get_block(0, 0)
	assert_eq(b["diagSplit"], "main", "diagSplit")
	assert_true(b.has("vGrid"), "vGrid")
	assert_eq(b["vGrid"][1][0], 3.0, "vGrid content")


## Invalid JSON reports an error without crashing.
func test_invalid_json_returns_error() -> void:
	var res := LevelIO.parse("{not json")
	assert_true(not res["ok"], "not ok")
	assert_true(res["error"] != "", "error message")


## Wrong top-level shapes are rejected.
func test_wrong_top_level_type() -> void:
	assert_true(not LevelIO.parse("[1,2]")["ok"], "array")
	assert_true(not LevelIO.parse("{}")["ok"], "no blocks")
	assert_true(not LevelIO.parse('{"blocks": [1]}')["ok"], "blocks array")


## Malformed block entries are skipped, valid ones kept.
func test_malformed_blocks_skipped() -> void:
	var text := '{"blocks": {"1,1": 5, "abc": {"shape": "pit"}, "x,y": {"bx": 2, "bz": 3}, "4,4": {"shape": "pit"}, "1,2,3": null}}'
	var res := LevelIO.parse(text)
	assert_true(res["ok"], "ok")
	var level: LevelData = res["level"]
	assert_eq(level.blocks.size(), 2, "two valid blocks")
	assert_eq(level.get_block(2, 3)["shape"], "flat", "bx/bz from fields")
	assert_eq(level.get_block(4, 4)["bz"], 4, "bx/bz from key")


## apply_shape clears fields set by a previous shape.
func test_apply_shape_clears_old_fields() -> void:
	var b := BlockData.make(0, 0)
	BlockData.apply_shape(b, "wing_left")
	assert_eq(b["cutout"], "wing_left", "cutout set")
	assert_eq(b["shadePreset"], "wing_dark", "preset set")
	b["subShades"] = [1]
	BlockData.apply_shape(b, "pit")
	assert_eq(b["shape"], "pit", "shape")
	assert_true(not b.has("cutout") and not b.has("shadePreset") and not b.has("subShades"), "cleared")


## snapshot/restore brings back size and blocks in place.
func test_snapshot_restore_in_place() -> void:
	var level := LevelData.new()
	level.set_block(1, 1, BlockData.make(1, 1))
	var snap := level.snapshot()
	level.cols = 8
	level.clear()
	level.restore(snap)
	assert_eq(level.cols, 14, "cols restored")
	assert_eq(level.blocks.size(), 1, "block restored")
	assert_eq(level.get_block(1, 1)["bx"], 1, "bx int")


## Bounds, clear and removal.
func test_bounds_clear_remove() -> void:
	var level := LevelData.new()
	assert_true(level.in_bounds(13, 13) and not level.in_bounds(14, 0) and not level.in_bounds(-1, 0), "bounds")
	level.set_block(0, 0, BlockData.make(0, 0))
	level.remove_block(0, 0)
	assert_true(level.get_block(0, 0).is_empty(), "removed")
	level.set_block(0, 0, BlockData.make(0, 0))
	level.clear()
	assert_eq(level.cols, 14, "size kept")
	assert_eq(level.blocks.size(), 0, "cleared")


## Wrong-typed known fields are coerced to typed values and build without engine errors.
func test_wrong_typed_values_coerced_and_buildable() -> void:
	var text := '{"cols":4,"rows":4,"blocks":{"1,1":{"bx":1,"bz":1,"isVoid":1,"elevation":null,"slope":"x","tilt":null,"shape":5,"element":null,"decal":[]},"2,2":{"bx":2,"bz":2,"isVoid":0,"elevation":"high","shape":"flat","unknownKey":"kept"}}}'
	var res := LevelIO.parse(text)
	assert_true(res.get("ok", false), "parse ok")
	var level: LevelData = res["level"]
	var b: Dictionary = level.get_block(1, 1)
	assert_eq(b["isVoid"], true, "isVoid bool")
	assert_eq(b["elevation"], 14.0, "elevation default")
	assert_eq(b["slope"], 0.0, "slope default")
	assert_eq(b["tilt"], 0.0, "tilt default")
	assert_eq(b["shape"], "flat", "shape default")
	assert_eq(b["element"], "none", "element default")
	assert_eq(b["decal"], "none", "decal default")
	var c: Dictionary = level.get_block(2, 2)
	assert_eq(c["isVoid"], false, "isVoid zero")
	assert_eq(c["elevation"], 14.0, "elevation string")
	assert_eq(c["unknownKey"], "kept", "unknown key kept")
	for blk in [b, c]:
		BlockMeshBuilder.build(blk)
		var el := ElementBuilder.build(blk)
		if el != null: el.free()
	var view := LevelView.new()
	view.bind(level)
	view.rebuild_all()
	view.free()


## arcadeFocus survives a JSON round trip; a malformed one is ignored.
func test_arcade_focus_round_trip() -> void:
	var r := LevelIO.parse('{"blocks": {}, "arcadeFocus": [1.5, 2, 3]}')
	var level: LevelData = r["level"]
	assert_true(level.arcade_focus.is_equal_approx(Vector3(1.5, 2, 3)), "parsed")
	var again: LevelData = LevelIO.parse(LevelIO.serialize(level))["level"]
	assert_true(again.arcade_focus.is_equal_approx(Vector3(1.5, 2, 3)), "round trip")
	var bad: LevelData = LevelIO.parse('{"blocks": {}, "arcadeFocus": [1, "x"]}')["level"]
	assert_eq(bad.arcade_focus, Vector3.INF, "malformed ignored")
