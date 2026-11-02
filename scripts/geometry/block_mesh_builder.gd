class_name BlockMeshBuilder
extends RefCounted
## Builds the mesh and collision faces of one block (port of buildBlockMeshGroup, js/geometry.js).
##
## Local coordinates: x and z in [0, BLOCK_SIZE], y is the world height. The caller places the
## node at (bx * BLOCK_SIZE, 0, bz * BLOCK_SIZE). The geometry is generated once by
## build_parts(); the mesh and the collision faces are both derived from that result.
##
## Winding: the JS code emits counter-clockwise triangles (Three.js). Godot treats clockwise as
## front, so every triangle is emitted with its last two vertices swapped. Normals keep the JS values.
##
## Surfaces are named, top first when present, then trim, wall, wall_right (empty ones are skipped).
## Use SURFACE_TOP etc. with ArrayMesh.surface_find_by_name() to tell them apart.

const SURFACE_TOP := "top"
const SURFACE_TRIM := "trim"
const SURFACE_WALL := "wall"
const SURFACE_WALL_RIGHT := "wall_right"
## Surface emission order, which is also the order of the collision triangles.
const SURFACE_ORDER: Array[String] = [SURFACE_TOP, SURFACE_TRIM, SURFACE_WALL, SURFACE_WALL_RIGHT]

const HALF := Constants.BLOCK_SIZE / 2.0
## Tiles per block side.
const GRID := 3
## Default steps for pit_stepped, indexed [row][col]; NAN means no sub-tile.
const DEFAULT_STEPS := [[0.0, 0.0, -1.2], [0.0, 0.0, -2.2], [-1.2, -2.2, NAN]]
## Light direction of the automatic shading (normalized in _light_dir()).
const LIGHT_DIR_RAW := Vector3(-0.45, 0.75, -0.48)
const SHADE_THRESH_WHITE := 0.82
const SHADE_THRESH_FLAT := 0.68
const SHADE_THRESH_MID := 0.52
## Normal x/z components below this count as a flat triangle.
const FLAT_NORMAL_EPS := 0.04


## Triangle soup with per-vertex attributes for one surface.
class Part:
	extends RefCounted
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()

	## Appends a triangle given in the JS (counter-clockwise) order, emitted clockwise for Godot.
	func add_triangle(p: Array, n: Vector3, uv: Array, color: Color) -> void:
		for i in [0, 2, 1]:
			positions.append(p[i])
			normals.append(n)
			uvs.append(uv[i])
			colors.append(color)


## Builds the mesh of a block; empty (no surfaces) for void and pit blocks.
static func build(block: Dictionary) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var parts := build_parts(block)
	for surface_name in SURFACE_ORDER:
		var part: Part = parts.get(surface_name)
		if part == null or part.positions.is_empty(): continue
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = part.positions
		arrays[Mesh.ARRAY_NORMAL] = part.normals
		arrays[Mesh.ARRAY_TEX_UV] = part.uvs
		arrays[Mesh.ARRAY_COLOR] = part.colors
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_name(idx, surface_name)
		mesh.surface_set_material(idx, _material_for(surface_name, block))
	return mesh


## Returns the vertex color of a shade multiplier: R = palette level / 5 (read by the top shader).
static func shade_color(shade: float) -> Color:
	var level := Constants.shade_level(shade) / 5.0
	return Color(level, level, level)


## Returns the triangle soup (all surfaces, in surface order) for a ConcavePolygonShape3D.
static func build_collision_faces(block: Dictionary) -> PackedVector3Array:
	var faces := PackedVector3Array()
	var parts := build_parts(block)
	for surface_name in SURFACE_ORDER:
		var part: Part = parts.get(surface_name)
		if part == null: continue
		faces.append_array(part.positions)
	return faces


## Generates the geometry once: returns {surface name: Part}; empty for void, pit and missing blocks.
static func build_parts(block: Dictionary) -> Dictionary:
	if block.is_empty() or block.get("isVoid", false) == true: return {}
	var shape := str(block.get("shape", ""))
	if shape == "pit": return {}
	var parts := {}
	for surface_name in SURFACE_ORDER:
		parts[surface_name] = Part.new()
	var tiles: Variant = block.get("tiles")
	if tiles is Array and tiles.size() == 3:
		_add_tiles(block, tiles, parts)
	elif shape == "pit_stepped" or shape == "subtiles_custom":
		_add_stepped(block, parts)
	else:
		_add_top(block, parts[SURFACE_TOP])
		_add_perimeter_walls(block, parts)
	return parts


