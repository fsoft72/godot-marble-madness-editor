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
	assert_true(a.vertex_color_use_as_albedo, "vertex colors enabled")
	assert_eq(a.texture_filter, BaseMaterial3D.TEXTURE_FILTER_NEAREST, "nearest filter")


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


## The base tile texture is 192x192.
func test_base_tile_texture_size_192() -> void:
	_clear()
	var tex := TextureFactory.top_surface_material("none", 0).albedo_texture
	assert_eq(tex.get_width(), BASE_TILE_SIZE, "width")
	assert_eq(tex.get_height(), BASE_TILE_SIZE, "height")


## Rotating a decal by 90 degrees changes the pixels of an asymmetric decal.
func test_decal_rotation_changes_texture() -> void:
	_clear()
	var img0 := TextureFactory.top_surface_material("arrow_long_chevrons", 0).albedo_texture.get_image()
	var img90 := TextureFactory.top_surface_material("arrow_long_chevrons", 90).albedo_texture.get_image()
	# Shaft runs along the vertical center at rotation 0 and the horizontal center at 90.
	var red0 := img0.get_pixel(96, 20)
	var red90 := img90.get_pixel(20, 96)
	assert_true(red0.r > 0.7 and red0.g < 0.3, "red shaft at rotation 0")
	assert_true(red90.r > 0.7 and red90.g < 0.3, "red shaft at rotation 90")
	assert_true(img90.get_pixel(96, 20).g > 0.5, "no shaft at old position")


## Cliff materials expose wall and trim, cached and repeating.
func test_cliff_materials_keys_and_cache() -> void:
	_clear()
	var m := TextureFactory.cliff_materials()
	assert_true(m.has("wall") and m.has("trim"), "keys")
	assert_true(m == TextureFactory.cliff_materials(), "cached dictionary")
	assert_eq(m["wall"].albedo_texture.get_width(), 96, "stripe width")
	assert_eq(m["wall"].albedo_texture.get_height(), 64, "stripe height")


## Flag material is a cached double sided 64x48 texture.
func test_flag_material() -> void:
	_clear()
	var f := TextureFactory.flag_material()
	assert_true(f == TextureFactory.flag_material(), "cached")
	assert_eq(f.cull_mode, BaseMaterial3D.CULL_DISABLED, "double sided")
	assert_eq(f.albedo_texture.get_width(), 64, "width")
	assert_eq(f.albedo_texture.get_height(), 48, "height")
