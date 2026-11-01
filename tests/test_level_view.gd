extends TestCase
## Tests for LevelView (per-block nodes, collision, picking).


## Builds a level with the given blocks and a bound view (not in the tree).
func _view_with(blocks: Array) -> LevelView:
	var level := LevelData.new()
	for b in blocks:
		level.set_block(b["bx"], b["bz"], b)
	var view := LevelView.new()
	view.bind(level)
	return view


## Returns the world center of a cell at the given height.
func _center(bx: int, bz: int, y: float) -> Vector3:
	return LevelView.grid_to_world(bx, bz) + Vector3(Constants.BLOCK_SIZE / 2.0, y, Constants.BLOCK_SIZE / 2.0)


## Counts the children of a node of the given class.
func _count_of(node: Node, cls: String) -> int:
	var n := 0
	for c in node.get_children():
		if c.is_class(cls): n += 1
	return n


## grid_to_world places the block origin at the grid corner.
func test_grid_to_world() -> void:
	assert_eq(LevelView.grid_to_world(2, 3), Vector3(6.0, 0.0, 9.0), "origin")


## rebuild_block creates a named node with mesh, element node and static body.
func test_rebuild_block_creates_node() -> void:
	var view := _view_with([BlockData.make(1, 2, {"elevation": 2.0})])
	view.rebuild_block(1, 2)
	var node := view.block_node(1, 2)
	assert_true(node != null, "node exists")
	if node == null:
		view.free()
		return
	assert_eq(node.name, &"Block_1_2", "node name")
	assert_eq(node.position, LevelView.grid_to_world(1, 2), "node position")
	assert_eq(_count_of(node, "MeshInstance3D"), 1, "one mesh")
	assert_eq(_count_of(node, "StaticBody3D"), 1, "one body")
	var body := node.get_node("Body") as StaticBody3D
	var shape := (body.get_child(0) as CollisionShape3D).shape
	assert_true(shape is ConcavePolygonShape3D, "concave shape")
	view.free()


## Void and absent cells have no node and no collider.
func test_void_block_has_no_node_or_collider() -> void:
	var view := _view_with([BlockData.make(0, 0, {"isVoid": true})])
	view.rebuild_all()
	assert_true(view.block_node(0, 0) == null, "void has no node")
	assert_true(view.block_node(5, 5) == null, "absent has no node")
	assert_eq(view.get_child_count(), 0, "no children at all")
	view.free()


## A pit has no geometry, but an element on it still appears (no collider).
func test_pit_with_element_has_node_without_collider() -> void:
	var view := _view_with([
		BlockData.make(0, 0, {"shape": "pit", "element": "cone_small"}),
		BlockData.make(1, 0, {"shape": "pit"}),
	])
	view.rebuild_all()
	var node := view.block_node(0, 0)
	assert_true(node != null, "pit with element has node")
	if node != null:
		assert_eq(_count_of(node, "StaticBody3D"), 0, "no body")
		assert_eq(_count_of(node, "MeshInstance3D"), 0, "no block mesh")
	assert_true(view.block_node(1, 0) == null, "bare pit has no node")
	assert_eq(view.pick_cell(_center(0, 0, 50.0), Vector3.DOWN), Vector2i(-1, -1), "pit not pickable")
	view.free()


## Removing a block from the data and rebuilding frees its node.
func test_remove_block_frees_node() -> void:
	var view := _view_with([BlockData.make(0, 0)])
	view.rebuild_block(0, 0)
	assert_true(view.block_node(0, 0) != null, "created")
	view.level.remove_block(0, 0)
	view.rebuild_block(0, 0)
	assert_true(view.block_node(0, 0) == null, "removed")
	assert_eq(view.get_child_count(), 0, "no children")
	view.free()