## Returns the material of a surface for the block (top depends on decal and rotation).
static func _material_for(surface_name: String, block: Dictionary) -> Material:
	if surface_name == SURFACE_TOP:
		var paint: Variant = block.get("paint")
		if paint is Array and not paint.is_empty():
			return TextureFactory.make_top_material(TextureFactory.paint_image(paint))
		return TextureFactory.top_surface_material(str(block.get("decal", "none")), int(_num(block.get("decalRotation"))))
	return TextureFactory.cliff_materials()[surface_name]


## Converts a Variant to float, 0.0 for null and non-numbers (JS Number() on undefined/null).
static func _num(value: Variant, fallback: float = 0.0) -> float:
	if value is int or value is float: return float(value)
	return fallback


## Normalized light direction of the automatic shading.
static func _light_dir() -> Vector3:
	return LIGHT_DIR_RAW.normalized()


## Returns the shade color value of a top triangle (port of getSubtileTriangleShade).
static func _triangle_shade(block: Dictionary, r: int, c: int, upper_left: bool, normal: Vector3) -> float:
	var shade: Dictionary = Constants.SHADE
	var sub_shades: Variant = block.get("subShades")
	if sub_shades is Array and r < sub_shades.size() and sub_shades[r] is Array and c < sub_shades[r].size():
		var entry: Variant = sub_shades[r][c]
		if entry is Array and entry.size() >= 2: return _num(entry[0] if upper_left else entry[1])
		if entry != null: return _num(entry)
	match str(block.get("shadePreset", "")):
		"funnel_bevel_left":
			if c == 2: return shade["FLAT"] if upper_left else shade["DARK"]
			return shade["FLAT"]
		"funnel_center":
			if c == 0: return shade["FLAT"] if upper_left else shade["DARK"]
			if c == 1: return shade["MID"]
			return shade["LIGHT"]
		"funnel_throat":
			if c == 0: return shade["DARK"]
			if c == 1: return shade["DARK"] if upper_left else shade["WHITE"]
			return shade["WHITE"]
		"chute_leg_x":
			return shade["WHITE"]
		"turn_right":
			if r + c < 2: return shade["WHITE"]
			if r + c > 2: return shade["WHITE"] if c == 2 else shade["DARK"]
			return shade["WHITE"] if upper_left else shade["DARK"]
		"chute_leg_z":
			return shade["MID"] if c < 2 else shade["WHITE"]
		"turn_left_dark":
			if r + c < 2: return shade["DARK"]
			if r + c > 2: return shade["WHITE"]
			return shade["DARK"] if upper_left else shade["WHITE"]
		"wing_dark":
			return shade["DARK"]
		"wing_white":
			return shade["WHITE"]
	if absf(normal.x) < FLAT_NORMAL_EPS and absf(normal.z) < FLAT_NORMAL_EPS: return shade["FLAT"]
	var d := normal.dot(_light_dir())
	if d > SHADE_THRESH_WHITE: return shade["WHITE"]
	if d > SHADE_THRESH_FLAT: return shade["FLAT"]
	if d > SHADE_THRESH_MID: return shade["MID"]
	return shade["DARK"]


## Adds one top triangle (JS vertex order) with its shade and face normal.
static func _push_top_triangle(block: Dictionary, part: Part, p: Array, uv: Array, r: int, c: int, upper_left: bool) -> void:
	var n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0]).normalized()
	var s := _triangle_shade(block, r, c, upper_left, n)
	part.add_triangle(p, n, uv, shade_color(s))


## Returns whether the tiles of the block are split along the anti-diagonal.
static func _uses_anti_diagonal(block: Dictionary) -> bool:
	var diag := str(block.get("diagSplit", ""))
	if diag != "": return diag == "anti"
	var shape := str(block.get("shape", ""))
	if shape == "fold_left" or shape == "fold_right": return true
	return str(block.get("shadePreset", "")) in ["funnel_bevel_left", "funnel_center", "turn_right", "turn_left_dark"]


