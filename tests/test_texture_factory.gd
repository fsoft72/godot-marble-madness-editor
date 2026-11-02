extends TestCase
## Tests for TextureFactory (procedural materials).

const BASE_TILE_SIZE := 192


## Clears the cache so tests do not influence each other.
func _clear() -> void:
	TextureFactory.clear_cache()


## Same arguments give the very same cached material instance.
func test_same_args_return_cached_instance() -> void:
	_clear()
	var a := TextureFactory.top_surface_material("pad_456", 90)
	var b := TextureFactory.top_surface_material("pad_456", 90)
	assert_true(a == b, "cached instance")
	assert_eq(a.shader.resource_path, TextureFactory.TOP_SHADER_PATH, "arcade top shader")


## Different decals (or rotations) give different materials.
func test_different_decal_different_material() -> void:
	_clear()
	var a := TextureFactory.top_surface_material("arrow_wide_ortho", 0)
	var b := TextureFactory.top_surface_material("goal_banner", 0)
	var c := TextureFactory.top_surface_material("arrow_wide_ortho", 90)
	assert_true(a != b, "different decal")
	assert_true(a != c, "different rotation")


## An unknown decal behaves like "none" and shares its cached material.
func test_unknown_decal_falls_back_to_none() -> void:
	_clear()
	var none_mat := TextureFactory.top_surface_material("none", 0)
	var unknown := TextureFactory.top_surface_material("does_not_exist", 0)
	assert_true(none_mat == unknown, "same cached material")


## The tile pattern has 16x16 texels with offsets 0..2 and a line (2) at the tile corner.
func test_tile_pattern() -> void:
	_clear()
	var img: Image = TextureFactory.tile_pattern_texture().get_image()
	assert_eq(img.get_width(), TextureFactory.TILE_PATTERN_SIZE, "width")
	assert_near(img.get_pixel(0, 0).r * 3.0, 2.0, 0.01, "line at the corner")
	assert_near(img.get_pixel(8, 8).r * 3.0, 0.0, 0.01, "fill in the middle")


## Rotating a decal by 90 degrees moves the red paint of an asymmetric decal.
func test_decal_rotation_changes_paint() -> void:
	_clear()
	var img0: Image = (TextureFactory.top_surface_material("arrow_long_chevrons", 0).get_shader_parameter("paint") as Texture2D).get_image()
	var img90: Image = (TextureFactory.top_surface_material("arrow_long_chevrons", 90).get_shader_parameter("paint") as Texture2D).get_image()
	# The shaft runs along the vertical center at rotation 0 and the horizontal center at 90.
	assert_true(img0.get_pixel(24, 5).a > 0.25 and img0.get_pixel(24, 5).r > 0.3, "red shaft at rotation 0")
	assert_true(img90.get_pixel(5, 24).a > 0.25 and img90.get_pixel(5, 24).r > 0.3, "red shaft at rotation 90")
	assert_true(img90.get_pixel(24, 5).a < 0.25, "no shaft at the old position")


## paint_image reads decal ramps ("0".."3") and absolute codes ("A".."L").
func test_paint_image_codes() -> void:
	var img := TextureFactory.paint_image([".1F", "L.."])
	assert_eq(img.get_width(), 3, "width")
	assert_true(img.get_pixel(0, 0).a < 0.25, "unpainted")
	assert_near(img.get_pixel(1, 0).a, 0.5, 0.01, "decal texel")
	assert_near(img.get_pixel(2, 0).g * 5.0, 5.0, 0.01, "F = gray level 5")
	assert_near(img.get_pixel(0, 1).r * 3.0, 1.0, 0.01, "L = red ramp")
	assert_near(img.get_pixel(0, 1).g * 5.0, 5.0, 0.01, "L = level 5")


## Cliff materials expose wall, trim and wall_right, cached; trim looks like the wall.
func test_cliff_materials_keys_and_cache() -> void:
	_clear()
	var m := TextureFactory.cliff_materials()
	assert_true(m.has("wall") and m.has("trim") and m.has("wall_right"), "keys")
	assert_true(m == TextureFactory.cliff_materials(), "cached dictionary")
	assert_true(m["trim"] == m["wall"], "trim drawn like the wall")
	assert_eq(m["wall_right"].get_shader_parameter("stripe_lit"), TextureFactory.WALL_CRIMSON, "crimson")


## Flag material is a cached double sided 64x48 texture.
func test_flag_material() -> void:
	_clear()
	var f := TextureFactory.flag_material()
	assert_true(f == TextureFactory.flag_material(), "cached")
	assert_eq(f.cull_mode, BaseMaterial3D.CULL_DISABLED, "double sided")
	assert_eq(f.albedo_texture.get_width(), 64, "width")
	assert_eq(f.albedo_texture.get_height(), 48, "height")

