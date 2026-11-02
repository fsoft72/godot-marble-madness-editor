"""Places the measured elements (elements.json) on a reconstructed level dictionary."""
import json
import os

from locate import level_tiles, locate
from vertices import HS

POST_HEIGHT = 0.55
TUBE_RADIUS = 0.26
# Screen rows from the rail highlight down to the floor under the rail axis.
HIGHLIGHT_TO_FLOOR = (TUBE_RADIUS + POST_HEIGHT) * HS
MARBLE_RADIUS = 0.52


def _free_block(level, x, z, used):
    """Returns the block key of world tile (x, z), or the nearest block without element."""
    bx, bz = int(x // 3), int(z // 3)
    best = None
    for b in level['blocks'].values():
        if f"{b['bx']},{b['bz']}" in used: continue
        d = (b['bx'] - bx) ** 2 + (b['bz'] - bz) ** 2
        if best is None or d < best[0]: best = (d, b)
    return best[1]


def place(level, path=os.path.join(os.path.dirname(__file__), 'elements.json'), log=print):
    """Adds tube_path, cone, goal_flags and marble_start elements to the level in place."""
    spec = json.load(open(path))
    tiles, focus = level_tiles(level)
    used = set()

    def ground(sx, sy):
        p = locate(tiles, focus, sx, sy)
        if p is not None: return p
        # No tile right there (hidden by the element itself): take the nearest visible floor
        # point on the same screen column below or above, keeping the screen point exact by
        # moving along the view direction on that floor height.
        for d in range(1, 14):
            for dy in (d, -d):
                q = locate(tiles, focus, sx, sy + dy)
                if q is None: continue
                # Same height as q; screen row sy needs x + z larger by dy / 4 (sy = 4 (x+z) - HS y).
                t = -dy / 8.0
                return (q[0] + t, q[1], q[2] + t)
        log(f'element: no floor under {sx},{sy}')
        return None

    def claim(p, fields):
        b = _free_block(level, p[0], p[2], used)
        used.add(f"{b['bx']},{b['bz']}")
        b.update(fields)
        return b

    for tube in spec['tubes']:
        pts = [ground(sx, sy + HIGHLIGHT_TO_FLOOR) for sx, sy in tube['points']]
        if any(p is None for p in pts): continue
        b = _free_block(level, pts[0][0], pts[0][2], used)
        ox, oz = b['bx'] * 3, b['bz'] * 3
        claim(pts[0], {'element': 'tube_path', 'tubePoints': [[round(p[0] - ox, 3), round(p[1] + POST_HEIGHT, 3), round(p[2] - oz, 3)] for p in pts], 'tubePosts': tube['posts']})
    for cone in spec['cones']:
        p = ground(*cone['floor'])
        if p is None: continue
        b = _free_block(level, p[0], p[2], used)
        claim(p, {'element': 'cone_large', 'coneSize': cone['size'], 'elemOffset': [round(p[0] - b['bx'] * 3, 3), round(p[2] - b['bz'] * 3, 3)]})
    p = ground(*spec['start'])
    if p is not None:
        b = _free_block(level, p[0], p[2], used)
        claim(p, {'element': 'marble_start', 'elemOffset': [round(p[0] - b['bx'] * 3, 3), round(p[2] - b['bz'] * 3, 3)]})
    flags = [ground(sx, sy) for sx, sy in spec['flags']]
    if all(f is not None for f in flags):
        b = _free_block(level, flags[0][0], flags[0][2], used)
        ox, oz = b['bx'] * 3, b['bz'] * 3
        claim(flags[0], {'element': 'goal_flags', 'flagPoints': [[round(f[0] - ox, 3), round(f[1], 3), round(f[2] - oz, 3)] for f in flags]})
