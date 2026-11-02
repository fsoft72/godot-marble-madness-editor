class_name ElementBuilder
extends RefCounted
## Builds the visual element placed on a block (port of buildElementOnBlock and
## createGuardTubeSegment from js/geometry.js). Visual only, no collision.
## Output coordinates are block local: x = u, z = v, y is world height.

## Height of the rail axis above the floor and rail radius (measured on the arcade reference:
## the rail top is 8 pixels above the floor, the rail is 5 pixels thick).
const POST_HEIGHT := 0.55
const TUBE_RADIUS := 0.26
const MARBLE_RADIUS := 0.52
const DEFAULT_MARBLE_COLOR := 0xe61922
## Goal flag pole and cloth, measured on the arcade reference (pole 22 pixels, cloth 12x11).
const POLE_HEIGHT := 2.25
const FLAG_WIDTH := 1.2
const FLAG_HEIGHT := 1.1
const ROUND_SEGMENTS := 12
const GLASS_SHADER_PATH := "res://shaders/glass_marble.gdshader"
## Height of the invisible copy of a tube collider that stops the marble climbing over the rail.
const TUBE_COLLISION_LIFT := 0.5
const CONE_NAME := "Cone"
const TUBE_ELEMENTS: Array[String] = ["tube_straight", "tube_corner", "tube_u", "tube_path"]
const TOON_SHADER_PATH := "res://shaders/arcade_toon.gdshader"
## Toon ramps (sRGB 0..255), darkest first: red tubes and gray cones of the arcade palette.
const TUBE_RAMP: Array[Vector3] = [Vector3(102, 34, 34), Vector3(136, 34, 34), Vector3(170, 34, 34), Vector3(221, 51, 51), Vector3(255, 136, 136)]
const CONE_RAMP: Array[Vector3] = [Vector3(51, 51, 51), Vector3(68, 68, 68), Vector3(153, 153, 153), Vector3(187, 187, 187), Vector3(221, 221, 221)]
const CONE_ELEMENTS: Array[String] = ["cone_small", "cone_large"]


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
		"tube_path": _build_tube_points(root, block)
		"cone_small": _build_cone(root, block, rot, false)
		"cone_large": _build_cone(root, block, rot, true)
		"goal_flags": _build_flags(root, block, rot)
		"marble_start": _build_marble(root, block, rot)
	return root


## Returns collision triangles of the solid parts of a built element, from its visible meshes:
## every tube mesh and the cone pyramid. Flags, marble and floor shadows are not solid.
## Tubes also get a raised copy: the visible rail is lower than the marble could climb over.
static func collision_faces(element: Node3D, block: Dictionary) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var type := str(block.get("element", "none"))
	if type in TUBE_ELEMENTS:
		_gather_faces(element, Transform3D.IDENTITY, faces)
		var rail_top := faces.duplicate()
		for p in rail_top: faces.append(p + Vector3.UP * TUBE_COLLISION_LIFT)
	elif type in CONE_ELEMENTS:
		var cone := element.get_node_or_null(CONE_NAME) as MeshInstance3D
		if cone != null: _append_mesh_faces(cone, cone.transform, faces)
	return faces


## Returns a new marble visual centered on its origin, without its floor shadow.
static func make_rolling_marble(color_value: Variant) -> Node3D:
	var root := Node3D.new()
	_build_marble(root, {"marbleColor": color_value}, 0.0)
	var marble := root.get_child(0) as Node3D
	root.remove_child(marble)
	root.free()
	marble.position = Vector3.ZERO
	var shadow := marble.get_node("MarbleShadow")
	marble.remove_child(shadow)
	shadow.free()
	return marble


## Appends the faces of every mesh below a node, walking down the accumulated transform.
static func _gather_faces(node: Node, xform: Transform3D, faces: PackedVector3Array) -> void:
	for child in node.get_children():
		var child_xform := xform * (child as Node3D).transform
		if child is MeshInstance3D: _append_mesh_faces(child, child_xform, faces)
		_gather_faces(child, child_xform, faces)


## Appends the triangles of one mesh instance after applying a transform.
static func _append_mesh_faces(inst: MeshInstance3D, xform: Transform3D, faces: PackedVector3Array) -> void:
	for p in inst.mesh.get_faces(): faces.append(xform * p)


