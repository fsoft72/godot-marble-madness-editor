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
