class_name TestCase
extends RefCounted
## Base class for all tests. The runner creates a fresh instance per test method.

## Failure messages recorded by the assert helpers.
var failures: Array[String] = []
## Scene tree set by the runner, for tests that need nodes in the tree.
var tree: SceneTree


## Records a failure when cond is false.
func assert_true(cond: bool, msg: String = "") -> void:
	if cond: return
	failures.append("assert_true failed: %s" % msg)


## Records a failure when actual != expected.
func assert_eq(actual: Variant, expected: Variant, msg: String = "") -> void:
	if typeof(actual) == typeof(expected) and actual == expected: return
	failures.append("assert_eq failed: %s (actual=%s, expected=%s)" % [msg, str(actual), str(expected)])


## Records a failure when |a - b| > eps.
func assert_near(a: float, b: float, eps: float = 0.0001, msg: String = "") -> void:
	if absf(a - b) <= eps: return
	failures.append("assert_near failed: %s (a=%s, b=%s, eps=%s)" % [msg, str(a), str(b), str(eps)])
