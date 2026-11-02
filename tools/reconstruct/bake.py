"""Bakes the painted look (tile line pattern on slopes, decals) of every visible tile pixel of
the reference into per block paint maps (TextureFactory.paint_image codes): each pixel is
stored in the texel the top shader samples for that pixel.

Shadows are not baked: pixels that are darker than the lit tile because they are in a shadow
of the reference stay unpainted, so the shadow comes from the sun light at run time."""
from collections import Counter, defaultdict

import numpy as np

from raster import raster_tile, corners_of
from tiles import level_map
from zrender import point_depth
from vertices import height

PAINT = 48
TEX = 16
CODE_BASE = ord('A')
# Palette level of a surface in the shadow (shaders/arcade_top.gdshader shadow_level).
SHADOW_LEVEL = 1


def bake(img, fit_tiles, verts, offsets, sy0, origin):
    """Returns {(bx, bz): list of 48 strings} of the blocks whose paint differs from the
    default tile pattern somewhere."""
    lv, ramp = level_map(img)
    h, w = lv.shape
    owner_depth = np.full((h, w), -1e9)
    owner = {}
    raster = []
    for key, (l0, l1, sp) in fit_tiles.items():
        comp, k, m = key
        if key not in offsets: continue
        off = offsets[key]
        c = corners_of(k, m, lambda kv, mv: verts[(comp, kv, mv)])
        ys, xs, lev, tx, ty = raster_tile(c, (l0, l1), sp, texels=True)
        inb = (ys >= 0) & (ys < h) & (xs >= 0) & (xs < w)
        mvs = [m, m + 1, m + 1, m + 2]
        kvs = [k, k + 1, k - 1, k]
        depth = np.mean([point_depth(mv + off, height(mv + off, verts[(comp, kv, mv)], sy0)) for kv, mv in zip(kvs, mvs)])
        raster.append((key, ys[inb], xs[inb], lev[inb], tx[inb], ty[inb], depth))
    for i, (key, ys, xs, lev, tx, ty, depth) in enumerate(raster):
        front = depth > owner_depth[ys, xs]
        owner_depth[ys[front], xs[front]] = depth
        for y, x in zip(ys[front], xs[front]): owner[(y, x)] = i
    votes = defaultdict(Counter)
    differs = set()
    x0, z0 = origin
    for i, (key, ys, xs, lev, tx, ty, depth) in enumerate(raster):
        comp, k, m = key
        mm = m + offsets[key]
        x = (mm + k) // 2 + x0
        z = (mm - k) // 2 + z0
        bx, bz, c, r = x // 3, z // 3, x % 3, z % 3
        for y, xx, l, a, b in zip(ys, xs, lev, tx, ty):
            if owner.get((y, xx)) != i: continue
            if lv[y, xx] < 0: continue
            if lv[y, xx] <= SHADOW_LEVEL and l > lv[y, xx]: continue
            code = CODE_BASE + ramp[y, xx] * 6 + lv[y, xx]
            votes[(bx, bz)][(r * TEX + b, c * TEX + a, code)] += 1
            if lv[y, xx] != l or ramp[y, xx] != 0: differs.add((bx, bz))
    out = {}
    for blk in differs:
        grid = [['.'] * PAINT for _ in range(PAINT)]
        best = {}
        for (row, col, code), n in votes[blk].items():
            if n > best.get((row, col), (0, 0))[0]: best[(row, col)] = (n, code)
        for (row, col), (n, code) in best.items(): grid[row][col] = chr(code)
        out[blk] = [''.join(row) for row in grid]
    return out
