class_name TextureFactory
extends RefCounted
## Procedural textures and materials (port of js/textures.js).
## Everything is drawn with Image primitives (rects and scanline polygons), no art assets.

const TILE_COUNT := 3
const BASE_SIZE := 192
const DECAL_NONE := "none"
const KNOWN_DECALS: Array[String] = [
	"arrow_wide_diag", "arrow_wide_ortho", "arrow_long_chevrons",
	"arrow_shaft_only", "pad_456", "goal_banner",
]

const FLAG_W := 64
const FLAG_H := 48
const FLAG_COLS := 4
const FLAG_ROWS := 3

const RED := Color("#cf241c")
const RED_BRIGHT := Color("#e62e24")

## 5x7 pixel glyphs used for the "GOAL" banner and the pad numbers.
const GLYPHS := {
	"G": [".###.", "#...#", "#....", "#.###", "#...#", "#...#", ".###."],
	"O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
	"A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
	"L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
	"4": ["..##.", ".#.#.", "#..#.", "#####", "...#.", "...#.", "...#."],
	"5": ["#####", "#....", "####.", "....#", "....#", "#...#", ".###."],
	"6": ["..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."],
}
const GLYPH_W := 5
const GLYPH_H := 7

## Texels per tile of the tile pattern (pixel centers of the 2:1 projection hit texel centers).
const TILE_PATTERN_SIZE := 16
## Tile pattern offsets taken from a flat tile of assets/level01_ref.png (0 fill, 1 edge, 2 line);
## row = v (z), column = u (x).
const TILE_PATTERN: Array[String] = [
	"2222222222222222", "2212221222122222", "2111201120112122", "2111000100010112",
	"2210000000000012", "2200000000000022", "2100000000000122", "2110000000000112",
	"2210000000000012", "2200000000000022", "2100000000000122", "2110000000000112",
	"2210000000000012", "2210001000100022", "2211021102110222", "2221222122212222",
]
## Texels per block side of the paint map (16 per tile).
const PAINT_SIZE := 48
const TOP_SHADER_PATH := "res://shaders/arcade_top.gdshader"
const WALL_SHADER_PATH := "res://shaders/arcade_wall.gdshader"
## Wall colors of the arcade palette (sRGB 0..255).
const WALL_YELLOW := Vector3(204, 204, 0)
const WALL_ORANGE := Vector3(204, 102, 0)
const WALL_CRIMSON := Vector3(136, 34, 34)
const WALL_SEAM_LIT := Vector3(102, 102, 102)
const WALL_SEAM_DARK := Vector3(51, 51, 51)

static var _cache := {}


## Drops every cached material (used by tests).
static func clear_cache() -> void:
	_cache.clear()


## Returns the cached material for a 3x3 block top surface: the arcade palette shader
## (shaders/arcade_top.gdshader) with the tile pattern and the decal as a paint map.
## Vertex colors carry the shade level; unknown decals fall back to "none".
## decal_rotation is in degrees (multiples of 90).
static func top_surface_material(decal: String, decal_rotation: int) -> ShaderMaterial:
	var decal_name := decal if decal in KNOWN_DECALS else DECAL_NONE
	var key := "top_%s_%d" % [decal_name, decal_rotation]
	if _cache.has(key): return _cache[key]
	var layer := Image.create(BASE_SIZE, BASE_SIZE, false, Image.FORMAT_RGBA8)
	if decal_name != DECAL_NONE:
		_draw_decal(layer, decal_name)
		_rotate_layer(layer, decal_rotation)
	var mat := make_top_material(_paint_from_layer(layer))
	_cache[key] = mat
	return mat


## Returns a new top surface shader material using a paint image (see paint_image()).
static func make_top_material(paint: Image) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(TOP_SHADER_PATH)
	mat.set_shader_parameter("pattern", tile_pattern_texture())
	mat.set_shader_parameter("paint", ImageTexture.create_from_image(paint))
	return mat


## Returns the cached per tile offset pattern (0 fill, 1 edge, 2 line) as a texture,
## TILE_PATTERN_SIZE texels per tile, R = offset / 3.
static func tile_pattern_texture() -> ImageTexture:
	if _cache.has("tile_pattern"): return _cache["tile_pattern"]
	var img := Image.create(TILE_PATTERN_SIZE, TILE_PATTERN_SIZE, false, Image.FORMAT_RGBA8)
	for y in TILE_PATTERN_SIZE:
		var row: String = TILE_PATTERN[y]
		for x in TILE_PATTERN_SIZE:
			img.set_pixel(x, y, Color(int(row[x]) / 3.0, 0, 0, 1))
	var tex := ImageTexture.create_from_image(img)
	_cache["tile_pattern"] = tex
	return tex


