extends TestCase
## Tests for BlockMeshBuilder (port of buildBlockMeshGroup).

const EPS := 1e-4
## Mesh vertex colors are stored as 8 bit values by Godot.
const COLOR_EPS := 0.004


## Returns the vertex array of the named surface, or an empty array when it is missing.
func _verts(mesh: ArrayMesh, surface_name: String) -> PackedVector3Array:
	var idx := mesh.surface_find_by_name(surface_name)
	if idx < 0: return PackedVector3Array()
	return mesh.surface_get_arrays(idx)[Mesh.ARRAY_VERTEX]


## Returns the array with the given Mesh.ARRAY_* index for the named surface.
func _attr(mesh: ArrayMesh, surface_name: String, array_index: int) -> Variant:
	var idx := mesh.surface_find_by_name(surface_name)
	if idx < 0: return null
	return mesh.surface_get_arrays(idx)[array_index]


## Returns a block with the shape applied through BlockData.apply_shape.
func _shaped(shape_id: String, props: Dictionary = {}) -> Dictionary:
	var block := BlockData.make(0, 0, props)
	BlockData.apply_shape(block, shape_id)
	return block


## Normal that Godot considers the visible side: front faces are clockwise.
func _facing_normal(a: Vector3, b: Vector3, c: Vector3) -> Vector3:
	return -(b - a).cross(c - a).normalized()


## A void block gives no surfaces and no collision faces.
func test_void_block_empty_mesh() -> void:
	var block := BlockData.make(0, 0, {"isVoid": true})
	assert_eq(BlockMeshBuilder.build(block).get_surface_count(), 0, "no surfaces")
	assert_eq(BlockMeshBuilder.build_collision_faces(block).size(), 0, "no collision")


## A flat block has every top vertex at its elevation, inside the local 0..3 range.
func test_flat_block_top_vertices_at_elevation() -> void:
	var mesh := BlockMeshBuilder.build(BlockData.make(0, 0, {"elevation": 14.0}))
	var top := _verts(mesh, BlockMeshBuilder.SURFACE_TOP)
	assert_eq(top.size(), 54, "3x3 tiles, 2 triangles each")
	for p in top:
		assert_near(p.y, 14.0, EPS, "top y")
		assert_true(p.x >= -EPS and p.x <= 3.0 + EPS and p.z >= -EPS and p.z <= 3.0 + EPS, "inside block")


## Top vertices of sloped, rotated and shaped blocks match BlockSurface.surface_y.
func test_top_vertices_match_surface_y() -> void:
	var blocks := [
		BlockData.make(0, 0, {"slope": 1.2, "tilt": 0.5, "rotation": 90, "elevation": 6.0}),
		_shaped("fold_right", {"slope": 2.0, "tilt": 0.5, "rotation": 270}),
		_shaped("fold_left", {"slope": 1.5, "rotation": 180}),
		_shaped("chute_funnel", {"slope": 1.0}),
	]
	for block in blocks:
		var top := _verts(BlockMeshBuilder.build(block), BlockMeshBuilder.SURFACE_TOP)
		assert_true(top.size() > 0, "has top")
		for p in top:
			assert_near(p.y, BlockSurface.surface_y(block, p.x, p.z), EPS, "y at %s,%s" % [p.x, p.z])


## Every shape id builds a mesh with collision, except the pit which is a hole.
func test_every_shape_builds_nonempty() -> void:
	for shape_id in Constants.SHAPE_IDS:
		var block := _shaped(shape_id, {"slope": 1.0})
		var mesh := BlockMeshBuilder.build(block)
		if shape_id == "pit":
			assert_eq(mesh.get_surface_count(), 0, "pit is empty")
			continue
		assert_true(mesh.get_surface_count() > 0, "%s has surfaces" % shape_id)
		assert_true(BlockMeshBuilder.build_collision_faces(block).size() > 0, "%s has collision" % shape_id)


