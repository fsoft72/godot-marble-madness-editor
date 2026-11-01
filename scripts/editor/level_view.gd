class_name LevelView
extends Node3D
## Renders a LevelData as one node per block and answers physics-free picking queries.
## Block origin is the grid corner: world position = (bx * BLOCK_SIZE, 0, bz * BLOCK_SIZE).

const NODE_PREFIX := "Block_"
const BODY_NAME := "Body"
const ELEMENT_NAME := "Element"
const MESH_NAME := "Mesh"
## Rays with a vertical component below this are treated as parallel to the ground.
const PARALLEL_EPS := 0.000001
const NO_CELL := Vector2i(-1, -1)

## The level being displayed.
var level: LevelData
## Cached collision faces per block key, local to the block.
var _faces: Dictionary = {}
## Cached local bounding box per block key.
var _bounds: Dictionary = {}


## Binds a level and rebuilds every block node.
func bind(new_level: LevelData) -> void:
	level = new_level
	rebuild_all()


## Rebuilds all block nodes and removes nodes of cells no longer in the level.
func rebuild_all() -> void:
	if level == null: return
	for child in get_children():
		var parsed := _parse_name(child.name)
		if parsed != NO_CELL and level.blocks.has(LevelData.key(parsed.x, parsed.y)): continue
		_drop_node(child)
	_faces.clear()
	_bounds.clear()
	for k in level.blocks:
		var block: Dictionary = level.blocks[k]
		rebuild_block(int(block["bx"]), int(block["bz"]))


## Creates, replaces or removes the node of one block, leaving all others untouched.
func rebuild_block(bx: int, bz: int) -> void:
	var k := LevelData.key(bx, bz)
	_forget(bx, bz)
	if level == null: return
	var block := level.get_block(bx, bz)
	if block.is_empty() or block.get("isVoid", false) == true: return
	var faces := BlockMeshBuilder.build_collision_faces(block)
	var element := ElementBuilder.build(block)
	if faces.is_empty() and element.get_child_count() == 0:
		element.free()
		return
	var node := Node3D.new()
	node.name = _node_name(bx, bz)
	node.position = grid_to_world(bx, bz)
	if not faces.is_empty():
		_add_geometry(node, block, faces)
		_faces[k] = faces
		_bounds[k] = _faces_bounds(faces)
	element.name = ELEMENT_NAME
	node.add_child(element)
	add_child(node)


## Returns the node of the block, or null when the cell has none.
func block_node(bx: int, bz: int) -> Node3D:
	return get_node_or_null(NodePath(_node_name(bx, bz))) as Node3D


## Returns the world position of the block origin (grid corner).
static func grid_to_world(bx: int, bz: int) -> Vector3:
	return Vector3(bx * Constants.BLOCK_SIZE, 0.0, bz * Constants.BLOCK_SIZE)


## Returns the cell whose geometry is hit first by the ray, or (-1, -1). Needs no physics or tree.
func pick_cell(ray_origin: Vector3, ray_dir: Vector3) -> Vector2i:
	var best := NO_CELL
	var best_dist := INF
	for k in _faces:
		var cell := _parse_key(k)
		var offset := grid_to_world(cell.x, cell.y)
		var local_origin := ray_origin - offset
		if not _bounds[k].intersects_segment(local_origin, local_origin + ray_dir * 1.0e6): continue
		var dist := _nearest_hit(_faces[k], local_origin, ray_dir)
		if dist >= best_dist: continue
		best_dist = dist
		best = cell
	return best


## Returns the grid cell under the ray on the plane at the default elevation, or (-1, -1).
func cell_from_ground_ray(ray_origin: Vector3, ray_dir: Vector3) -> Vector2i:
	if level == null: return NO_CELL
	if absf(ray_dir.y) < PARALLEL_EPS: return NO_CELL
	var plane_y: float = BlockData.defaults()["elevation"]
	var t := (plane_y - ray_origin.y) / ray_dir.y
	if t < 0.0: return NO_CELL
	var hit := ray_origin + ray_dir * t
	var bx := int(floorf(hit.x / Constants.BLOCK_SIZE))
	var bz := int(floorf(hit.z / Constants.BLOCK_SIZE))
	if not level.in_bounds(bx, bz): return NO_CELL
	return Vector2i(bx, bz)


## Adds the visual mesh and the static body with a concave shape to a block node.
func _add_geometry(node: Node3D, block: Dictionary, faces: PackedVector3Array) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = MESH_NAME
	mesh_instance.mesh = BlockMeshBuilder.build(block)
	node.add_child(mesh_instance)
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	var body := StaticBody3D.new()
	body.name = BODY_NAME
	body.add_child(collision)
	node.add_child(body)


## Removes and frees the node and cached data of a block immediately.
func _forget(bx: int, bz: int) -> void:
	var k := LevelData.key(bx, bz)
	_faces.erase(k)
	_bounds.erase(k)
	var node := block_node(bx, bz)
	if node != null: _drop_node(node)


## Detaches a node from the view and frees it right away so its name is released.
func _drop_node(node: Node) -> void:
	remove_child(node)
	node.free()


## Returns the closest hit distance of a ray against a triangle soup, or INF.
func _nearest_hit(faces: PackedVector3Array, origin: Vector3, dir: Vector3) -> float:
	var best := INF
	for i in range(0, faces.size() - 2, 3):
		var hit: Variant = Geometry3D.ray_intersects_triangle(origin, dir, faces[i], faces[i + 1], faces[i + 2])
		if hit == null: continue
		best = minf(best, origin.distance_to(hit))
	return best


## Returns the bounding box of a triangle soup.
func _faces_bounds(faces: PackedVector3Array) -> AABB:
	var box := AABB(faces[0], Vector3.ZERO)
	for p in faces: box = box.expand(p)
	return box.grow(0.001)


## Returns the node name of a block.
func _node_name(bx: int, bz: int) -> StringName:
	return StringName("%s%d_%d" % [NODE_PREFIX, bx, bz])


## Parses a node name "Block_bx_bz" into a cell, or (-1, -1) if it is not one.
func _parse_name(node_name: StringName) -> Vector2i:
	var s := String(node_name)
	if not s.begins_with(NODE_PREFIX): return NO_CELL
	var parts := s.trim_prefix(NODE_PREFIX).split("_")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int(): return NO_CELL
	return Vector2i(int(parts[0]), int(parts[1]))


## Parses a "bx,bz" level key into a cell.
func _parse_key(k: String) -> Vector2i:
	var parts := k.split(",")
	return Vector2i(int(parts[0]), int(parts[1]))
