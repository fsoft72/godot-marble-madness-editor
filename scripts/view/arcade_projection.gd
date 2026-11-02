class_name ArcadeProjection
extends RefCounted
## The 2:1 isometric projection of the arcade reference image (assets/level01_ref.png).
## One tile (1 world unit) is a 16x8 logical pixel diamond: the camera looks down at
## 30 degrees (sin 30 = 0.5) with a 45 degree yaw. World +X goes right-down on screen,
## world +Z goes left-down, world +Y goes up.

## Camera pitch above the horizon: asin(0.5), the exact 2:1 ratio.
const PITCH := PI / 6.0
## Camera yaw: looks along (-1, -, -1).
const YAW := PI / 4.0
## Width in logical pixels of one tile diamond.
const TILE_PX_W := 16.0
## Logical pixels per world unit in the screen plane (TILE_PX_W / sqrt(2)).
const PX_PER_UNIT := TILE_PX_W / 1.4142135623730951
## Distance of the camera from the focus.
const BACKOFF := 300.0
## Level point at the screen center of the reference image (fitted, see tools/compare_ref.py).
const REFERENCE_FOCUS := Vector3(21.0, 0.0, 21.0)


## Unit direction from the focus to the camera.
static func view_dir() -> Vector3:
	return Vector3(cos(PITCH) * sin(YAW), sin(PITCH), cos(PITCH) * cos(YAW))


## Sets an orthographic camera to the arcade projection for a viewport of `view_height_px`
## logical pixels, looking at `focus` shifted by `screen_shift` world units along the
## camera right and up axes.
static func apply(cam: Camera3D, view_height_px: float, screen_shift: Vector2 = Vector2.ZERO, focus: Vector3 = REFERENCE_FOCUS) -> void:
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.keep_aspect = Camera3D.KEEP_HEIGHT
	cam.size = view_height_px / PX_PER_UNIT
	cam.near = 1.0
	cam.far = BACKOFF * 2.0
	var basis := Basis.looking_at(-view_dir(), Vector3.UP)
	var center := focus + basis.x * screen_shift.x + basis.y * screen_shift.y
	cam.transform = Transform3D(basis, center + view_dir() * BACKOFF)


## Projects a world point to logical screen pixels relative to the projection of `focus`
## (x right, y down).
static func to_screen(p: Vector3, focus: Vector3 = REFERENCE_FOCUS) -> Vector2:
	var d := p - focus
	return Vector2((d.x - d.z) * TILE_PX_W * 0.5, (d.x + d.z) * TILE_PX_W * 0.25 - d.y * PX_PER_UNIT * cos(PITCH))