## Collision soup is made of whole triangles for every shape and cutout.
func test_collision_faces_multiple_of_three() -> void:
	for shape_id in Constants.SHAPE_IDS:
		var faces := BlockMeshBuilder.build_collision_faces(_shaped(shape_id, {"slope": 1.0}))
		assert_eq(faces.size() % 3, 0, "%s collision" % shape_id)
	var cut := BlockData.make(0, 0, {"cutout": "wing_right"})
	assert_eq(BlockMeshBuilder.build_collision_faces(cut).size() % 3, 0, "wing_right collision")


## JS buildBlockMeshGroup returns no top (and no walls) for a pit.
func test_pit_has_no_top_at_center() -> void:
	var block := BlockData.make(0, 0, {"shape": "pit"})
	var mesh := BlockMeshBuilder.build(block)
	assert_eq(mesh.surface_find_by_name(BlockMeshBuilder.SURFACE_TOP), -1, "no top surface")
	assert_eq(BlockMeshBuilder.build_collision_faces(block).size(), 0, "no collision")


## Collision faces are exactly the visual vertices, in surface order.
func test_collision_matches_visual_vertices() -> void:
	var block := _shaped("fold_right", {"slope": 1.0, "rotation": 90})
	var mesh := BlockMeshBuilder.build(block)
	var expected := PackedVector3Array()
	for i in mesh.get_surface_count():
		expected.append_array(mesh.surface_get_arrays(i)[Mesh.ARRAY_VERTEX])
	assert_true(BlockMeshBuilder.build_collision_faces(block) == expected, "same vertices")


## Top triangles face up for Godot's clockwise culling, for flat and sloped blocks.
func test_top_faces_point_up() -> void:
	var blocks := [
		BlockData.make(0, 0, {}),
		BlockData.make(0, 0, {"slope": 1.0, "tilt": 0.5}),
		_shaped("fold_left", {"slope": 1.0}),
		_shaped("pit_stepped"),
	]
	for block in blocks:
		var top := _verts(BlockMeshBuilder.build(block), BlockMeshBuilder.SURFACE_TOP)
		for i in range(0, top.size(), 3):
			var n := _facing_normal(top[i], top[i + 1], top[i + 2])
			assert_true(n.y > 0.5, "top triangle %d faces up (%s)" % [i / 3, str(n)])


## Wall triangles face away from the block: +Z wall and +X wall on a flat block.
func test_walls_face_outward() -> void:
	var mesh := BlockMeshBuilder.build(BlockData.make(0, 0, {}))
	var checked := {"z_pos": false, "z_neg": false, "x_pos": false, "x_neg": false}
	for surface_name in [BlockMeshBuilder.SURFACE_WALL, BlockMeshBuilder.SURFACE_WALL_RIGHT]:
		var v := _verts(mesh, surface_name)
		assert_true(v.size() > 0, "%s exists" % surface_name)
		for i in range(0, v.size(), 3):
			var n := _facing_normal(v[i], v[i + 1], v[i + 2])
			var centroid := (v[i] + v[i + 1] + v[i + 2]) / 3.0
			var outward := Vector3(centroid.x - 1.5, 0.0, centroid.z - 1.5)
			assert_true(n.dot(outward) > 0.0, "%s triangle %d faces out" % [surface_name, i / 3])
			if n.z > 0.9: checked["z_pos"] = true
			if n.z < -0.9: checked["z_neg"] = true
			if n.x > 0.9: checked["x_pos"] = true
			if n.x < -0.9: checked["x_neg"] = true
	for key in checked:
		assert_true(checked[key], "found wall facing %s" % key)


