class_name LevelRules
extends RefCounted
## Game rules read from a level: start position, goal cells and fall limit. No nodes, no physics.

const START_ELEMENT := "marble_start"
const GOAL_ELEMENT := "goal_flags"
## Distance below the lowest block where the marble counts as fallen.
const FALL_MARGIN := 8.0
## The marble reaches a goal cell only within this height above its surface.
const GOAL_HEIGHT := 2.0
## Small gap between the marble and the surface at the start.
const START_LIFT := 0.05


## Returns the sorted cells of a non-void block with the given element.
static func cells_with_element(level: LevelData, element: String) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for block: Dictionary in level.blocks.values():
		if block["isVoid"] or block["element"] != element: continue
		cells.append(Vector2i(block["bx"], block["bz"]))
	cells.sort()
	return cells


## Returns the marble center at the start of the level, or Vector3.INF when it has no start.
static func start_position(level: LevelData, marble_radius: float) -> Vector3:
	var cells := cells_with_element(level, START_ELEMENT)
	if cells.is_empty(): return Vector3.INF
	var block := level.get_block(cells[0].x, cells[0].y)
	var at := element_point(block)
	var y := BlockSurface.surface_y(block, at.x, at.y)
	return LevelView.grid_to_world(cells[0].x, cells[0].y) + Vector3(at.x, y + marble_radius + START_LIFT, at.y)


## Returns the block local point of the element of a block: "elemOffset" [u, v] or the center.
static func element_point(block: Dictionary) -> Vector2:
	var offset: Variant = block.get("elemOffset")
	if offset is Array and offset.size() == 2: return Vector2(BlockSurface._num(offset[0]), BlockSurface._num(offset[1]))
	var half := Constants.BLOCK_SIZE / 2.0
	return Vector2(half, half)


## Returns the height below which the marble has fallen off the level.
static func fall_limit(level: LevelData) -> float:
	var lowest := 0.0
	for block: Dictionary in level.blocks.values():
		if not block["isVoid"]: lowest = minf(lowest, block["elevation"])
	return lowest - FALL_MARGIN


## Returns true when a marble center is on a goal cell, close to its surface.
static func is_on_goal(level: LevelData, pos: Vector3) -> bool:
	var size := Constants.BLOCK_SIZE
	var bx := int(floorf(pos.x / size))
	var bz := int(floorf(pos.z / size))
	var block := level.get_block(bx, bz)
	if block.is_empty() or block["isVoid"] or block["element"] != GOAL_ELEMENT: return false
	var y := BlockSurface.surface_y(block, pos.x - bx * size, pos.z - bz * size)
	return pos.y - y <= GOAL_HEIGHT