## First character of the absolute paint codes: code = PAINT_CODE_BASE + ramp * 6 + level.
const PAINT_CODE_BASE := "A"


## Builds a paint image from rows of texel codes, one char per texel (row = v, column = u):
## "." unpainted, "0".."3" decal ramp (tile pattern kept), "A".."L" absolute color
## (PAINT_CODE_BASE + ramp * 6 + level, gray ramp 0 or red ramp 1).
static func paint_image(rows: Array) -> Image:
	var h := maxi(rows.size(), 1)
	var w := 1
	for row in rows: w = maxi(w, str(row).length())
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for y in rows.size():
		var row := str(rows[y])
		for x in row.length():
			var ch := row[x]
			if ch >= "0" and ch <= "3":
				img.set_pixel(x, y, Color(int(ch) / 3.0, 0, 0, 0.5))
				continue
			var code := ch.unicode_at(0) - PAINT_CODE_BASE.unicode_at(0)
			if code < 0 or code >= 12: continue
			img.set_pixel(x, y, Color((code / 6) / 3.0, (code % 6) / 5.0, 0, 1))
	return img


## Returns the cliff wall materials: "wall" and "trim" (yellow, orange in the shadow) and
## "wall_right" (crimson). Cached. The trim is drawn like the wall: shadows come from the sun.
static func cliff_materials() -> Dictionary:
	if _cache.has("cliff_materials"): return _cache["cliff_materials"]
	var yellow := _wall_material(WALL_YELLOW, WALL_SEAM_LIT, WALL_ORANGE, WALL_SEAM_DARK)
	var mats := {
		"wall": yellow,
		"trim": yellow,
		"wall_right": _wall_material(WALL_CRIMSON, WALL_SEAM_DARK, WALL_CRIMSON, WALL_SEAM_DARK),
	}
	_cache["cliff_materials"] = mats
	return mats


## Samples per world unit along a wall of the baked wall shadow.
const WALL_SHADOW_SAMPLES := 8
## Depth range (world units below the wall top edge) encoded in the wall shadow texture.
const WALL_SHADOW_RANGE := 64.0


## Returns a yellow wall material with a baked shadow: wall_shadow holds 3 rows (tile rows of
## the +Z walls of a "tiles" block) of 24 [start, end] depth intervals below the wall top (one
## per 1/8 unit along X); inside the interval the wall is in the shadow, outside it is lit;
## [-1, -1] keeps the sun shadow.
static func make_baked_wall_material(wall_shadow: Array) -> ShaderMaterial:
	var w := WALL_SHADOW_SAMPLES * 3
	var img := Image.create(w, 3, false, Image.FORMAT_RGF)
	for r in 3:
		var row: Variant = wall_shadow[r]
		for x in w:
			var v := Vector2(-1.0, -1.0)
			if row is Array and x < row.size() and row[x] is Array and row[x].size() == 2:
				v = Vector2(BlockSurface._num(row[x][0]), BlockSurface._num(row[x][1]))
			img.set_pixel(x, r, Color(v.x / WALL_SHADOW_RANGE, v.y / WALL_SHADOW_RANGE, 0, 1))
	var mat := _wall_material(WALL_YELLOW, WALL_SEAM_LIT, WALL_ORANGE, WALL_SEAM_DARK)
	mat.set_shader_parameter("wall_shadow", ImageTexture.create_from_image(img))
	mat.set_shader_parameter("has_wall_shadow", true)
	return mat


## Returns a wall shader material with the given stripe and seam colors (0..255 sRGB).
static func _wall_material(stripe_lit: Vector3, seam_lit: Vector3, stripe_shadow: Vector3, seam_shadow: Vector3) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = _shader(WALL_SHADER_PATH)
	mat.set_shader_parameter("stripe_lit", stripe_lit)
	mat.set_shader_parameter("seam_lit", seam_lit)
	mat.set_shader_parameter("stripe_shadow", stripe_shadow)
	mat.set_shader_parameter("seam_shadow", seam_shadow)
	return mat


## Returns a cached shader resource.
static func _shader(path: String) -> Shader:
	if _cache.has(path): return _cache[path]
	var shader := load(path) as Shader
	_cache[path] = shader
	return shader