## Adds the 3x3 top surface tiles, honoring cutouts, goal_bevel and the diagonal split.
static func _add_top(block: Dictionary, part: Part) -> void:
	var is_goal_bevel := str(block.get("shape", "")) == "goal_bevel"
	var rot := _num(block.get("rotation"))
	var cutout := str(block.get("cutout", ""))
	var anti := _uses_anti_diagonal(block)
	for r in GRID:
		for c in GRID:
			var p00 := _top_point(block, c, r)
			var p10 := _top_point(block, c + 1, r)
			var p01 := _top_point(block, c, r + 1)
			var p11 := _top_point(block, c + 1, r + 1)
			var uv00 := _top_uv(c, r)
			var uv10 := _top_uv(c + 1, r)
			var uv01 := _top_uv(c, r + 1)
			var uv11 := _top_uv(c + 1, r + 1)
			if cutout == "wing_left":
				if r + c < 2: continue
				if r + c == 2:
					_push_top_triangle(block, part, [p10, p01, p11], [uv10, uv01, uv11], r, c, false)
					continue
			elif cutout == "wing_right":
				if r + c > 2: continue
				if r + c == 2:
					_push_top_triangle(block, part, [p00, p01, p10], [uv00, uv01, uv10], r, c, true)
					continue
			if is_goal_bevel:
				var ruv := BlockSurface.rotate_uv(c + 0.5, r + 0.5, rot)
				var sc := floori(ruv.x)
				var sr := floori(ruv.y)
				if sr == 2 and sc == 0:
					_push_top_triangle(block, part, [p00, p11, p10], [uv00, uv11, uv10], r, c, true)
					continue
				if sr == 2 and sc == 2:
					_push_top_triangle(block, part, [p00, p01, p10], [uv00, uv01, uv10], r, c, true)
					continue
			if anti:
				_push_top_triangle(block, part, [p00, p01, p10], [uv00, uv01, uv10], r, c, true)
				_push_top_triangle(block, part, [p10, p01, p11], [uv10, uv01, uv11], r, c, false)
			else:
				_push_top_triangle(block, part, [p00, p01, p11], [uv00, uv01, uv11], r, c, true)
				_push_top_triangle(block, part, [p00, p11, p10], [uv00, uv11, uv10], r, c, false)


## Returns the local top surface point at integer grid coordinates (u, v).
static func _top_point(block: Dictionary, u: int, v: int) -> Vector3:
	return Vector3(u, BlockSurface.surface_y(block, u, v), v)


## Returns the top texture UV of grid coordinates (u, v). Godot's V runs top to bottom,
## so the image row at z = 0 (Three's v = 1) is V = 0 and decals are not mirrored.
static func _top_uv(u: int, v: int) -> Vector2:
	return Vector2(u / 3.0, v / 3.0)


## Adds the perimeter cliff walls, honoring cutouts and cliffShadow.
static func _add_perimeter_walls(block: Dictionary, parts: Dictionary) -> void:
	var cutout := str(block.get("cutout", ""))
	var shadow: Array = [Constants.DEFAULT_TRIM_HEIGHT, Constants.DEFAULT_TRIM_HEIGHT, Constants.DEFAULT_TRIM_HEIGHT, Constants.DEFAULT_TRIM_HEIGHT]
	var cliff_shadow: Variant = block.get("cliffShadow")
	if cliff_shadow is Array and cliff_shadow.size() == 4:
		for i in 4:
			shadow[i] = _num(cliff_shadow[i])
	for i in GRID:
		var a := i
		var b := i + 1
		if cutout != "wing_right":
			# Front-left wall (v = 3), normal +Z, with variable trim depth.
			_add_wall_with_trim(parts, true, Vector3(a, BlockSurface.surface_y(block, a, 3), 3), Vector3(b, BlockSurface.surface_y(block, b, 3), 3), a, b, shadow[i], shadow[i + 1])
		if cutout != "wing_left":
			# Back-right wall (v = 0), normal -Z.
			_add_wall_with_trim(parts, true, Vector3(b, BlockSurface.surface_y(block, b, 0), 0), Vector3(a, BlockSurface.surface_y(block, a, 0), 0), a, b)
		if cutout != "wing_right":
			# Front-right wall (u = 3), normal +X.
			_add_wall_with_trim(parts, false, Vector3(3, BlockSurface.surface_y(block, 3, b), b), Vector3(3, BlockSurface.surface_y(block, 3, a), a), a, b)
		if cutout != "wing_left":
			# Back-left wall (u = 0), normal -X.
			_add_wall_with_trim(parts, false, Vector3(0, BlockSurface.surface_y(block, 0, a), a), Vector3(0, BlockSurface.surface_y(block, 0, b), b), a, b)


