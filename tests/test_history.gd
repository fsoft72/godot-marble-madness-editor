extends TestCase
## Tests for History (undo/redo).


## Builds a level with a single block at (0, 0) with the given elevation.
func _level_with(elevation: float) -> LevelData:
	var level := LevelData.new()
	level.set_block(0, 0, BlockData.make(0, 0, {"elevation": elevation}))
	return level


## Undo brings back the state saved by push.
func test_undo_restores_previous() -> void:
	var level := _level_with(1.0)
	var h := History.new()
	h.push(level)
	level.set_block(0, 0, BlockData.make(0, 0, {"elevation": 2.0}))
	assert_true(h.undo(level), "undo returns true")
	assert_eq(level.get_block(0, 0)["elevation"], 1.0, "elevation restored")
	assert_true(not h.can_undo(), "undo stack empty")


## Redo reapplies the state undone.
func test_redo_after_undo() -> void:
	var level := _level_with(1.0)
	var h := History.new()
	h.push(level)
	level.set_block(0, 0, BlockData.make(0, 0, {"elevation": 2.0}))
	h.undo(level)
	assert_true(h.can_redo(), "can redo")
	assert_true(h.redo(level), "redo returns true")
	assert_eq(level.get_block(0, 0)["elevation"], 2.0, "elevation redone")
	assert_true(not h.can_redo(), "redo stack empty")


## A new push clears the redo stack.
func test_new_push_clears_redo() -> void:
	var level := _level_with(1.0)
	var h := History.new()
	h.push(level)
	level.set_block(0, 0, BlockData.make(0, 0, {"elevation": 2.0}))
	h.undo(level)
	h.push(level)
	assert_true(not h.can_redo(), "redo cleared")


## Undo and redo on empty stacks return false and leave the level alone.
func test_undo_empty_is_noop() -> void:
	var level := _level_with(1.0)
	var before := level.snapshot()
	var h := History.new()
	assert_true(not h.undo(level), "undo false")
	assert_true(not h.redo(level), "redo false")
	assert_eq(level.snapshot(), before, "level unchanged")


## Only the newest MAX_STEPS snapshots are kept.
func test_max_steps_drops_oldest() -> void:
	var level := _level_with(0.0)
	var h := History.new()
	for i in range(History.MAX_STEPS + 5):
		level.set_block(0, 0, BlockData.make(0, 0, {"elevation": float(i)}))
		h.push(level)
	var count := 0
	while h.undo(level):
		count += 1
	assert_eq(count, History.MAX_STEPS, "steps kept")
	assert_eq(level.get_block(0, 0)["elevation"], 5.0, "oldest kept is index 5")
