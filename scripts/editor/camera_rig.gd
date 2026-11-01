class_name CameraRig
extends Node3D
## Editor camera rig: an orthographic arcade camera and a perspective camera that
## orbit around a focus point. Port of the camera setup and OrbitControls use in
## js/main.js. Right drag orbits, middle drag pans, wheel zooms.

## Camera projection modes.
enum Mode { ORTHO, PERSP }

## Ortho frustum height at reset (js orthoFrustum).
const ORTHO_SIZE := 34.0
## Smallest and largest ortho frustum height.
const ORTHO_SIZE_MIN := 4.0
const ORTHO_SIZE_MAX := 200.0
## Distance of the ortho camera from the focus along its axis.
const ORTHO_BACKOFF := 200.0
## Ortho clip planes: cover 199 units in front of and 400 behind the focus.
const ORTHO_NEAR := 1.0
const ORTHO_FAR := 600.0
## Perspective camera settings (js PerspectiveCamera(42, aspect, 0.5, 400)).
const PERSP_FOV := 42.0
const PERSP_NEAR := 0.5
const PERSP_FAR := 400.0
## Perspective orbit distance bounds.
const DISTANCE_MIN := 5.0
const DISTANCE_MAX := 250.0
## Reset view: offset (52, 52 * 0.96, 52) from the focus, as in setArcadeIsometricView.
const RESET_OFFSET := Vector3(52.0, 49.92, 52.0)
const RESET_YAW := PI / 4.0
## Pitch limits in radians above the horizon (js maxPolarAngle = 0.49 PI).
const PITCH_MIN := PI * 0.01
const PITCH_MAX := PI * 0.49
## Input sensitivities.
const ORBIT_SPEED := 0.005
const ZOOM_STEP := 0.9
## Viewport height used for pan scaling when the rig is outside the tree.
const FALLBACK_VIEW_HEIGHT := 720.0

## Active projection mode.
var mode: Mode = Mode.ORTHO
## Point the camera orbits around (moved by panning).
var focus := Vector3.ZERO
## Focus set by focus_on; reset_arcade_view returns to it.
var home_focus := Vector3.ZERO

var _yaw := RESET_YAW
var _pitch := 0.0
var _distance := 0.0
var _ortho_size := ORTHO_SIZE
var _ortho_camera := Camera3D.new()
var _persp_camera := Camera3D.new()


## Builds both cameras and applies the arcade view.
func _init() -> void:
	_ortho_camera.name = "OrthoCamera"
	_ortho_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	_ortho_camera.near = ORTHO_NEAR
	_ortho_camera.far = ORTHO_FAR
	_persp_camera.name = "PerspCamera"
	_persp_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_persp_camera.fov = PERSP_FOV
	_persp_camera.near = PERSP_NEAR
	_persp_camera.far = PERSP_FAR
	add_child(_ortho_camera)
	add_child(_persp_camera)
	reset_arcade_view()


## Makes the camera of the current mode current once the rig is in the tree.
func _ready() -> void:
	_apply_mode()


## Handles orbit (right drag), pan (middle drag) and zoom (wheel) over the 3D view.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT: orbit(event.relative)
		elif event.button_mask & MOUSE_BUTTON_MASK_MIDDLE: pan(event.relative)
		return
	if not (event is InputEventMouseButton and event.pressed): return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP: zoom(1.0)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN: zoom(-1.0)


## Switches between the ortho and perspective cameras.
func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	_apply_mode()


## Returns the camera of the active mode.
func current_camera() -> Camera3D:
	return _ortho_camera if mode == Mode.ORTHO else _persp_camera


## Moves the focus point (and the reset focus); the view keeps its angles and zoom.
func focus_on(center: Vector3) -> void:
	focus = center
	home_focus = center
	_update_cameras()


## Restores the arcade isometric view around the focus set by focus_on.
func reset_arcade_view() -> void:
	focus = home_focus
	_yaw = RESET_YAW
	_pitch = atan2(RESET_OFFSET.y, Vector2(RESET_OFFSET.x, RESET_OFFSET.z).length())
	_distance = RESET_OFFSET.length()
	_ortho_size = ORTHO_SIZE
	_update_cameras()


## Orbits by a mouse delta in pixels; pitch is clamped to avoid flipping.
func orbit(delta: Vector2) -> void:
	_yaw -= delta.x * ORBIT_SPEED
	_pitch = clampf(_pitch + delta.y * ORBIT_SPEED, PITCH_MIN, PITCH_MAX)
	_update_cameras()


## Pans the focus in the camera plane by a mouse delta in pixels.
func pan(delta: Vector2) -> void:
	var cam := current_camera()
	var world_height := _ortho_size if mode == Mode.ORTHO else 2.0 * _distance * tan(deg_to_rad(PERSP_FOV) / 2.0)
	var units_per_pixel := world_height / _view_height()
	focus += (-cam.transform.basis.x * delta.x + cam.transform.basis.y * delta.y) * units_per_pixel
	_update_cameras()


## Zooms by wheel steps: positive zooms in. Ortho size or perspective distance, clamped.
func zoom(steps: float) -> void:
	var factor := pow(ZOOM_STEP, steps)
	if mode == Mode.ORTHO: _ortho_size = clampf(_ortho_size * factor, ORTHO_SIZE_MIN, ORTHO_SIZE_MAX)
	else: _distance = clampf(_distance * factor, DISTANCE_MIN, DISTANCE_MAX)
	_update_cameras()


## Returns a world ray {"origin", "dir"} through a screen position of the active camera.
func ray_from_screen(pos: Vector2) -> Dictionary:
	var cam := current_camera()
	return {"origin": cam.project_ray_origin(pos), "dir": cam.project_ray_normal(pos).normalized()}


## Returns the viewport height in pixels, or a fallback outside the tree.
func _view_height() -> float:
	if not is_inside_tree(): return FALLBACK_VIEW_HEIGHT
	return maxf(get_viewport().get_visible_rect().size.y, 1.0)


## Makes the camera of the current mode current; deferred until the rig is in the tree.
func _apply_mode() -> void:
	if not is_inside_tree(): return
	current_camera().make_current()


## Positions and orients both cameras from yaw, pitch, distance and focus.
func _update_cameras() -> void:
	var dir := Vector3(cos(_pitch) * sin(_yaw), sin(_pitch), cos(_pitch) * cos(_yaw))
	_place(_ortho_camera, focus + dir * ORTHO_BACKOFF)
	_place(_persp_camera, focus + dir * _distance)
	_ortho_camera.size = _ortho_size


## Sets a camera position and makes it look at the focus.
func _place(cam: Camera3D, pos: Vector3) -> void:
	cam.transform = Transform3D(Basis.looking_at(focus - pos, Vector3.UP), pos)
