class_name History
extends RefCounted
## Undo/redo stacks of full-level snapshots (mirrors saveUndoSnapshot/undo/redo in js/main.js).

## Maximum number of undo steps kept.
const MAX_STEPS := 100

var _undo_stack: Array[String] = []
var _redo_stack: Array[String] = []


## Saves the current level state to the undo stack and clears the redo stack.
func push(level: LevelData) -> void:
	_undo_stack.append(level.snapshot())
	if _undo_stack.size() > MAX_STEPS: _undo_stack.pop_front()
	_redo_stack.clear()


## Restores the previous state. Returns false and leaves the level untouched if there is none.
func undo(level: LevelData) -> bool:
	if _undo_stack.is_empty(): return false
	_redo_stack.append(level.snapshot())
	level.restore(_undo_stack.pop_back())
	return true


## Reapplies the last undone state. Returns false and leaves the level untouched if there is none.
func redo(level: LevelData) -> bool:
	if _redo_stack.is_empty(): return false
	_undo_stack.append(level.snapshot())
	level.restore(_redo_stack.pop_back())
	return true


## Returns true when there is a state to undo to.
func can_undo() -> bool:
	return not _undo_stack.is_empty()


## Returns true when there is an undone state to redo.
func can_redo() -> bool:
	return not _redo_stack.is_empty()
