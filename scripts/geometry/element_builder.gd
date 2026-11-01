class_name ElementBuilder
extends RefCounted
## Builds the visual element placed on a block (port of buildElementOnBlock and
## createGuardTubeSegment from js/geometry.js). Visual only, no collision.
## Output coordinates are block local: x = u, z = v, y is world height.

const POST_HEIGHT := 0.42
const TUBE_RADIUS := 0.13
const MARBLE_RADIUS := 0.52
const DEFAULT_MARBLE_COLOR := 0xe61922
const POLE_HEIGHT := 1.95
const FLAG_WIDTH := 0.92
const FLAG_HEIGHT := 0.65
const ROUND_SEGMENTS := 12


## Returns a Node3D holding the element of the block (empty for none or unknown ids).
static func build(block: Dictionary) -> Node3D:
	var root := Node3D.new()
	var type := str(block.get("element", "none"))
	if type == "" or type == "none": return root
	var rot := BlockSurface._num(block.get("elemRotation"))
	match type:
		"tube_straight": _build_tube_straight(root, block, rot)
		"tube_corner": _build_tube_path(root, block, rot, [Vector2(0.18, 2.85), Vector2(0.18, 0.18), Vector2(2.85, 0.18)])
		"tube_u": _build_tube_path(root, block, rot, [Vector2(0.15, 2.85), Vector2(0.15, 0.15), Vector2(2.85, 0.15), Vector2(2.85, 2.85)])
		"cone_small": _build_cone(root, block, rot, false)
		"cone_large": _build_cone(root, block, rot, true)
		"goal_flags": _build_flags(root, block, rot)
		"marble_start": _build_marble(root, block, rot)
	return root


## Rotates an element point (u, v) by the element rotation.
static func _rotate_point(u: float, v: float, rot: float) -> Vector2:
	return BlockSurface.rotate_uv(u, v, rot)


## Returns a new red tube material.
static func _tube_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.hex(0xd82218ff)
	mat.roughness = 0.45
	return mat


## Adds a single straight tube along the block edge, honouring an optional tubeSpan.
static func _build_tube_straight(root: Node3D, block: Dictionary, rot: float) -> void:
	var t0 := 0.08
	var t1 := 2.92
	var span: Variant = block.get("tubeSpan")
	if span is Array and span.size() >= 2:
		t0 = BlockSurface._num(span[0])
		t1 = BlockSurface._num(span[1])
	var p0 := _rotate_point(0.18, t0, rot)
	var p1 := _rotate_point(0.18, t1, rot)
	root.add_child(_guard_tube_segment(block, p0, p1, _tube_material()))


## Adds consecutive guard tube segments through the rotated points.
static func _build_tube_path(root: Node3D, block: Dictionary, rot: float, points: Array) -> void:
	var mat := _tube_material()
	var rotated: Array[Vector2] = []
	for p: Vector2 in points: rotated.append(_rotate_point(p.x, p.y, rot))
	for i in range(rotated.size() - 1):
		root.add_child(_guard_tube_segment(block, rotated[i], rotated[i + 1], mat))


## Builds one guard tube segment: two posts, two joint spheres and a connecting bar.
static func _guard_tube_segment(block: Dictionary, a: Vector2, b: Vector2, mat: Material) -> Node3D:
	var group := Node3D.new()
	var y0 := BlockSurface.surface_y(block, a.x, a.y)
	var y1 := BlockSurface.surface_y(block, b.x, b.y)
	var p0 := Vector3(a.x, y0 + POST_HEIGHT, a.y)
	var p1 := Vector3(b.x, y1 + POST_HEIGHT, b.y)
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = TUBE_RADIUS * 0.85
	post_mesh.bottom_radius = TUBE_RADIUS * 0.92
	post_mesh.height = POST_HEIGHT
	post_mesh.radial_segments = ROUND_SEGMENTS
	post_mesh.rings = 1
	_add_mesh(group, post_mesh, mat, Vector3(a.x, y0 + POST_HEIGHT * 0.5, a.y))
	_add_mesh(group, post_mesh, mat, Vector3(b.x, y1 + POST_HEIGHT * 0.5, b.y))
	var joint_mesh := SphereMesh.new()
	joint_mesh.radius = TUBE_RADIUS * 1.05
	joint_mesh.height = joint_mesh.radius * 2.0
	joint_mesh.radial_segments = ROUND_SEGMENTS
	joint_mesh.rings = ROUND_SEGMENTS / 2
	_add_mesh(group, joint_mesh, mat, p0)
	_add_mesh(group, joint_mesh, mat, p1)
	var dir := p1 - p0
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = TUBE_RADIUS
	bar_mesh.bottom_radius = TUBE_RADIUS
	bar_mesh.height = dir.length()
	bar_mesh.radial_segments = ROUND_SEGMENTS
	bar_mesh.rings = 1
	var bar := _add_mesh(group, bar_mesh, mat, p0 + dir * 0.5)
	if dir.length() > 0.0001: bar.basis = Basis(_arc(Vector3.UP, dir.normalized()))
	return group


