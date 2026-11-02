"""Places the components in depth: picks the m offset of every component that maximizes the
class agreement (top / +X wall / +Z wall) of the z-buffer render with the reference."""
from collections import defaultdict, Counter

import numpy as np

from vertices import height
from walls import wall_kind, votes
from zrender import render_into, TOP, WALL_X, WALL_Z, H, W

SEARCH = range(-12, 13, 2)
# Offsets tried for components without wall votes.
WIDE_SEARCH = range(-20, 130, 2)


def reference_classes(img, cell_labels):
    """Returns the class image of the reference (0 for pixels that are none of the classes)."""
    kind = wall_kind(img)
    cls = np.zeros(kind.shape, int)
    gray = (img[:, :, 0] == img[:, :, 1]) & (img[:, :, 1] == img[:, :, 2]) & (img[:, :, 0] > 0)
    reddish = (img[:, :, 0] > img[:, :, 1] + 40)
    cls[gray | reddish] = TOP
    cls[kind == 2] = WALL_Z
    cls[(kind == 1) & (cell_labels == 0)] = WALL_X
    # Wall seams: gray pixels between wall stripes take the class of the stripes.
    for dx in (-2, -1, 1, 2):
        nb = np.roll(kind, dx, axis=1)
        seam = gray & (cell_labels == 0)
        cls[seam & (nb == 2)] = WALL_Z
        cls[seam & (nb == 1)] = WALL_X
    return cls


def comp_tiles(fit_tiles, verts, comp, off, sy0):
    """Returns the zrender tile tuples of one component placed with m offset `off`."""
    keys = {(k, m) for (c, k, m) in fit_tiles if c == comp}
    out = []
    for (k, m) in keys:
        vk = [(k, m), (k + 1, m + 1), (k - 1, m + 1), (k, m + 2)]
        sys_ = [verts[(comp, kv, mv)] for kv, mv in vk]
        corners = np.array([[8.0 * kv, sy] for (kv, mv), sy in zip(vk, sys_)])
        mvs = [mv + off for kv, mv in vk]
        hs = [height(mv, sy, sy0) for mv, sy in zip(mvs, sys_)]
        wall_x = (k + 1, m + 1) not in keys
        wall_z = (k - 1, m + 1) not in keys
        out.append((corners, hs, mvs, wall_x, wall_z))
    return out


def place(fit_tiles, verts, ref_cls, sy0, root, vote_counts, log=print):
    """Greedy placement, biggest components first. Returns {comp: offset}."""
    sizes = Counter(c for (c, k, m) in fit_tiles)
    order = [c for c, _ in sizes.most_common()]
    offsets = {root: 0}
    zbuf, cls_buf = render_into(comp_tiles(fit_tiles, verts, root, 0, sy0), np.full((H, W), -1e9), np.zeros((H, W), int))
    mask = ref_cls > 0
    for comp in order:
        if comp in offsets: continue
        cands = set()
        for (a, b, d), n in vote_counts.items():
            if b == comp and a in offsets: cands.add(offsets[a] + d)
            if a == comp and b in offsets: cands.add(offsets[b] - d)
        cands = {c + s for c in cands for s in SEARCH} if cands else set(WIDE_SEARCH)
        mine = {o: comp_tiles(fit_tiles, verts, comp, o, sy0) for o in cands}
        base = int(((cls_buf == ref_cls) & mask).sum())
        best = None
        for o in sorted(cands):
            _, cls = render_into(mine[o], zbuf.copy(), cls_buf.copy())
            score = int(((cls == ref_cls) & mask).sum())
            if best is None or score > best[0]: best = (score, o)
        if best[0] <= base:
            log(f'comp {comp} ({sizes[comp]} tiles) dropped: no offset improves the render')
            continue
        offsets[comp] = best[1]
        render_into(mine[best[1]], zbuf, cls_buf)
        log(f'comp {comp} ({sizes[comp]} tiles) offset {best[1]} score {best[0]} (+{best[0] - base})')
    return offsets


def _tile_tuple(fit_tiles, verts, key, off, keys, sy0):
    """Returns the zrender tuple of one tile with m offset `off`; keys: set of (k, m, off) of
    the tiles placed in the same surface (for the wall flags)."""
    comp, k, m = key
    vk = [(k, m), (k + 1, m + 1), (k - 1, m + 1), (k, m + 2)]
    sys_ = [verts[(comp, kv, mv)] for kv, mv in vk]
    corners = np.array([[8.0 * kv, sy] for (kv, mv), sy in zip(vk, sys_)])
    mvs = [mv + off for kv, mv in vk]
    hs = [height(mv, sy, sy0) for mv, sy in zip(mvs, sys_)]
    wall_x = (comp, k + 1, m + 1, off) not in keys
    wall_z = (comp, k - 1, m + 1, off) not in keys
    return (corners, hs, mvs, wall_x, wall_z)


def refine_groups(fit_tiles, verts, ref_cls, offsets, sy0, bad_share=0.6, log=print):
    """Moves groups of badly matching tiles in depth. Returns {tile key: m offset} for every
    placed tile (the component offset unless a group was moved)."""
    tile_off = {key: offsets[key[0]] for key in fit_tiles if key[0] in offsets}
    mask = ref_cls > 0

    def render_all():
        keys = {(c, k, m, o) for (c, k, m), o in tile_off.items()}
        tiles = [_tile_tuple(fit_tiles, verts, key, o, keys, sy0) for key, o in tile_off.items()]
        return render_into(tiles, np.full((H, W), -1e9), np.zeros((H, W), int))[1]

    cls = render_all()
    base = int(((cls == ref_cls) & mask).sum())
    # Tiles whose own footprint agrees badly with the reference classes.
    bad = set()
    for key, o in tile_off.items():
        comp, k, m = key
        ys = [verts[(comp, kv, mv)] for kv, mv in ((k, m), (k, m + 2))]
        y0, y1 = int(max(min(ys), 0)), int(min(max(ys) + 1, H))
        x0, x1 = max(8 * k - 6, 0), min(8 * k + 6, W)
        if y1 <= y0 or x1 <= x0: continue
        win_ref = ref_cls[y0:y1, x0:x1]
        win = cls[y0:y1, x0:x1]
        sel = win_ref > 0
        if sel.sum() and ((win == win_ref) & sel).sum() < bad_share * sel.sum(): bad.add(key)
    # Groups: lattice connected bad tiles of one component.
    groups = []
    seen = set()
    for key in bad:
        if key in seen: continue
        group, stack = [], [key]
        seen.add(key)
        while stack:
            c, k, m = stack.pop()
            group.append((c, k, m))
            for dk, dm in ((1, 1), (-1, 1), (1, -1), (-1, -1)):
                n = (c, k + dk, m + dm)
                if n in bad and n not in seen:
                    seen.add(n)
                    stack.append(n)
        groups.append(group)
    groups.sort(key=len, reverse=True)
    log(f'refine: {len(bad)} bad tiles in {len(groups)} groups, base score {base}')
    for group in groups:
        if len(group) < 2: continue
        o0 = tile_off[group[0]]
        best = (base, 0)
        for d in range(-16, 17, 2):
            if d == 0: continue
            for key in group: tile_off[key] = o0 + d
            s = int(((render_all() == ref_cls) & mask).sum())
            if s > best[0]: best = (s, d)
        for key in group: tile_off[key] = o0 + best[1]
        if best[1]:
            log(f'refine: moved {len(group)} tiles by {best[1]} (+{best[0] - base})')
            base = best[0]
    return tile_off