## Rotates an element point (u, v) by the element rotation.
static func _rotate_point(u: float, v: float, rot: float) -> Vector2:
	return BlockSurface.rotate_uv(u, v, rot)


## Returns a new red tube material (arcade toon ramp).
static func _tube_material() -> ShaderMaterial:
	return toon_material(TUBE_RAMP)


## Returns a toon shader material with a five color ramp (sRGB 0..255, darkest first).
static func toon_material(ramp: Array[Vector3]) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(TOON_SHADER_PATH)
	for i in 5:
		mat.set_shader_parameter("c%d" % i, ramp[i])
	return mat


## Adds a guard tube through free points: block "tubePoints" [[u, y, v], ...] are rail axis
## points in block local x/z with absolute height y; "tubePosts" lists the indices of the
## points that stand on a post down to the floor (POST_HEIGHT below the axis).
static func _build_tube_points(root: Node3D, block: Dictionary) -> void:
	var raw: Variant = block.get("tubePoints")
	if not raw is Array or raw.size() < 2: return
	var pts: Array[Vector3] = []
	for p in raw:
		if p is Array and p.size() == 3: pts.append(Vector3(BlockSurface._num(p[0]), BlockSurface._num(p[1]), BlockSurface._num(p[2])))
	if pts.size() < 2: return
	var mat := _tube_material()
	var group := Node3D.new()
	root.add_child(group)
	for i in range(pts.size() - 1):
		_add_bar(group, pts[i], pts[i + 1], mat)
	var joint := SphereMesh.new()
	joint.radius = TUBE_RADIUS
	joint.height = TUBE_RADIUS * 2.0
	joint.radial_segments = ROUND_SEGMENTS
	joint.rings = ROUND_SEGMENTS / 2
	for p in pts: _add_mesh(group, joint, mat, p)
	var posts: Variant = block.get("tubePosts")
	if not posts is Array: return
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = TUBE_RADIUS * 0.85
	post_mesh.bottom_radius = TUBE_RADIUS * 0.92
	post_mesh.height = POST_HEIGHT
	post_mesh.radial_segments = ROUND_SEGMENTS
	post_mesh.rings = 1
	for idx in posts:
		var i := int(BlockSurface._num(idx))
		if i < 0 or i >= pts.size(): continue
		_add_mesh(group, post_mesh, mat, pts[i] - Vector3(0, POST_HEIGHT * 0.5, 0))