## Converts an RGBA decal layer into a paint image at PAINT_SIZE: red pixels become the red
## ramp, gray pixels the gray ramp, transparent pixels stay unpainted.
static func _paint_from_layer(layer: Image) -> Image:
	var small := layer.duplicate() as Image
	small.resize(PAINT_SIZE, PAINT_SIZE, Image.INTERPOLATE_NEAREST)
	var img := Image.create(PAINT_SIZE, PAINT_SIZE, false, Image.FORMAT_RGBA8)
	for y in PAINT_SIZE:
		for x in PAINT_SIZE:
			var c := small.get_pixel(x, y)
			if c.a < 0.5: continue
			var ramp := 1 if c.r > c.g + 0.2 else 0
			img.set_pixel(x, y, Color(ramp / 3.0, 0, 0, 0.5))
	return img


## Rotates a decal layer counter-clockwise by decal_rotation degrees (JS canvas rotate(-angle)).
static func _rotate_layer(layer: Image, decal_rotation: int) -> void:
	var quarter_turns := posmod(roundi(decal_rotation / 90.0), 4)
	if quarter_turns == 1: layer.rotate_90(COUNTERCLOCKWISE)
	elif quarter_turns == 2: layer.rotate_180()
	elif quarter_turns == 3: layer.rotate_90(CLOCKWISE)


## Returns the cached double sided checkered flag material.
static func flag_material() -> StandardMaterial3D:
	if _cache.has("flag_mat"): return _cache["flag_mat"]
	var img := Image.create(FLAG_W, FLAG_H, false, Image.FORMAT_RGBA8)
	var cw := FLAG_W / FLAG_COLS
	var ch := FLAG_H / FLAG_ROWS
	for r in FLAG_ROWS:
		for c in FLAG_COLS:
			var col := Color("#f59f18") if (r + c) % 2 == 0 else Color("#181818")
			_fill_rect(img, c * cw, r * ch, cw, ch, col)
	var mat := _make_material(img, false)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_cache["flag_mat"] = mat
	return mat


## Builds an unlit, nearest filtered material from an image.
static func _make_material(img: Image, repeat: bool) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.texture_repeat = repeat
	return mat


## Draws one unrotated decal onto a transparent layer.
static func _draw_decal(layer: Image, decal: String) -> void:
	var size := BASE_SIZE
	var cx := size / 2
	match decal:
		"arrow_wide_diag":
			# Arrow pointing down in local space, rotated -45 degrees around the center.
			var angle := -PI / 4.0
			var c := Vector2(cx, cx)
			_fill_rect_xf(layer, Rect2(-15, -80, 30, 8), c, angle, RED)
			_fill_rect_xf(layer, Rect2(-19, -65, 38, 10), c, angle, RED)
			_fill_rect_xf(layer, Rect2(-22, -48, 44, 58), c, angle, RED)
			_fill_poly(layer, _xf([Vector2(-52, 8), Vector2(52, 8), Vector2(0, 74)], c, angle), RED)
		"arrow_wide_ortho":
			_fill_rect(layer, cx - 15, 14, 30, 9, RED)
			_fill_rect(layer, cx - 19, 29, 38, 11, RED)
			_fill_rect(layer, cx - 22, 46, 44, 64, RED)
			_fill_poly(layer, [Vector2(cx - 52, 108), Vector2(cx + 52, 108), Vector2(cx, 176)], RED)
		"arrow_long_chevrons":
			_fill_rect(layer, cx - 11, 0, 22, 82, RED)
			_fill_poly(layer, [Vector2(cx - 30, 78), Vector2(cx + 30, 78), Vector2(cx, 114)], RED)
			_chevron(layer, cx, 122, 18, 16)
			_chevron(layer, cx, 144, 15, 15)
			_chevron(layer, cx, 165, 12, 14)
		"arrow_shaft_only":
			_fill_rect(layer, cx - 11, 0, 22, size, RED)
		"goal_banner":
			_fill_rect(layer, 4, 34, size - 8, 10, Color("#555555"))
			_fill_rect(layer, 4, size - 44, size - 8, 10, Color("#555555"))
			_draw_text(layer, "GOAL", Vector2(cx, cx + 2), 6, 6, Color("#363636"))
		"pad_456":
			_draw_pad_456(layer)