## A wall runs from the top edge down to PILLAR_BOTTOM in one piece (no trim band).
func test_wall_extent() -> void:
	var mesh := BlockMeshBuilder.build(BlockData.make(0, 0, {"elevation": 10.0}))
	var wall_min := 1e9
	var wall_max := -1e9
	for p in _verts(mesh, BlockMeshBuilder.SURFACE_WALL):
		wall_min = minf(wall_min, p.y)
		wall_max = maxf(wall_max, p.y)
	assert_near(wall_min, Constants.PILLAR_BOTTOM, EPS, "wall bottom")
	assert_near(wall_max, 10.0, EPS, "wall top")
	assert_eq(mesh.surface_find_by_name("trim"), -1, "no trim surface")


## Top UVs: local (0,0) is the image top-left, (0,3) bottom-left, (3,0) top-right (no mirroring).
func test_top_uv_orientation() -> void:
	var mesh := BlockMeshBuilder.build(BlockData.make(0, 0, {}))
	var verts := _verts(mesh, BlockMeshBuilder.SURFACE_TOP)
	var uvs: PackedVector2Array = _attr(mesh, BlockMeshBuilder.SURFACE_TOP, Mesh.ARRAY_TEX_UV)
	assert_eq(uvs.size(), verts.size(), "one uv per vertex")
	var seen := 0
	for i in verts.size():
		var p := verts[i]
		assert_near(uvs[i].x, p.x / 3.0, EPS, "u")
		assert_near(uvs[i].y, p.z / 3.0, EPS, "v")
		if p.x < EPS and p.z > 3.0 - EPS:
			assert_near(uvs[i].y, 1.0, EPS, "bottom-left corner v")
			seen += 1
	assert_true(seen > 0, "bottom-left corner present")


## Shading: without an explicit shade the sun decides (alpha 0); presets and sub-tiles follow
## the JS values (alpha 1).
func test_vertex_shades() -> void:
	var flat: PackedColorArray = _attr(BlockMeshBuilder.build(BlockData.make(0, 0, {})), BlockMeshBuilder.SURFACE_TOP, Mesh.ARRAY_COLOR)
	for c in flat:
		assert_near(c.a, 0.0, COLOR_EPS, "lit by the sun")
	var leg: PackedColorArray = _attr(BlockMeshBuilder.build(_shaped("chute_leg_x")), BlockMeshBuilder.SURFACE_TOP, Mesh.ARRAY_COLOR)
	for c in leg:
		assert_near(c.r, BlockMeshBuilder.shade_color(Constants.SHADE["WHITE"]).r, COLOR_EPS, "leg shade")
		assert_near(c.a, 1.0, COLOR_EPS, "explicit")
	var explicit := BlockData.make(0, 0, {"subShades": [[0.1, 0.1, 0.1], [0.1, 0.1, 0.1], [0.1, 0.1, 0.1]]})
	var forced: PackedColorArray = _attr(BlockMeshBuilder.build(explicit), BlockMeshBuilder.SURFACE_TOP, Mesh.ARRAY_COLOR)
	for c in forced:
		assert_near(c.r, BlockMeshBuilder.shade_color(0.1).r, COLOR_EPS, "explicit sub shade")


## Wing cutouts drop tiles and walls; the kept half is a triangle fan on the diagonal.
func test_cutouts_reduce_geometry() -> void:
	var full := _verts(BlockMeshBuilder.build(BlockData.make(0, 0, {})), BlockMeshBuilder.SURFACE_TOP).size()
	var wl := _verts(BlockMeshBuilder.build(BlockData.make(0, 0, {"cutout": "wing_left"})), BlockMeshBuilder.SURFACE_TOP)
	var wr := _verts(BlockMeshBuilder.build(BlockData.make(0, 0, {"cutout": "wing_right"})), BlockMeshBuilder.SURFACE_TOP)
	# 3 full tiles (2 tris) + 3 diagonal tiles (1 tri) = 9 triangles.
	assert_eq(wl.size(), 27, "wing_left vertices")
	assert_eq(wr.size(), 27, "wing_right vertices")
	assert_true(wl.size() < full, "fewer than full")
	for p in wl:
		assert_true((p.x / 1.0) + p.z >= 3.0 - EPS, "wing_left keeps u+v >= 3")
	for p in wr:
		assert_true(p.x + p.z <= 3.0 + EPS, "wing_right keeps u+v <= 3")


