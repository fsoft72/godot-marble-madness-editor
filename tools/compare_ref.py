#!/usr/bin/env python3
"""Compares a render of tools/render_level.gd with the arcade reference image.

Usage: python3 tools/compare_ref.py RENDER.png [--ref assets/level01_ref.png] [--diff out.png]

Both images are 2x pixel art; the comparison runs on the logical (288x590) pixels.
Prints the share of logical pixels with exactly the same color and the share with the same
material class (black, top tile gray, wall, red element ...), and writes a diff image:
matching pixels dimmed, mismatches in magenta.
"""
import argparse
import sys

import numpy as np
from PIL import Image

DEFAULT_REF = 'assets/level01_ref.png'

# Material classes of the arcade palette (sRGB values).
CLASSES = {
    'black': [(0, 0, 0)],
    'gray': [(51, 51, 51), (68, 68, 68), (102, 102, 102), (153, 153, 153), (187, 187, 187), (221, 221, 221)],
    'yellow': [(204, 204, 0)],
    'orange': [(204, 102, 0)],
    'crimson': [(136, 34, 34)],
    'red': [(102, 34, 34), (170, 34, 34), (221, 51, 51), (255, 136, 136), (204, 0, 0), (102, 0, 0)],
}


def load_logical(path):
    """Returns the logical pixels (every second pixel) of a 2x image as an int array."""
    img = np.array(Image.open(path).convert('RGB')).astype(int)
    return img[::2, ::2]


def classify(img):
    """Returns a class index per pixel (len(CLASSES) for colors outside the palette)."""
    out = np.full(img.shape[:2], len(CLASSES), int)
    for i, colors in enumerate(CLASSES.values()):
        for c in colors:
            out[(img == np.array(c)).all(axis=2)] = i
    return out


def compare(render, ref):
    """Returns (exact share, class share, exact mask)."""
    if render.shape != ref.shape:
        raise SystemExit(f'size mismatch: render {render.shape} vs reference {ref.shape}')
    exact = (render == ref).all(axis=2)
    same_class = classify(render) == classify(ref)
    return exact.mean(), same_class.mean(), exact


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('render')
    ap.add_argument('--ref', default=DEFAULT_REF)
    ap.add_argument('--diff')
    args = ap.parse_args()
    render = load_logical(args.render)
    ref = load_logical(args.ref)
    exact_share, class_share, exact = compare(render, ref)
    print(f'exact {exact_share * 100:.2f}%  class {class_share * 100:.2f}%')
    if args.diff:
        out = (ref * 0.35).astype(np.uint8)
        out[~exact] = (255, 0, 255)
        Image.fromarray(out).resize((out.shape[1] * 2, out.shape[0] * 2), Image.NEAREST).save(args.diff)
    return 0


if __name__ == '__main__':
    sys.exit(main())
