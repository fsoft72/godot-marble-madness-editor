"""Class level z-buffer renderer (tops and front walls) of reconstructed tiles, used to pick
component offsets: tops render class TOP, +X walls WALL_X, +Z walls WALL_Z.

A tile is given by its screen corners (top, right, left, bottom) and its lattice depth m;
the depth of a screen point is HS * (x + z) / 4 ... expressed with the screen row:
depth = (4 * m_point + sy_point ...) - see point_depth().
"""
import numpy as np

from vertices import HS

TOP, WALL_X, WALL_Z = 1, 2, 3
H, W = 590, 288
BOTTOM_ROW = 2000.0


def point_depth(mv, y):
    """Depth toward the camera of a world point with lattice depth mv = x + z and height y
    (camera direction (cos30 sin45, sin30, cos30 cos45))."""
    return 0.6123724 * mv + 0.5 * y


def _raster_tri(p, d, zbuf, cls, value, owner=None, oid=0):
    """Rasterizes a screen triangle p (3x2) with per vertex depth d into zbuf/cls."""
    x0 = max(int(np.floor(p[:, 0].min())), 0); x1 = min(int(np.ceil(p[:, 0].max())), W)
    y0 = max(int(np.floor(p[:, 1].min())), 0); y1 = min(int(np.ceil(p[:, 1].max())), H)
    if x1 <= x0 or y1 <= y0: return
    gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
    a, b, c = p
    area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
    if abs(area) < 1e-9: return
    w0 = ((b[0] - gx) * (c[1] - gy) - (b[1] - gy) * (c[0] - gx)) / area
    w1 = ((c[0] - gx) * (a[1] - gy) - (c[1] - gy) * (a[0] - gx)) / area
    w2 = 1.0 - w0 - w1
    inside = (w0 >= 0) & (w1 >= 0) & (w2 >= 0)
    z = w0 * d[0] + w1 * d[1] + w2 * d[2]
    sub_z = zbuf[y0:y1, x0:x1]
    sub_c = cls[y0:y1, x0:x1]
    win = inside & (z > sub_z)
    sub_z[win] = z[win]
    sub_c[win] = value
    if owner is not None: owner[y0:y1, x0:x1][win] = oid


def render(tiles):
    """tiles: list of (corners 4x2 screen, heights 4, mvs 4, wall_x, wall_z) where corners are
    (top, right, left, bottom), wall_x/wall_z say whether the front right / front left edge
    has a wall. Returns the class image."""
    return render_into(tiles, np.full((H, W), -1e9), np.zeros((H, W), int))[1]


def render_into(tiles, zbuf, cls, owner=None):
    """Renders tiles over existing depth and class buffers (modified in place); returns both.
    owner, when given, receives the index in `tiles` of the front-most tile of each pixel."""
    for oid, (corners, hs, mvs, wall_x, wall_z) in enumerate(tiles):
        d = np.array([point_depth(mv, h) for mv, h in zip(mvs, hs)])
        top, right, left, bottom = range(4)
        for tri in ((top, left, bottom), (top, bottom, right)):
            _raster_tri(corners[list(tri)], d[list(tri)], zbuf, cls, TOP, owner, oid)
        for flag, (i, j), value in ((wall_x, (right, bottom), WALL_X), (wall_z, (left, bottom), WALL_Z)):
            if not flag: continue
            pi, pj = corners[i], corners[j]
            drop = 120.0
            qi = pi + [0, drop * HS]
            qj = pj + [0, drop * HS]
            di = d[i] - 0.5 * drop
            dj = d[j] - 0.5 * drop
            _raster_tri(np.array([pi, pj, qj]), np.array([d[i], d[j], dj]), zbuf, cls, value, owner, oid)
            _raster_tri(np.array([pi, qj, qi]), np.array([d[i], dj, di]), zbuf, cls, value, owner, oid)
    return zbuf, cls
