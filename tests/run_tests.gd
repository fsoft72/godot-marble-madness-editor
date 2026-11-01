extends SceneTree
## Test runner. Usage:
##   godot --headless --path . -s res://tests/run_tests.gd
## After adding or renaming any global class_name script, refresh the class cache first:
##   godot --headless --path . --import
## Loads every tests/test_*.gd, runs each test_* method on a fresh instance
## (methods may use await), prints PASS/FAIL per method and exits non-zero on
## any failure, on a test script that fails to load, or when no tests are found.

const TESTS_DIR := "res://tests"
const TEST_PREFIX := "test_"
const TEST_METHOD_PREFIX := "test_"

var _passed := 0
var _failed := 0


## Entry point: starts the (possibly async) run.
func _initialize() -> void:
	_run_all()


## Runs every test script, then quits with the proper exit code.
func _run_all() -> void:
	var files := _find_test_files()
	if files.is_empty():
		print("FAIL: no test files found in %s" % TESTS_DIR)
		quit(1)
		return
	for path in files:
		await _run_file(path)
	print("\nResult: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


## Returns sorted paths of tests/test_*.gd files, excluding the base class.
func _find_test_files() -> Array[String]:
	var result: Array[String] = []
	var dir := DirAccess.open(TESTS_DIR)
	if dir == null: return result
	for f in dir.get_files():
		if f.begins_with(TEST_PREFIX) and f.ends_with(".gd") and f != "test_case.gd":
			result.append("%s/%s" % [TESTS_DIR, f])
	result.sort()
	return result


## Runs all test_* methods of one script; a load failure counts as a failure.
func _run_file(path: String) -> void:
	var script := load(path) as GDScript
	if script == null or not script.can_instantiate():
		_failed += 1
		print("FAIL %s: script failed to load or parse" % path)
		return
	var methods: Array[String] = []
	for m in script.get_script_method_list():
		if String(m["name"]).begins_with(TEST_METHOD_PREFIX):
			methods.append(m["name"])
	methods.sort()
	for method in methods:
		await _run_method(script, path, method)


## Runs one test method on a fresh instance and records the result.
func _run_method(script: GDScript, path: String, method: String) -> void:
	var inst = script.new()
	if not inst is TestCase:
		_failed += 1
		print("FAIL %s: does not extend TestCase" % path)
		return
	inst.tree = self
	await inst.call(method)
	if inst.failures.is_empty():
		_passed += 1
		print("PASS %s::%s" % [path, method])
		return
	_failed += 1
	print("FAIL %s::%s" % [path, method])
	for msg in inst.failures:
		print("    %s" % msg)