## Quaternion rotating unit vector a onto unit vector b (handles the opposite case).
static func _arc(a: Vector3, b: Vector3) -> Quaternion:
	if a.dot(b) < -0.9999: return Quaternion(Vector3.RIGHT, PI)
	return Quaternion(a, b)


## Creates a MeshInstance3D, adds it to parent at position and returns it.
static func _add_mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	return inst


## Returns a copy of a mesh with one face normal per triangle (the JS flatShading: true look).
## The face normal keeps the side of the source normals, so lighting direction is unchanged.
static func _flat_shaded(source: Mesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var src_normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var out_verts := PackedVector3Array()
	var out_normals := PackedVector3Array()
	for t in range(0, indices.size(), 3):
		var tri := [indices[t], indices[t + 1], indices[t + 2]]
		var raw_normal := (verts[tri[1]] - verts[tri[0]]).cross(verts[tri[2]] - verts[tri[0]])
		if raw_normal.length_squared() < 1e-12: continue
		var face := raw_normal.normalized()
		var smooth: Vector3 = src_normals[tri[0]] + src_normals[tri[1]] + src_normals[tri[2]]
		if face.dot(smooth) < 0.0: face = -face
		for i in tri:
			out_verts.append(verts[i])
			out_normals.append(face)
	var out_arrays := []
	out_arrays.resize(Mesh.ARRAY_MAX)
	out_arrays[Mesh.ARRAY_VERTEX] = out_verts
	out_arrays[Mesh.ARRAY_NORMAL] = out_normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out_arrays)
	return mesh


## Adds the four sided pyramid and its flat floor shadow.
static func _build_cone(root: Node3D, block: Dictionary, rot: float, is_large: bool) -> void:
	var radius := 1.18 if is_large else 0.72
	var height := 1.85 if is_large else 1.18
	var shape := str(block.get("shape", "flat"))
	var cu := 1.5
	var cv := 1.5
	if is_large and shape == "pit_stepped":
		var c := _rotate_point(1.0, 1.0, BlockSurface._num(block.get("rotation")))
		cu = c.x
		cv = c.y
	var base_y := BlockSurface._num(block.get("elevation")) if shape == "pit_stepped" else BlockSurface.surface_y(block, cu, cv)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color.hex(0xd0d4daff)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
	var source := CylinderMesh.new()
	source.top_radius = 0.0
	source.bottom_radius = radius
	source.height = height
	source.radial_segments = 4
	source.rings = 1
	var cone := _add_mesh(root, _flat_shaded(source), mat, Vector3(cu, base_y + height * 0.5, cv))
	cone.rotation.y = PI / 4.0 + deg_to_rad(rot)
	if shape == "pit": return
	_add_cone_shadow(root, Vector3(cu, base_y + 0.02, cv), is_large)


## Adds the right pointing triangular shadow on the floor under a cone.
static func _add_cone_shadow(root: Node3D, origin: Vector3, is_large: bool) -> void:
	var length := 2.1 if is_large else 1.35
	var half := 0.78 if is_large else 0.48
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([
		origin + Vector3(0, 0, -half),
		origin + Vector3(0, 0, half),
		origin + Vector3(length, 0, -length * 0.65),
	])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.UP, Vector3.UP, Vector3.UP])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0x48 / 255.0, 0x48 / 255.0, 0x48 / 255.0, 0.65)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.disable_receive_shadows = true
	var inst := MeshInstance3D.new()
	inst.name = "ConeShadow"
	inst.mesh = mesh
	inst.material_override = mat
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(inst)


