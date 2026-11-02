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
	assert_near(post.position.y, 2.0 + ElementBuilder.POST_HEIGHT / 2.0, 0.0001, "post y")
	node.free()


## A pit block still builds its element.
func test_pit_block_builds_element() -> void:
	var node := _build("cone_small", 0, {"shape": "pit"})
	assert_true(_meshes(node).size() > 0, "pit cone built")
	node.free()


## Returns the glass tint of the marble sphere built with the given marbleColor.
func _marble_color(value: Variant) -> Color:
	var node := _build("marble_start", 0, {"marbleColor": value})
	var color := Color.BLACK
	for m in _meshes(node):
		if m.name == "MarbleSphere": color = (m.material_override as ShaderMaterial).get_shader_parameter("tint")
	node.free()
	return color


## A '#rrggbb' string tints the marble glass.
func test_marble_color_html_string() -> void:
	var c := _marble_color("#1020ff")
	assert_near(c.r, 0x10 / 255.0, 0.001, "r")
	assert_near(c.g, 0x20 / 255.0, 0.001, "g")
	assert_near(c.b, 1.0, 0.001, "b")


## The marble uses the ray traced glass shader with the marble radius.
func test_marble_uses_ray_traced_glass() -> void:
	var node := _build("marble_start")
	for m in _meshes(node):
		if m.name != "MarbleSphere": continue
		var mat := m.material_override as ShaderMaterial
		assert_true(mat != null and mat.shader.resource_path == ElementBuilder.GLASS_SHADER_PATH, "glass shader")
		assert_near(mat.get_shader_parameter("radius"), ElementBuilder.MARBLE_RADIUS, 0.0001, "radius")
	node.free()


## An int colors the marble.
func test_marble_color_int() -> void:
	var c := _marble_color(0x00ff00)
	assert_near(c.g, 1.0, 0.001, "g")
	assert_near(c.r, 0.0, 0.001, "r")


## An invalid string falls back to the default red.
func test_marble_color_invalid_falls_back() -> void:
	var c := _marble_color("not a color")
	assert_near(c.r, 0xe6 / 255.0, 0.001, "default r")
	assert_near(c.g, 0x19 / 255.0, 0.001, "default g")


## The cone is flat shaded like the JS (flatShading: true): all vertices of a triangle share its face normal.
func test_cone_is_flat_shaded() -> void:
	var node := _build("cone_small")
	var cone: MeshInstance3D = null
	for m in _meshes(node):
		if m.name == ElementBuilder.CONE_NAME: cone = m
	assert_true(cone != null, "cone mesh found")
	if cone != null:
		var arrays := cone.mesh.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var count := indices.size() if indices.size() > 0 else verts.size()
		assert_true(count >= 12, "at least four side triangles, got %d vertices" % count)
		for t in range(0, count, 3):
			var i0 := indices[t] if indices.size() > 0 else t
			var i1 := indices[t + 1] if indices.size() > 0 else t + 1
			var i2 := indices[t + 2] if indices.size() > 0 else t + 2
			var raw_normal := (verts[i1] - verts[i0]).cross(verts[i2] - verts[i0])
			if raw_normal.length_squared() < 1e-12: continue
			var face := raw_normal.normalized()
			for i in [i0, i1, i2]:
				# Normals are stored compressed by the engine, so compare by direction.
				assert_true(absf(normals[i].dot(face)) > 0.999, "normal %d of triangle %d is the face normal" % [i, t / 3])
	node.free()


## tube_path builds bars, joints and posts through the given axis points.
func test_tube_path() -> void:
	var node := _build("tube_path", 0, {"tubePoints": [[0, 3, 0], [2, 3, 0], [2, 3, 2]], "tubePosts": [0]})
	var bars := 0
	var posts := 0
	for m in _meshes(node):
		if m.mesh is CylinderMesh and is_equal_approx((m.mesh as CylinderMesh).height, ElementBuilder.POST_HEIGHT): posts += 1
		elif m.mesh is CylinderMesh: bars += 1
	assert_eq(bars, 2, "two bars")
	assert_eq(posts, 1, "one post")
	assert_true(ElementBuilder.collision_faces(node, {"element": "tube_path"}).size() > 0, "solid")
	node.free()