## Rebuilding one block replaces only its own node.
func test_rebuild_block_touches_only_that_block() -> void:
	var view := _view_with([BlockData.make(0, 0), BlockData.make(1, 0)])
	view.rebuild_all()
	var other_id := view.block_node(1, 0).get_instance_id()
	var old_id := view.block_node(0, 0).get_instance_id()
	view.rebuild_block(0, 0)
	assert_eq(view.block_node(1, 0).get_instance_id(), other_id, "other unchanged")
	assert_true(view.block_node(0, 0).get_instance_id() != old_id, "target replaced")
	assert_eq(view.block_node(0, 0).name, &"Block_0_0", "name kept")
	assert_eq(view.get_child_count(), 2, "two children")
	view.free()


## rebuild_all drops nodes of cells no longer in the level.
func test_rebuild_all_removes_stale_nodes() -> void:
	var view := _view_with([BlockData.make(0, 0), BlockData.make(1, 0)])
	view.rebuild_all()
	view.level.remove_block(1, 0)
	view.rebuild_all()
	assert_true(view.block_node(1, 0) == null, "stale removed")
	assert_true(view.block_node(0, 0) != null, "kept")
	assert_eq(view.get_child_count(), 1, "one child")
	view.free()


## A ray from above hits the block below it.
func test_pick_cell_hits_block_from_above() -> void:
	var view := _view_with([BlockData.make(2, 3, {"elevation": 2.0}), BlockData.make(0, 0, {"elevation": 2.0})])
	view.rebuild_all()
	assert_eq(view.pick_cell(_center(2, 3, 30.0), Vector3.DOWN), Vector2i(2, 3), "hit 2,3")
	assert_eq(view.pick_cell(_center(0, 0, 30.0), Vector3.DOWN), Vector2i(0, 0), "hit 0,0")
	view.free()


## The nearest hit wins: a high block in front of a low one along the ray.
func test_pick_cell_nearest_wins() -> void:
	var view := _view_with([BlockData.make(0, 0, {"elevation": 2.0}), BlockData.make(1, 0, {"elevation": 8.0})])
	view.rebuild_all()
	var origin := Vector3(20.0, 5.0, 1.5)
	assert_eq(view.pick_cell(origin, Vector3.LEFT), Vector2i(1, 0), "wall of higher block first")
	view.free()


## Rays over void or empty cells miss.
func test_pick_cell_misses_void() -> void:
	var view := _view_with([BlockData.make(0, 0, {"isVoid": true}), BlockData.make(1, 0)])
	view.rebuild_all()
	assert_eq(view.pick_cell(_center(0, 0, 30.0), Vector3.DOWN), Vector2i(-1, -1), "void")
	assert_eq(view.pick_cell(_center(7, 7, 30.0), Vector3.DOWN), Vector2i(-1, -1), "empty")
	view.free()


## A ray pointing up from above everything misses.
func test_pick_cell_ray_away_misses() -> void:
	var view := _view_with([BlockData.make(0, 0)])
	view.rebuild_all()
	assert_eq(view.pick_cell(_center(0, 0, 30.0), Vector3.UP), Vector2i(-1, -1), "away")
	view.free()


## The ground ray maps the plane hit to a cell, also for empty cells.
func test_ground_ray_hits_cell() -> void:
	var view := _view_with([])
	var y: float = BlockData.defaults()["elevation"]
	assert_eq(view.cell_from_ground_ray(_center(4, 5, y + 10.0), Vector3.DOWN), Vector2i(4, 5), "cell 4,5")
	view.free()


## Ground rays outside the grid, parallel or pointing away return -1,-1.
func test_ground_ray_outside_grid_returns_minus_one() -> void:
	var view := _view_with([])
	var y: float = BlockData.defaults()["elevation"]
	assert_eq(view.cell_from_ground_ray(_center(20, 0, y + 10.0), Vector3.DOWN), Vector2i(-1, -1), "outside x")
	assert_eq(view.cell_from_ground_ray(Vector3(-1.0, y + 10.0, 1.0), Vector3.DOWN), Vector2i(-1, -1), "negative x")
	assert_eq(view.cell_from_ground_ray(_center(1, 1, y + 10.0), Vector3.RIGHT), Vector2i(-1, -1), "parallel")
	assert_eq(view.cell_from_ground_ray(_center(1, 1, y + 10.0), Vector3.UP), Vector2i(-1, -1), "away")
	view.free()
