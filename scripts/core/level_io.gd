class_name LevelIO
extends RefCounted
## Tolerant JSON reading and writing of levels. Problems are reported in the
## return value, never logged.


## Parses level JSON. Returns {"ok": bool, "level": LevelData, "error": String}.
static func parse(text: String) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail("Invalid JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
	if typeof(json.data) != TYPE_DICTIONARY: return _fail("Top level value must be an object")
	if not json.data.has("blocks"): return _fail("Missing 'blocks'")
	var level := LevelData.from_dict(json.data)
	if level == null: return _fail("'blocks' must be an object")
	return {"ok": true, "level": level, "error": ""}


## Serializes a level to JSON text.
static func serialize(level: LevelData) -> String:
	return JSON.stringify(level.to_dict(), "\t") + "\n"


## Reads and parses a level file. Same result shape as parse().
static func load_file(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return _fail("File not found: %s" % path)
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return _fail("Cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
	return parse(f.get_as_text())


## Writes a level to a file. Returns OK or the open error.
static func save_file(path: String, level: LevelData) -> Error:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null: return FileAccess.get_open_error()
	f.store_string(serialize(level))
	return OK


## Builds a failure result.
static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "level": null, "error": msg}
