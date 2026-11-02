class_name LevelData
extends RefCounted
## A square grid of blocks. Blocks are raw dictionaries keyed by "bx,bz".

## Format version written to JSON.
const FORMAT_VERSION := 1
## Block fields that must be integers (JSON numbers parse as floats).
const INT_FIELDS: Array[String] = ["bx", "bz", "rotation", "elemRotation", "decalRotation"]

## Tiles per side along X.
var cols: int = Constants.DEFAULT_GRID
## Tiles per side along Z.
var rows: int = Constants.DEFAULT_GRID
## Blocks keyed by "bx,bz".
var blocks: Dictionary = {}
## World point shown at the center of the arcade view (JSON "arcadeFocus" [x, y, z]);
## Vector3.INF when the level does not set one.
var arcade_focus := Vector3.INF


## Returns the dictionary key for a cell.
static func key(bx: int, bz: int) -> String:
	return "%d,%d" % [bx, bz]


## Returns the block at the cell, or an empty dictionary if absent.
func get_block(bx: int, bz: int) -> Dictionary:
	return blocks.get(key(bx, bz), {})


## Stores a block at the cell.
func set_block(bx: int, bz: int, block: Dictionary) -> void:
	blocks[key(bx, bz)] = block


## Removes the block at the cell, if any.
func remove_block(bx: int, bz: int) -> void:
	blocks.erase(key(bx, bz))


## Returns true when the cell lies inside the grid.
func in_bounds(bx: int, bz: int) -> bool:
	return bx >= 0 and bz >= 0 and bx < cols and bz < rows


## Removes all blocks and the arcade focus, keeps the grid size.
func clear() -> void:
	blocks.clear()
	arcade_focus = Vector3.INF


## Returns the whole level state (size and blocks) as a JSON string.
func snapshot() -> String:
	return JSON.stringify(to_dict())


## Restores a snapshot in place. Returns without changes if the snapshot is invalid.
func restore(snap: String) -> void:
	var json := JSON.new()
	if json.parse(snap) != OK or typeof(json.data) != TYPE_DICTIONARY: return
	var parsed := LevelData.from_dict(json.data)
	if parsed == null: return
	copy_from(parsed)


## Replaces this level's contents with a copy of another level's contents.
func copy_from(other: LevelData) -> void:
	cols = other.cols
	rows = other.rows
	blocks = other.blocks.duplicate(true)
	arcade_focus = other.arcade_focus


## Returns a plain dictionary ready for JSON serialization.
func to_dict() -> Dictionary:
	var d := {"version": FORMAT_VERSION, "cols": cols, "rows": rows, "blocks": blocks.duplicate(true)}
	if arcade_focus != Vector3.INF: d["arcadeFocus"] = [arcade_focus.x, arcade_focus.y, arcade_focus.z]
	return d


## Builds a level from a dictionary. Returns null if "blocks" is not a Dictionary.
## Tolerant: missing fields get defaults, unknown keys are kept, malformed blocks are skipped.
static func from_dict(d: Dictionary) -> LevelData:
	var raw_blocks: Variant = d.get("blocks", {})
	if typeof(raw_blocks) != TYPE_DICTIONARY: return null
	var level := LevelData.new()
	level.cols = _read_size(d.get("cols"))
	level.rows = _read_size(d.get("rows"))
	level.arcade_focus = _read_focus(d.get("arcadeFocus"))
	for k in raw_blocks:
		var block := _normalize_block(str(k), raw_blocks[k])
		if block.is_empty(): continue
		level.blocks[key(block["bx"], block["bz"])] = block
	return level


## Reads an [x, y, z] number array, Vector3.INF when missing or malformed.
static func _read_focus(v: Variant) -> Vector3:
	if not v is Array or v.size() != 3: return Vector3.INF
	for n in v:
		if not (n is float or n is int): return Vector3.INF
	return Vector3(v[0], v[1], v[2])


## Reads a grid size value, falling back to the default when missing or invalid.
static func _read_size(v: Variant) -> int:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT: return Constants.DEFAULT_GRID
	if v < 1: return Constants.DEFAULT_GRID
	return int(v)


## Returns a normalized copy of a raw block, or an empty dictionary if it must be skipped.
static func _normalize_block(k: String, raw: Variant) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY: return {}
	var from_key := _parse_key(k)
	var bx: Variant = _as_int(raw.get("bx"), from_key.get("bx"))
	var bz: Variant = _as_int(raw.get("bz"), from_key.get("bz"))
	if bx == null or bz == null: return {}
	var block := BlockData.defaults()
	block.merge(raw.duplicate(true), true)
	block["bx"] = bx
	block["bz"] = bz
	for f in INT_FIELDS:
		var n: Variant = _as_int(block[f], 0)
		block[f] = n
	_coerce_known_types(block)
	return block


## Forces known fields to their expected types, using the defaults for wrong-typed values.
static func _coerce_known_types(block: Dictionary) -> void:
	var defaults := BlockData.defaults()
	var v: Variant = block["isVoid"]
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT: block["isVoid"] = v != 0
	elif typeof(v) != TYPE_BOOL: block["isVoid"] = defaults["isVoid"]
	for f in ["elevation", "slope", "tilt"]:
		var n: Variant = block[f]
		block[f] = float(n) if typeof(n) == TYPE_INT or typeof(n) == TYPE_FLOAT else defaults[f]
	for f in ["shape", "element", "decal"]:
		if typeof(block[f]) != TYPE_STRING: block[f] = defaults[f]


## Parses "bx,bz" into {"bx", "bz"}; returns an empty dictionary if invalid.
static func _parse_key(k: String) -> Dictionary:
	var parts := k.split(",")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return {}
	return {"bx": int(parts[0]), "bz": int(parts[1])}


## Converts a number to int; returns fallback when v is not a number.
static func _as_int(v: Variant, fallback: Variant) -> Variant:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT: return int(v)
	return fallback