## Height difference below which two tile edges count as joined (no wall between them).
const EDGE_JOIN_EPS := 0.001


## Adds the tiles of a "tiles" block: two triangles per tile from its own corners (holes are
## skipped) and a cliff wall on every tile edge that is not joined to the neighbor tile.
static func _add_tiles(block: Dictionary, tiles: Array, parts: Dictionary) -> void:
	var elev := _num(block.get("elevation"))
	for r in GRID:
		for c in GRID:
			var h := BlockSurface.tile_corners(tiles, c, r)
			if h.is_empty(): continue
			var p00 := Vector3(c, elev + h[0], r)
			var p10 := Vector3(c + 1, elev + h[1], r)
			var p01 := Vector3(c, elev + h[2], r + 1)
			var p11 := Vector3(c + 1, elev + h[3], r + 1)
			var uv00 := _top_uv(c, r)
			var uv10 := _top_uv(c + 1, r)
			var uv01 := _top_uv(c, r + 1)
			var uv11 := _top_uv(c + 1, r + 1)
			var part: Part = parts[SURFACE_TOP]
			if BlockSurface.tile_split(block, c, r) == "anti":
				_push_top_triangle(block, part, [p00, p01, p10], [uv00, uv01, uv10], r, c, true)
				_push_top_triangle(block, part, [p10, p01, p11], [uv10, uv01, uv11], r, c, false)
			else:
				_push_top_triangle(block, part, [p00, p01, p11], [uv00, uv01, uv11], r, c, true)
				_push_top_triangle(block, part, [p00, p11, p10], [uv00, uv11, uv10], r, c, false)
			_add_tile_walls(tiles, parts, c, r, h, p00, p10, p01, p11)


## Adds the walls of the four edges of tile (c, r) that are not joined to their neighbor
## tile; h holds the corner offsets [h00, h10, h01, h11] of the tile.
static func _add_tile_walls(tiles: Array, parts: Dictionary, c: int, r: int, h: Array, p00: Vector3, p10: Vector3, p01: Vector3, p11: Vector3) -> void:
	# Front-left edge (v = r + 1), normal +Z: joined to the next row's h00, h10.
	if not _joined(BlockSurface.tile_corners(tiles, c, r + 1), [0, 1], [h[2], h[3]]):
		_add_wall_with_trim(parts, true, p01, p11, c, c + 1)
	# Back-right edge (v = r), normal -Z: joined to the previous row's h01, h11.
	if not _joined(BlockSurface.tile_corners(tiles, c, r - 1), [2, 3], [h[0], h[1]]):
		_add_wall_with_trim(parts, true, p10, p00, c, c + 1)
	# Front-right edge (u = c + 1), normal +X: joined to the next column's h00, h01.
	if not _joined(BlockSurface.tile_corners(tiles, c + 1, r), [0, 2], [h[1], h[3]]):
		_add_wall_with_trim(parts, false, p11, p10, r, r + 1)
	# Back-left edge (u = c), normal -X: joined to the previous column's h10, h11.
	if not _joined(BlockSurface.tile_corners(tiles, c - 1, r), [1, 3], [h[0], h[2]]):
		_add_wall_with_trim(parts, false, p00, p01, r, r + 1)


## Returns whether the neighbor corners n[idx[0]], n[idx[1]] equal the edge offsets `edge`.
static func _joined(n: Array, idx: Array, edge: Array) -> bool:
	if n.is_empty(): return false
	return absf(n[idx[0]] - edge[0]) < EDGE_JOIN_EPS and absf(n[idx[1]] - edge[1]) < EDGE_JOIN_EPS


## Adds the stepped sub-tile pillars of pit_stepped and subtiles_custom blocks.
static func _add_stepped(block: Dictionary, parts: Dictionary) -> void:
	var elev := _num(block.get("elevation"))
	var rot := _num(block.get("rotation"))
	var custom := str(block.get("shape", "")) == "subtiles_custom" and block.get("subHeights") != null
	var sub_heights: Variant = block.get("subHeights")
	for r in GRID:
		for c in GRID:
			var offset := NAN
			if custom:
				offset = _sub_height(sub_heights, r, c)
			else:
				var ruv := BlockSurface.rotate_uv(c + 0.5, r + 0.5, rot)
				var sc := clampi(floori(ruv.x), 0, 2)
				var sr := clampi(floori(ruv.y), 0, 2)
				offset = DEFAULT_STEPS[sr][sc]
			if is_nan(offset): continue
			_add_stepped_tile(parts, c, r, elev + offset)