## Adds a straight rail bar between two axis points.
static func _add_bar(parent: Node3D, p0: Vector3, p1: Vector3, mat: Material) -> void:
	var dir := p1 - p0
	if dir.length() < 0.0001: return
	var bar_mesh := CylinderMesh.new()
	bar_mesh.top_radius = TUBE_RADIUS
	bar_mesh.bottom_radius = TUBE_RADIUS
	bar_mesh.height = dir.length()
	bar_mesh.radial_segments = ROUND_SEGMENTS
	bar_mesh.rings = 1
	var bar := _add_mesh(parent, bar_mesh, mat, p0 + dir * 0.5)
	bar.basis = Basis(_arc(Vector3.UP, dir.normalized()))


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
	# Toon shaded parts are lit by the sun only, like the blocks (the fill light skips them).
	if mat is ShaderMaterial and (mat as ShaderMaterial).shader.resource_path == TOON_SHADER_PATH:
		inst.layers = Constants.BLOCK_RENDER_LAYER
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
		# Godot front faces are clockwise: the counter-clockwise normal must point inward.
		if raw_normal.dot(face) > 0.0: tri = [tri[0], tri[2], tri[1]]
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
	var size: Variant = block.get("coneSize")
	if size is Array and size.size() == 2:
		radius = BlockSurface._num(size[0])
		height = BlockSurface._num(size[1])
	var shape := str(block.get("shape", "flat"))
	var cu := 1.5
	var cv := 1.5
	var offset: Variant = block.get("elemOffset")
	if offset is Array and offset.size() == 2:
		cu = BlockSurface._num(offset[0])
		cv = BlockSurface._num(offset[1])
	elif is_large and shape == "pit_stepped":
		var c := _rotate_point(1.0, 1.0, BlockSurface._num(block.get("rotation")))
		cu = c.x
		cv = c.y
	var base_y := BlockSurface._num(block.get("elevation")) if shape == "pit_stepped" else BlockSurface.surface_y(block, cu, cv)
	if block.get("elemY") is float or block.get("elemY") is int: base_y = float(block["elemY"])
	var mat := toon_material(CONE_RAMP)
	var source := CylinderMesh.new()
	source.top_radius = 0.0
	source.bottom_radius = radius
	source.height = height
	source.radial_segments = 4
	source.rings = 1
	var cone := _add_mesh(root, _flat_shaded(source), mat, Vector3(cu, base_y + height * 0.5, cv))
	cone.name = CONE_NAME
	cone.rotation.y = PI / 4.0 + deg_to_rad(rot)
	if shape == "pit" or block.has("coneSize"): return
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
	var feet: Array[Vector3] = []
	var raw: Variant = block.get("flagPoints")
	if raw is Array:
		for f in raw:
			if f is Array and f.size() == 3: feet.append(Vector3(BlockSurface._num(f[0]), BlockSurface._num(f[1]), BlockSurface._num(f[2])))
	if feet.is_empty():
		for q in [_rotate_point(0.15, 1.5, rot), _rotate_point(2.85, 1.5, rot)]:
			feet.append(Vector3(q.x, BlockSurface.surface_y(block, q.x, q.y), q.y))
	for foot in feet:
		var p := Vector2(foot.x, foot.z)
		var y := foot.y
		_add_mesh(root, pole_mesh, pole_mat, Vector3(p.x, y + POLE_HEIGHT * 0.5, p.y))
		# The cloth hangs from the pole along the block X axis (turned by elemRotation).
		var along := Vector3(cos(deg_to_rad(rot)), 0.0, -sin(deg_to_rad(rot)))
		var flag := _add_mesh(root, flag_mesh, flag_mat, Vector3(p.x, y + POLE_HEIGHT - FLAG_HEIGHT * 0.5, p.y) + along * FLAG_WIDTH * 0.5)
		flag.rotation.y = deg_to_rad(rot)


## Adds the glass marble: contact shadow and the ray traced glass sphere (its inner core of
## eight dots is traced by the shader).
static func _build_marble(root: Node3D, block: Dictionary, rot: float) -> void:
	var marble := Node3D.new()
	marble.name = "Marble"
	var at := Vector2(1.5, 1.5)
	var offset: Variant = block.get("elemOffset")
	if offset is Array and offset.size() == 2: at = Vector2(BlockSurface._num(offset[0]), BlockSurface._num(offset[1]))
	var y := BlockSurface.surface_y(block, at.x, at.y)
	if block.get("elemY") is float or block.get("elemY") is int: y = float(block["elemY"])
	marble.position = Vector3(at.x, y + MARBLE_RADIUS, at.y)
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
	var marble_color := _parse_marble_color(block.get("marbleColor"))
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = MARBLE_RADIUS
	sphere_mesh.height = MARBLE_RADIUS * 2.0
	sphere_mesh.radial_segments = 32
	sphere_mesh.rings = 16
	var sphere := _add_mesh(marble, sphere_mesh, make_glass_material(marble_color, rot), Vector3.ZERO)
	sphere.name = "MarbleSphere"
	sphere.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON


## Returns the ray traced glass material of a marble (shaders/glass_marble.gdshader): tinted by
## `color`, with the inner core of eight dots turned like the JS inner square (elemRotation).
static func make_glass_material(color: Color, rot_degrees: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = load(GLASS_SHADER_PATH)
	mat.set_shader_parameter("tint", Color(color.r, color.g, color.b))
	mat.set_shader_parameter("radius", MARBLE_RADIUS)
	mat.set_shader_parameter("sun_dir_world", -LevelEnvironment.sun_direction())
	mat.set_shader_parameter("core_basis", Basis.from_euler(Vector3(PI * 0.22, deg_to_rad(rot_degrees), PI * 0.15)))
	return mat


## Parses marbleColor: a '#rrggbb' string or an int 0xrrggbb; invalid values give the default red.
static func _parse_marble_color(value: Variant) -> Color:
	var fallback := Color.hex((DEFAULT_MARBLE_COLOR << 8) | 0xff)
	if value is String: return Color.html(value) if Color.html_is_valid(value) else fallback
	if value is int or value is float: return Color.hex((int(value) << 8) | 0xff)
	return fallback
