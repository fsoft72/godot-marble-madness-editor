class_name ErrorCapture
extends Logger
## Logger that records engine and script errors so the runner can fail a test
## whose method aborted with a runtime error (which does not raise in GDScript).

## Messages captured since the last clear().
var messages: Array[String] = []
var _mutex := Mutex.new()


## Records an error or script error (called by the engine, possibly from any thread).
func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool, _error_type: int, _script_backtraces: Array) -> void:
	_mutex.lock()
	messages.append("%s (%s:%d in %s)" % [rationale if rationale != "" else code, file, line, function])
	_mutex.unlock()


## Returns a copy of the captured messages and clears the buffer.
func take() -> Array[String]:
	_mutex.lock()
	var result := messages.duplicate()
	messages.clear()
	_mutex.unlock()
	return result
