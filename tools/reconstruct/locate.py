"""Maps reference screen pixels to world points on the reconstructed level.

Usage: python3 locate.py LEVEL.json sx sy [sx sy ...]   (logical pixel coordinates)
Prints, for each pixel, the world (x, y, z) of the visible top surface point under it, found
by marching the view ray through the level's tiles."""
import json
import sys

import numpy as np

HS = 16.0 / np.sqrt(2.0) * np.cos(np.pi / 6.0)


def load_tiles(path):
    """Returns (list of (x, z, h00, h10, h01, h11, split)), focus) of a level JSON file."""
    return level_tiles(json.load(open(path)))


def level_tiles(level):
    """Returns (list of (x, z, h00, h10, h01, h11, split)), focus) of a level dictionary."""
    out = []
    for b in level['blocks'].values():
        tiles = b.get('tiles')
        if not tiles: continue
        for r in range(3):
            for c in range(3):
                t = tiles[r][c]
                if t is None: continue
                e = b['elevation']
                out.append((b['bx'] * 3 + c, b['bz'] * 3 + r, *[e + h for h in t], b['tileSplit'][r][c]))
    return out, level['arcadeFocus']


def screen_of(p, focus):
    """Logical screen position of world point p (x, y, z)."""
    dx, dy, dz = p[0] - focus[0], p[1] - focus[1], p[2] - focus[2]
    return np.array([144 + (dx - dz) * 8, 295 + (dx + dz) * 4 - dy * HS])


def locate(tiles, focus, sx, sy):
    """Returns the front-most world point (x, y, z) of a tile under screen point (sx, sy)."""
    best = None
    for x, z, h00, h10, h01, h11, split in tiles:
        # Solve on the tile plane pieces by sampling a fine grid (simple and robust).
        us, vs = np.meshgrid(np.linspace(0, 1, 33), np.linspace(0, 1, 33))
        hh = h00 * (1 - us) * (1 - vs) + h10 * us * (1 - vs) + h01 * (1 - us) * vs + h11 * us * vs
        px = 144 + ((x + us - focus[0]) - (z + vs - focus[2])) * 8
        py = 295 + ((x + us - focus[0]) + (z + vs - focus[2])) * 4 - (hh - focus[1]) * HS
        d = (px - sx) ** 2 + (py - sy) ** 2
        i = np.unravel_index(np.argmin(d), d.shape)
        if d[i] > 0.5: continue
        depth = 0.6124 * (x + us[i] + z + vs[i]) + 0.5 * hh[i]
        if best is None or depth > best[0]: best = (depth, (x + us[i], hh[i], z + vs[i]))
    return None if best is None else best[1]


if __name__ == '__main__':
    tiles, focus = load_tiles(sys.argv[1])
    args = [float(a) for a in sys.argv[2:]]
    for sx, sy in zip(args[::2], args[1::2]):
        p = locate(tiles, focus, sx, sy)
        print(f'{sx:.1f},{sy:.1f} -> ' + ('none' if p is None else '(%.2f, %.2f, %.2f)' % p))