## Draws a downward pointing triangle (chevron) centered on cx.
static func _chevron(layer: Image, cx: int, top: int, half_w: int, h: int) -> void:
	_fill_poly(layer, [Vector2(cx - half_w, top), Vector2(cx + half_w, top), Vector2(cx, top + h)], RED)


## Draws the 3x2 red numbered tiles plus the arrow below them.
static func _draw_pad_456(layer: Image) -> void:
	var t := BASE_SIZE / TILE_COUNT
	var labels := [[0, 0, "4"], [1, 0, "5"], [0, 1, "5"], [1, 1, "6"], [2, 0, "4"], [2, 1, "6"]]
	for item in labels:
		var x: int = item[0] * t
		var y: int = item[1] * t
		_fill_rect(layer, x + 3, y + 3, t - 6, t - 6, RED_BRIGHT)
		_stroke_rect(layer, x + 5, y + 5, t - 10, t - 10, 2, Color("#ffece8"))
		_draw_text(layer, item[2], Vector2(x + t / 2.0, y + t / 2.0 + 1), 3, 0, Color.WHITE)
	var mid := t * 1.5
	_fill_rect(layer, int(mid - 8), t * 2 + 2, 16, 28, RED_BRIGHT)
	_fill_poly(layer, [Vector2(mid - 24, t * 2 + 26), Vector2(mid + 24, t * 2 + 26), Vector2(mid, BASE_SIZE - 6)], RED_BRIGHT)


## Draws text from the 5x7 glyph table, centered on `center`. scale is pixels per glyph pixel.
static func _draw_text(img: Image, text: String, center: Vector2, scale: int, gap: int, col: Color) -> void:
	var count := text.length()
	var total_w := count * GLYPH_W * scale + (count - 1) * gap
	var x0 := int(center.x - total_w / 2.0)
	var y0 := int(center.y - GLYPH_H * scale / 2.0)
	for i in count:
		var rows: Array = GLYPHS[text[i]]
		var gx := x0 + i * (GLYPH_W * scale + gap)
		for gy in GLYPH_H:
			for px in GLYPH_W:
				if rows[gy][px] == "#": _fill_rect(img, gx + px * scale, y0 + gy * scale, scale, scale, col)


## Fills an axis aligned rect (clipped to the image, no blending).
static func _fill_rect(img: Image, x: int, y: int, w: int, h: int, col: Color) -> void:
	var clipped := Rect2i(x, y, w, h).intersection(Rect2i(0, 0, img.get_width(), img.get_height()))
	if clipped.size.x <= 0 or clipped.size.y <= 0: return
	img.fill_rect(clipped, col)


## Draws a hollow rect border of the given thickness inside (x, y, w, h).
static func _stroke_rect(img: Image, x: int, y: int, w: int, h: int, thick: int, col: Color) -> void:
	_fill_rect(img, x, y, w, thick, col)
	_fill_rect(img, x, y + h - thick, w, thick, col)
	_fill_rect(img, x, y, thick, h, col)
	_fill_rect(img, x + w - thick, y, thick, h, col)


## Rotates points around `center` by `angle` radians (canvas convention, y down).
static func _xf(points: Array, center: Vector2, angle: float) -> Array:
	var out: Array = []
	for p in points: out.append(center + (p as Vector2).rotated(angle))
	return out


## Fills a rect given in local space, rotated around `center`.
static func _fill_rect_xf(img: Image, r: Rect2, center: Vector2, angle: float, col: Color) -> void:
	var corners := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	_fill_poly(img, _xf(corners, center, angle), col)


## Fills a polygon with an even-odd scanline sampled at pixel centers.
static func _fill_poly(img: Image, points: Array, col: Color) -> void:
	var n := points.size()
	if n < 3: return
	var min_y := INF
	var max_y := -INF
	for p in points:
		min_y = minf(min_y, p.y)
		max_y = maxf(max_y, p.y)
	for y in range(maxi(0, floori(min_y)), mini(img.get_height(), ceili(max_y) + 1)):
		var sy := y + 0.5
		var xs: Array[float] = []
		for i in n:
			var a: Vector2 = points[i]
			var b: Vector2 = points[(i + 1) % n]
			if (a.y <= sy) == (b.y <= sy): continue
			xs.append(a.x + (sy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			var x_from := maxi(0, ceili(xs[k] - 0.5))
			var x_to := mini(img.get_width(), ceili(xs[k + 1] - 0.5))
			if x_to > x_from: img.fill_rect(Rect2i(x_from, y, x_to - x_from, 1), col)
