class_name BlockSurface
extends RefCounted
## Block surface height (port of rotateUV and getBlockSurfaceY from js/geometry.js).
## Local block coordinates (u, v) are in [0..3] x [0..3].

const ROTATION_FULL := 360.0


## Rotates local (u, v) around the block center (1.5, 1.5).
## Only multiples of 90 (after wrapping into [0, 360)) rotate; anything else is identity.
## rotation is a float so that integer and JSON float rotations behave the same.
static func rotate_uv(u: float, v: float, rotation: float = 0.0) -> Vector2:
	var rot := fposmod(rotation, ROTATION_FULL)
	if rot == 90.0: return Vector2(3.0 - v, u)
	if rot == 180.0: return Vector2(3.0 - u, 3.0 - v)
	if rot == 270.0: return Vector2(v, 3.0 - u)
	return Vector2(u, v)


## Returns the world Y at local (u, v) of a block dictionary.
## Priority: vGrid (4x4 offsets), corners [c00, c10, c01, c11], then parametric shapes.
## Missing fields follow the JS defaults (elevation, slope, tilt, rotation = 0; shape = flat).
static func surface_y(block: Dictionary, u: float, v: float) -> float:
	var elev := _num(block.get("elevation"))
	var slope := _num(block.get("slope"))
	var tilt := _num(block.get("tilt"))
	var rot := _num(block.get("rotation"))
	var shape: String = str(block.get("shape", ""))
	if shape == "": shape = "flat"
	var v_grid: Variant = block.get("vGrid")
	if v_grid is Array and v_grid.size() == 4:
		return _grid_y(elev, v_grid, str(block.get("diagSplit", "")), u, v)
	var corners: Variant = block.get("corners")
	if corners is Array and corners.size() == 4:
		return _corners_y(elev, corners, str(block.get("diagSplit", "")), u, v)
	var ruv := rotate_uv(u, v, rot)
	var du := (ruv.x - 1.5) / 3.0
	var dv := (ruv.y - 1.5) / 3.0
	var nu := ruv.x / 3.0
	var nv := ruv.y / 3.0
	match shape:
		"fold_right":
			return elev + _anti_split(-slope * 0.5, -slope * 0.25 + tilt * 0.4, 0.0, slope * 0.5, nu, nv)
		"fold_left":
			return elev + _anti_split(-slope * 0.5, 0.0, -slope * 0.25 + tilt * 0.4, slope * 0.5, nu, nv)
		"chute_funnel":
			return elev + _main_split(0.0, 0.0, slope * 0.5, slope, nu, nv)
	return elev + dv * slope + du * tilt


## Mirrors JS Number(x ?? 0): null/missing is 0, numbers pass, numeric strings convert.
static func _num(value: Variant) -> float:
	if value == null: return 0.0
	if value is float or value is int: return float(value)
	if value is String: return (value as String).to_float()
	return 0.0


## Height inside the vGrid sub-tile that contains (u, v).
static func _grid_y(elev: float, grid: Array, diag_split: String, u: float, v: float) -> float:
	var c := clampi(floori(2.0 if u == 3.0 else u), 0, 2)
	var r := clampi(floori(2.0 if v == 3.0 else v), 0, 2)
	var fu := clampf(u - c, 0.0, 1.0)
	var fv := clampf(v - r, 0.0, 1.0)
	var h00: float = grid[r][c]
	var h10: float = grid[r][c + 1]
	var h01: float = grid[r + 1][c]
	var h11: float = grid[r + 1][c + 1]
	if diag_split == "main":
		if fu >= fv: return elev + h00 * (1.0 - fu) + h10 * (fu - fv) + h11 * fv
		return elev + h00 * (1.0 - fv) + h01 * (fv - fu) + h11 * fu
	if fu + fv <= 1.0: return elev + h00 + (h10 - h00) * fu + (h01 - h00) * fv
	return elev + h11 + (h01 - h11) * (1.0 - fu) + (h10 - h11) * (1.0 - fv)


## Height from explicit corner offsets [c00, c10, c01, c11] (anti split only when requested).
static func _corners_y(elev: float, corners: Array, diag_split: String, u: float, v: float) -> float:
	var nu := u / 3.0
	var nv := v / 3.0
	if diag_split == "anti":
		return elev + _anti_split(corners[0], corners[1], corners[2], corners[3], nu, nv)
	return elev + _main_split(corners[0], corners[1], corners[2], corners[3], nu, nv)


## Interpolation split along the anti-diagonal (nu + nv = 1), offsets without elevation.
static func _anti_split(c00: float, c10: float, c01: float, c11: float, nu: float, nv: float) -> float:
	if nu + nv <= 1.0: return c00 + (c10 - c00) * nu + (c01 - c00) * nv
	return c11 + (c01 - c11) * (1.0 - nu) + (c10 - c11) * (1.0 - nv)


## Interpolation split along the main diagonal (nu = nv), offsets without elevation.
static func _main_split(c00: float, c10: float, c01: float, c11: float, nu: float, nv: float) -> float:
	if nu >= nv: return c00 * (1.0 - nu) + c10 * (nu - nv) + c11 * nv
	return c00 * (1.0 - nv) + c01 * (nv - nu) + c11 * nu
