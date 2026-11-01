extends TestCase
## Tests for ElementBuilder.

const ALL_ELEMENTS := ["tube_straight", "tube_corner", "tube_u", "cone_small", "cone_large", "goal_flags", "marble_start"]


## Builds an element on a flat block at elevation 2 with the given rotation.
func _build(element: String, elem_rotation: int = 0, extra: Dictionary = {}) -> Node3D:
	var props := {"element": element, "elemRotation": elem_rotation, "elevation": 2.0}
	props.merge(extra, true)
	return ElementBuilder.build(BlockData.make(0, 0, props))


## Collects every MeshInstance3D below a node.
func _meshes(node: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	for child in node.get_children():
		if child is MeshInstance3D: out.append(child)
		out.append_array(_meshes(child))
	return out


## The none element builds an empty node.
func test_none_has_no_children() -> void:
	var node := _build("none")
	assert_eq(node.get_child_count(), 0, "no children")
	node.free()


## Every element id other than none builds something.
func test_each_element_has_children() -> void:
	for id in ALL_ELEMENTS:
		var node := _build(id)
		assert_true(node.get_child_count() > 0, "%s has children" % id)
		assert_true(_meshes(node).size() > 0, "%s has meshes" % id)
		node.free()


## The marble is a sphere of positive radius resting on the surface.
func test_marble_start_is_sphere_radius_positive() -> void:
	var node := _build("marble_start")
	var sphere: SphereMesh = null
	var holder: MeshInstance3D = null
	for m in _meshes(node):
		if m.name == "MarbleSphere":
			holder = m
			sphere = m.mesh as SphereMesh
	assert_true(sphere != null, "sphere found")
	if sphere != null:
		assert_true(sphere.radius > 0.0, "radius positive")
		var center: Vector3 = holder.get_parent().position + holder.position
		assert_near(center.y, 2.0 + sphere.radius, 0.0001, "rests on surface")
		assert_near(center.x, 1.5, 0.0001, "centered x")
		assert_near(center.z, 1.5, 0.0001, "centered z")
	node.free()


## Rotating a tube_corner moves its parts.
func test_elem_rotation_changes_child_positions() -> void:
	var a := _build("tube_corner", 0)
	var b := _build("tube_corner", 90)
	var ma := _meshes(a)
	var mb := _meshes(b)
	assert_eq(ma.size(), mb.size(), "same part count")
	assert_true(not ma[0].position.is_equal_approx(mb[0].position), "first post moved")
	a.free()
	b.free()


## A tube post sits on the surface at the rotated point (0.18, 2.85).
func test_tube_corner_first_post_position() -> void:
	var node := _build("tube_corner", 0)
	var post := _meshes(node)[0]
	assert_near(post.position.x, 0.18, 0.0001, "post x")
	assert_near(post.position.z, 2.85, 0.0001, "post z")
	assert_near(post.position.y, 2.0 + 0.21, 0.0001, "post y")
	node.free()


## A pit block still builds its element.
func test_pit_block_builds_element() -> void:
	var node := _build("cone_small", 0, {"shape": "pit"})
	assert_true(_meshes(node).size() > 0, "pit cone built")
	node.free()
