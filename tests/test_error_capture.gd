extends TestCase
## Tests for the runtime error capture used by the runner.


## A logged error is recorded and take() clears the buffer.
func test_capture_records_and_clears() -> void:
	var cap := ErrorCapture.new()
	cap._log_error("f", "file.gd", 3, "code", "boom", false, 1, [])
	var msgs := cap.take()
	assert_eq(msgs.size(), 1, "one message")
	assert_true("boom" in msgs[0], "contains rationale")
	assert_eq(cap.take().size(), 0, "cleared")