## Adds two poles with checkered flags at the rotated left and right side points.
static func _build_flags(root: Node3D, block: Dictionary, rot: float) -> void:
	var pole_mat := StandardMaterial3D.new()
	pole_mat.albedo_color = Color.hex(0xe8a828ff)
	pole_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.06
	pole_mesh.height = POLE_HEIGHT
	pole_mesh.radial_segments = 8
	pole_mesh.rings = 1
	var flag_mesh := QuadMesh.new()
	flag_mesh.size = Vector2(FLAG_WIDTH, FLAG_HEIGHT)
	var flag_mat := TextureFactory.flag_material()
	for p in [_rotate_point(0.15, 1.5, rot), _rotate_point(2.85, 1.5, rot)]:
		var y := BlockSurface.surface_y(block, p.x, p.y)
		_add_mesh(root, pole_mesh, pole_mat, Vector3(p.x, y + POLE_HEIGHT * 0.5, p.y))
		var flag := _add_mesh(root, flag_mesh, flag_mat, Vector3(p.x - 0.25, y + POLE_HEIGHT - FLAG_HEIGHT * 0.5, p.y - 0.25))
		flag.rotation.y = PI / 4.0 + deg_to_rad(rot)


## Adds the glass marble: contact shadow, inner eight point square and tinted sphere.
static func _build_marble(root: Node3D, block: Dictionary, rot: float) -> void:
	var marble := Node3D.new()
	marble.name = "Marble"
	var y := BlockSurface.surface_y(block, 1.5, 1.5)
	marble.position = Vector3(1.5, y + MARBLE_RADIUS, 1.5)
	root.add_child(marble)
	var shadow_mesh := CylinderMesh.new()
	shadow_mesh.top_radius = MARBLE_RADIUS * 0.88
	shadow_mesh.bottom_radius = MARBLE_RADIUS * 0.88
	shadow_mesh.height = 0.001
	shadow_mesh.radial_segments = 24
	shadow_mesh.rings = 1
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.albedo_color = Color(0x18 / 255.0, 0x18 / 255.0, 0x18 / 255.0, 0.48)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shadow := _add_mesh(marble, shadow_mesh, shadow_mat, Vector3(0, -MARBLE_RADIUS + 0.02, 0))
	shadow.name = "MarbleShadow"
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var inner := Node3D.new()
	inner.name = "InnerSquare"
	inner.rotation = Vector3(PI * 0.22, deg_to_rad(rot), PI * 0.15)
	marble.add_child(inner)
	_add_inner_points(inner)
	var marble_color := _parse_marble_color(block.get("marbleColor"))
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = MARBLE_RADIUS
	sphere_mesh.height = MARBLE_RADIUS * 2.0
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(marble_color, 0x85 / 255.0)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.metallic_specular = 1.0
	glass.roughness = 0.12
	var sphere := _add_mesh(marble, sphere_mesh, glass, Vector3.ZERO)
	sphere.name = "MarbleSphere"


## Adds the 4 corner and 4 median dots of the inner square.
static func _add_inner_points(inner: Node3D) -> void:
	var s := MARBLE_RADIUS * 0.48
	var points := [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s),
		Vector3(0, 0, -s), Vector3(s, 0, 0), Vector3(0, 0, s), Vector3(-s, 0, 0)]
	var dot := SphereMesh.new()
	dot.radius = MARBLE_RADIUS * 0.095
	dot.height = dot.radius * 2.0
	dot.radial_segments = 14
	dot.rings = 7
	var corner_mat := StandardMaterial3D.new()
	corner_mat.albedo_color = Color.hex(0xfff275ff)
	corner_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var median_mat := StandardMaterial3D.new()
	median_mat.albedo_color = Color.hex(0x48dbfbff)
	median_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for i in range(points.size()):
		_add_mesh(inner, dot, corner_mat if i < 4 else median_mat, points[i])


## Parses marbleColor: a '#rrggbb' string or an int 0xrrggbb; invalid values give the default red.
static func _parse_marble_color(value: Variant) -> Color:
	var fallback := Color.hex((DEFAULT_MARBLE_COLOR << 8) | 0xff)
	if value is String: return Color.html(value) if Color.html_is_valid(value) else fallback
	if value is int or value is float: return Color.hex((int(value) << 8) | 0xff)
	return fallback
