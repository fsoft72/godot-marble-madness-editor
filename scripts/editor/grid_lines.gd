class_name GridLines
extends MeshInstance3D
## Wireframe macro grid over the level area (port of the THREE.GridHelper in js/main.js).
## It is a square of max(cols, rows) cells centered on the level, drawn at height 0.

## Colors of the center line and of the other lines (0x3a4466 and 0x1e2436 in the JS).
const CENTER_COLOR := Color("3a4466")
const LINE_COLOR := Color("1e2436")

## Number of line segments in the current mesh.
var _line_count := 0


## Creates the unshaded vertex color material.
func _init() -> void:
	name = "GridLines"
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	material_override = mat


## Rebuilds the lines for a grid of cols x rows cells.
func rebuild(cols: int, rows: int) -> void:
	var divisions := maxi(cols, rows)
	var size := divisions * Constants.BLOCK_SIZE
	var center := Vector3(cols * Constants.BLOCK_SIZE / 2.0, 0.0, rows * Constants.BLOCK_SIZE / 2.0)
	var half := size / 2.0
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	for i in divisions + 1:
		var offset := -half + i * Constants.BLOCK_SIZE
		var color := CENTER_COLOR if i * 2 == divisions else LINE_COLOR
		verts.append_array([center + Vector3(offset, 0.0, -half), center + Vector3(offset, 0.0, half)])
		verts.append_array([center + Vector3(-half, 0.0, offset), center + Vector3(half, 0.0, offset)])
		for _n in 4: colors.append(color)
	_line_count = verts.size() / 2
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = colors
	var new_mesh := ArrayMesh.new()
	new_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arrays)
	mesh = new_mesh


## Returns the number of line segments drawn.
func line_count() -> int:
	return _line_count
