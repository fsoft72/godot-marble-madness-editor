"""Python rasterizer of the top surface shader (shaders/arcade_top.gdshader) in the arcade
projection, used to fit vertex heights to the reference by analysis by synthesis.

A tile is (k, m, level0, level1, split) with screen corners from lattice vertices:
top (k, m), right (k + 1, m + 1), left (k - 1, m + 1), bottom (k, m + 2).
"""
import numpy as np

PATTERN = np.array([[int(ch) for ch in row] for row in [
    "2222222222222222", "2212221222122222", "2111201120112122", "2111000100010112",
    "2210000000000012", "2200000000000022", "2100000000000122", "2110000000000112",
    "2210000000000012", "2200000000000022", "2100000000000122", "2110000000000112",
    "2210000000000012", "2210001000100022", "2211021102110222", "2221222122212222",
]])
PSIZE = 16


def tile_triangles(split):
    """Returns the two triangles as corner index triples into (top, right, left, bottom) and
    the uv of each corner index; first triangle gets level0."""
    uv = np.array([[0, 0], [1, 0], [0, 1], [1, 1]], float)  # top=00, right=10, left=01, bottom=11
    if split == 'anti':
        return [(0, 2, 1), (1, 2, 3)], uv
    return [(0, 2, 3), (0, 3, 1)], uv


def raster_tile(corners_xy, levels, split, texels=False):
    """Rasterizes one tile. corners_xy: 4x2 screen points (top, right, left, bottom).
    Returns (ys, xs, level per pixel) for the pixel centers covered (front facing only),
    plus the texel column and row (0..15) of each pixel when texels is True."""
    tris, uv = tile_triangles(split)
    out_y, out_x, out_l, out_tx, out_ty = [], [], [], [], []
    for ti, tri in enumerate(tris):
        p = corners_xy[list(tri)]
        x0 = int(np.floor(p[:, 0].min())); x1 = int(np.ceil(p[:, 0].max()))
        y0 = int(np.floor(p[:, 1].min())); y1 = int(np.ceil(p[:, 1].max()))
        if x1 <= x0 or y1 <= y0: continue
        gx, gy = np.meshgrid(np.arange(x0, x1) + 0.5, np.arange(y0, y1) + 0.5)
        a, b, c = p
        area = (b[0] - a[0]) * (c[1] - a[1]) - (b[1] - a[1]) * (c[0] - a[0])
        if area >= 0: continue  # back facing or degenerate (screen y down: front is negative)
        w0 = (b[0] - gx) * (c[1] - gy) - (b[1] - gy) * (c[0] - gx)
        w1 = (c[0] - gx) * (a[1] - gy) - (c[1] - gy) * (a[0] - gx)
        w2 = (a[0] - gx) * (b[1] - gy) - (a[1] - gy) * (b[0] - gx)
        inside = (w0 <= 0) & (w1 <= 0) & (w2 <= 0)
        if not inside.any(): continue
        w0, w1, w2 = w0[inside] / area, w1[inside] / area, w2[inside] / area
        t_uv = uv[list(tri)]
        u = w0 * t_uv[0, 0] + w1 * t_uv[1, 0] + w2 * t_uv[2, 0]
        v = w0 * t_uv[0, 1] + w1 * t_uv[1, 1] + w2 * t_uv[2, 1]
        tx = np.clip(np.floor(u * PSIZE).astype(int), 0, PSIZE - 1)
        ty = np.clip(np.floor(v * PSIZE).astype(int), 0, PSIZE - 1)
        lev = np.clip(levels[ti] - PATTERN[ty, tx], 0, 5)
        out_y.append(np.floor(gy[inside]).astype(int))
        out_x.append(np.floor(gx[inside]).astype(int))
        out_l.append(lev)
        out_tx.append(tx)
        out_ty.append(ty)
    if not out_y:
        empty = np.zeros(0, int)
        return (empty, empty, empty, empty, empty) if texels else (empty, empty, empty)
    res = (np.concatenate(out_y), np.concatenate(out_x), np.concatenate(out_l))
    if texels: res += (np.concatenate(out_tx), np.concatenate(out_ty))
    return res


def corners_of(k, m, sy_of):
    """Returns the 4x2 screen corners (top, right, left, bottom) of tile (k, m);
    sy_of(kv, mv) gives the screen row of a vertex."""
    return np.array([
        [8.0 * k, sy_of(k, m)],
        [8.0 * (k + 1), sy_of(k + 1, m + 1)],
        [8.0 * (k - 1), sy_of(k - 1, m + 1)],
        [8.0 * k, sy_of(k, m + 2)],
    ])