## Returns subHeights[r][c] or NAN when it is missing, null or not a number.
static func _sub_height(sub_heights: Variant, r: int, c: int) -> float:
	if not sub_heights is Array or r >= sub_heights.size(): return NAN
	var row: Variant = sub_heights[r]
	if not row is Array or c >= row.size(): return NAN
	var value: Variant = row[c]
	if value is int or value is float: return float(value)
	return NAN


## Adds one flat sub-tile at column c, row r with height y, plus its four walls.
static func _add_stepped_tile(parts: Dictionary, c: int, r: int, y: float) -> void:
	var part: Part = parts[SURFACE_TOP]
	var x0 := float(c)
	var x1 := float(c + 1)
	var z0 := float(r)
	var z1 := float(r + 1)
	var u0 := c / 3.0
	var u1 := (c + 1) / 3.0
	var v0 := r / 3.0
	var v1 := (r + 1) / 3.0
	var color := shade_color(Constants.SHADE["FLAT"])
	part.add_triangle([Vector3(x0, y, z0), Vector3(x0, y, z1), Vector3(x1, y, z1)], Vector3.UP, [Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1)], color)
	part.add_triangle([Vector3(x0, y, z0), Vector3(x1, y, z1), Vector3(x1, y, z0)], Vector3.UP, [Vector2(u0, v0), Vector2(u1, v1), Vector2(u1, v0)], color)
	_add_wall_with_trim(parts, true, Vector3(x0, y, z1), Vector3(x1, y, z1), c, c + 1)
	_add_wall_with_trim(parts, true, Vector3(x1, y, z0), Vector3(x0, y, z0), c, c + 1)
	_add_wall_with_trim(parts, false, Vector3(x1, y, z1), Vector3(x1, y, z0), r, r + 1)
	_add_wall_with_trim(parts, false, Vector3(x0, y, z0), Vector3(x0, y, z1), r, r + 1)


## Adds a cliff wall from top edge p0 -> p1 down to PILLAR_BOTTOM (port of addCliffWallWithTrim).
## With_trim walls (yellow) get an orange trim band on top; the others (crimson) have none.
static func _add_wall_with_trim(parts: Dictionary, with_trim: bool, p0: Vector3, p1: Vector3, u0: float, u1: float, trim0: float = Constants.DEFAULT_TRIM_HEIGHT, trim1: float = Constants.DEFAULT_TRIM_HEIGHT) -> void:
	var dx := p1.x - p0.x
	var dz := p1.z - p0.z
	var length := Vector2(dx, dz).length()
	if length == 0.0: length = 1.0
	var n := Vector3(-dz / length, 0.0, dx / length)
	var bottom := Constants.PILLAR_BOTTOM
	if with_trim:
		var mid0 := p0.y - trim0
		var mid1 := p1.y - trim1
		_push_wall_quad(parts[SURFACE_TRIM], n, p0, p1, p0.y, p1.y, mid0, mid1, u0, u1)
		_push_wall_quad(parts[SURFACE_WALL], n, p0, p1, mid0, mid1, bottom, bottom, u0, u1)
	else:
		_push_wall_quad(parts[SURFACE_WALL_RIGHT], n, p0, p1, p0.y, p1.y, bottom, bottom, u0, u1)


## Pushes a wall quad (two triangles). V is 0 at the top edge and 1 at the bottom edge
## (Godot orientation of the JS 1.0 top / 0.0 bottom).
static func _push_wall_quad(part: Part, n: Vector3, p0: Vector3, p1: Vector3, top0: float, top1: float, bot0: float, bot1: float, u0: float, u1: float) -> void:
	var a := Vector3(p0.x, top0, p0.z)
	var b := Vector3(p0.x, bot0, p0.z)
	var c := Vector3(p1.x, bot1, p1.z)
	var d := Vector3(p1.x, top1, p1.z)
	var white := Color.WHITE
	part.add_triangle([a, b, c], n, [Vector2(u0, 0), Vector2(u0, 1), Vector2(u1, 1)], white)
	part.add_triangle([a, c, d], n, [Vector2(u0, 0), Vector2(u1, 1), Vector2(u1, 0)], white)
