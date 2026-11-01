extends TestCase
## Tests for CameraRig.


## Adds a rig to the scene tree and waits a frame, because the root only joins the tree after startup.
func _make_rig() -> CameraRig:
	var rig := CameraRig.new()
	tree.root.add_child(rig)
	await tree.process_frame
	return rig


## The ortho camera is the default and uses orthogonal projection.
func test_ortho_is_default_and_orthogonal_projection() -> void:
	var rig := await _make_rig()
	var cam := rig.current_camera()
	assert_eq(rig.mode, CameraRig.Mode.ORTHO, "default mode")
	assert_eq(cam.projection, Camera3D.PROJECTION_ORTHOGONAL, "orthogonal")
	assert_near(cam.size, 34.0, 0.0001, "ortho size")
	assert_true(cam.current, "ortho camera is current")
	rig.free()


## set_mode switches the current camera and its projection.
func test_set_mode_switches_projection() -> void:
	var rig := await _make_rig()
	rig.set_mode(CameraRig.Mode.PERSP)
	var cam := rig.current_camera()
	assert_eq(cam.projection, Camera3D.PROJECTION_PERSPECTIVE, "perspective")
	assert_near(cam.fov, 42.0, 0.0001, "fov")
	assert_true(cam.current, "persp camera is current")
	rig.set_mode(CameraRig.Mode.ORTHO)
	assert_eq(rig.current_camera().projection, Camera3D.PROJECTION_ORTHOGONAL, "back to ortho")
	rig.free()


## set_mode before entering the tree applies once the rig is ready.
func test_set_mode_before_tree() -> void:
	var rig := CameraRig.new()
	rig.set_mode(CameraRig.Mode.PERSP)
	tree.root.add_child(rig)
	await tree.process_frame
	assert_true(rig.current_camera().current, "persp current after entering tree")
	assert_eq(rig.current_camera().projection, Camera3D.PROJECTION_PERSPECTIVE, "perspective")
	rig.free()


## Orbit, pan and zoom followed by reset gives back the initial transform.
func test_reset_arcade_view_restores_transform() -> void:
	var rig := await _make_rig()
	var initial := rig.current_camera().transform
	var initial_size := rig.current_camera().size
	rig.orbit(Vector2(120, -40))
	rig.pan(Vector2(30, 20))
	rig.zoom(3.0)
	assert_true(not rig.current_camera().transform.is_equal_approx(initial), "view changed")
	rig.reset_arcade_view()
	assert_true(rig.current_camera().transform.is_equal_approx(initial), "transform restored")
	assert_near(rig.current_camera().size, initial_size, 0.0001, "size restored")
	rig.free()


## Reset orbits around the focus point.
func test_focus_on_sets_look_target() -> void:
	var rig := await _make_rig()
	rig.focus_on(Vector3(20, 0, 20))
	var cam := rig.current_camera()
	var forward := -cam.global_transform.basis.z
	var to_focus := (Vector3(20, 0, 20) - cam.global_position).normalized()
	assert_true(forward.dot(to_focus) > 0.9999, "camera looks at focus")
	rig.free()


## The default view looks from +X, +Z downwards like the JS source.
func test_default_view_direction() -> void:
	var rig := await _make_rig()
	var pos := rig.current_camera().global_position
	assert_true(pos.x > 0.0 and pos.z > 0.0 and pos.y > 0.0, "camera at +X +Y +Z")
	assert_near(pos.x, pos.z, 0.0001, "yaw 45 degrees")
	rig.free()


## Pitch is clamped so the camera never flips over the top or under the ground.
func test_pitch_clamped() -> void:
	var rig := await _make_rig()
	rig.orbit(Vector2(0, 100000))
	var up := rig.current_camera().global_transform.basis.y
	assert_true(up.y > 0.0, "camera up stays up (high)")
	rig.orbit(Vector2(0, -100000))
	assert_true(rig.current_camera().global_position.y > 0.0, "camera stays above ground")
	rig.free()


## Zoom changes ortho size in ORTHO and distance in PERSP, within bounds.
func test_zoom_bounds() -> void:
	var rig := await _make_rig()
	var before := rig.current_camera().size
	rig.zoom(1.0)
	assert_true(rig.current_camera().size < before, "zoom in shrinks ortho size")
	rig.zoom(1000.0)
	assert_true(rig.current_camera().size > 0.0, "ortho size stays positive")
	rig.set_mode(CameraRig.Mode.PERSP)
	var dist_before := rig.current_camera().global_position.length()
	rig.zoom(-1.0)
	assert_true(rig.current_camera().global_position.length() > dist_before, "zoom out increases distance")
	rig.free()


## Screen rays come back with a normalized direction.
func test_ray_dir_normalized() -> void:
	var rig := await _make_rig()
	for mode in [CameraRig.Mode.ORTHO, CameraRig.Mode.PERSP]:
		rig.set_mode(mode)
		var ray := rig.ray_from_screen(Vector2(10, 10))
		assert_near(ray["dir"].length(), 1.0, 0.0001, "dir normalized")
		assert_true(ray.has("origin"), "has origin")
	rig.free()