## Stepped pit drops the (2,2) sub-tile and uses default step heights.
func test_pit_stepped_default_steps() -> void:
	var block := BlockData.make(0, 0, {"shape": "pit_stepped", "elevation": 10.0})
	var top := _verts(BlockMeshBuilder.build(block), BlockMeshBuilder.SURFACE_TOP)
	assert_eq(top.size(), 8 * 6, "8 sub-tiles, 2 triangles each")
	var ys := {}
	for p in top:
		ys[snappedf(p.y, 0.001)] = true
	assert_true(ys.has(10.0) and ys.has(8.8) and ys.has(7.8), "heights 10, 8.8, 7.8")
	assert_eq(ys.size(), 3, "three distinct heights")
	for p in top:
		assert_true(p.x >= -EPS and p.x <= 3.0 + EPS and p.z >= -EPS and p.z <= 3.0 + EPS, "inside block")


## Custom sub-tiles follow subHeights and skip null / missing entries.
func test_subtiles_custom_heights() -> void:
	var block := BlockData.make(0, 0, {
		"shape": "subtiles_custom", "elevation": 5.0,
		"subHeights": [[0.0, null, 1.0], [0.5, 0.5, 0.5], [null, null, 2.0]],
	})
	var top := _verts(BlockMeshBuilder.build(block), BlockMeshBuilder.SURFACE_TOP)
	assert_eq(top.size(), 6 * 6, "6 present sub-tiles")
	var bad := BlockData.make(0, 0, {"shape": "subtiles_custom", "subHeights": "oops"})
	assert_eq(BlockMeshBuilder.build(bad).get_surface_count(), 0, "bad subHeights has no tiles")


## Unknown shape, decal and cutout values do not crash and still build a surface.
func test_unknown_values_do_not_crash() -> void:
	var block := BlockData.make(0, 0, {"shape": "banana", "decal": "nope", "cutout": "weird", "shadePreset": "x"})
	var mesh := BlockMeshBuilder.build(block)
	assert_true(mesh.get_surface_count() > 0, "builds something")
	assert_eq(BlockMeshBuilder.build_collision_faces({}).size() % 3, 0, "empty dict is tolerated")


## A "tiles" block skips holes and adds walls only where neighbor tiles do not join.
func test_tiles_block_walls() -> void:
	var flat := [0.0, 0.0, 0.0, 0.0]
	var joined := BlockData.make(0, 0, {"tiles": [[flat, flat, flat], [flat, flat, flat], [flat, flat, flat]]})
	var stepped := BlockData.make(0, 0, {"tiles": [[flat, flat, flat], [flat, [1.0, 1.0, 1.0, 1.0], flat], [flat, flat, null]]})
	var parts_j := BlockMeshBuilder.build_parts(joined)
	var parts_s := BlockMeshBuilder.build_parts(stepped)
	assert_eq(parts_j[BlockMeshBuilder.SURFACE_TOP].positions.size(), 9 * 6, "nine tiles")
	assert_eq(parts_s[BlockMeshBuilder.SURFACE_TOP].positions.size(), 8 * 6, "hole skipped")
	var walls_j: int = parts_j[BlockMeshBuilder.SURFACE_WALL].positions.size() + parts_j[BlockMeshBuilder.SURFACE_WALL_RIGHT].positions.size()
	var walls_s: int = parts_s[BlockMeshBuilder.SURFACE_WALL].positions.size() + parts_s[BlockMeshBuilder.SURFACE_WALL_RIGHT].positions.size()
	assert_eq(walls_j, 12 * 6, "only the block perimeter has walls")
	assert_true(walls_s > walls_j, "the raised tile and the hole add walls")
