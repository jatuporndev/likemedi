"""Bakes pixel-art prop sprites to PNG files.

Mirrors the logic in scripts/world/pixel_props.gd so the on-disk PNGs match
what the runtime generator would produce. Run once to populate
sprites/world/props/.
"""

from __future__ import annotations

import os
import random
from PIL import Image

W, H = 16, 24
OUTLINE = (15, 10, 15, 255)  # Color(0.06, 0.04, 0.06)

KINDS = ["tree", "dead_tree", "rock", "tombstone", "mushroom", "bush"]
VARIANTS = 4

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "sprites", "world", "props")
OUT_DIR = os.path.abspath(OUT_DIR)


def c(r, g, b, a=1.0):
    return (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)), int(round(a * 255)))


def lerp(a, b, t):
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(4))


def darken(col, amount):
    return (
        int(round(col[0] * (1 - amount))),
        int(round(col[1] * (1 - amount))),
        int(round(col[2] * (1 - amount))),
        col[3],
    )


def lighten(col, amount):
    return (
        int(round(col[0] + (255 - col[0]) * amount)),
        int(round(col[1] + (255 - col[1]) * amount)),
        int(round(col[2] + (255 - col[2]) * amount)),
        col[3],
    )


def put(img, x, y, col):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def fill_ellipse(img, cx, cy, rx, ry, col):
    rx = max(rx, 1)
    ry = max(ry, 1)
    for y in range(cy - ry, cy + ry + 1):
        for x in range(cx - rx, cx + rx + 1):
            dx = (x - cx) / rx
            dy = (y - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                put(img, x, y, col)


def fill_rect(img, x0, y0, x1, y1, col):
    for y in range(y0, y1 + 1):
        for x in range(x0, x1 + 1):
            put(img, x, y, col)


def outline_pass(img, outline_col):
    copy = img.copy()
    offsets = [(-1, 0), (1, 0), (0, -1), (0, 1)]
    for y in range(img.height):
        for x in range(img.width):
            r, g, b, a = copy.getpixel((x, y))
            if a >= 128:
                continue
            has_neighbor = False
            for dx, dy in offsets:
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height:
                    if copy.getpixel((nx, ny))[3] >= 128:
                        has_neighbor = True
                        break
            if has_neighbor:
                img.putpixel((x, y), outline_col)


def drop_shadow(img):
    shadow = (0, 0, 0, int(round(0.45 * 255)))
    for y in range(H - 3, H):
        for x in range(W):
            dx = (x - 8) / 6.0
            dy = (y - (H - 2)) / 1.5
            if dx * dx + dy * dy <= 1.0:
                if img.getpixel((x, y))[3] < 25:
                    img.putpixel((x, y), shadow)


# ---------------- kinds ----------------

def draw_tree(img, rng):
    trunk_mid = lerp(c(0.30, 0.20, 0.10), c(0.22, 0.14, 0.07), rng.random())
    trunk_shade = darken(trunk_mid, 0.25)
    leaf_dark = c(0.10, 0.22, 0.12)
    leaf_mid = lerp(c(0.16, 0.36, 0.18), c(0.20, 0.42, 0.22), rng.random())
    leaf_light = c(0.34, 0.60, 0.32)

    for y in range(14, 22):
        put(img, 7, y, trunk_shade)
        put(img, 8, y, trunk_mid)
    put(img, 6, 21, trunk_shade)
    put(img, 9, 21, trunk_mid)

    rx = 5 + rng.randint(0, 1)
    ry = 6 + rng.randint(0, 1)
    fill_ellipse(img, 7, 8, rx, ry, leaf_mid)
    fill_ellipse(img, 7, 11, rx - 1, 2, leaf_dark)
    fill_ellipse(img, 10, 9, 2, 2, leaf_dark)
    fill_ellipse(img, 5, 5, 2, 2, leaf_light)
    put(img, 4, 4, leaf_light)


def draw_dead_tree(img, rng):
    trunk_mid = c(0.24, 0.18, 0.13)
    trunk_shade = darken(trunk_mid, 0.30)

    for y in range(4, 22):
        put(img, 7, y, trunk_shade)
        put(img, 8, y, trunk_mid)

    branches = [
        (6, 8), (5, 7), (4, 6),
        (9, 10), (10, 9), (11, 8),
        (6, 14), (5, 13),
        (10, 5), (11, 4),
    ]
    for bx, by in branches:
        put(img, bx, by, trunk_shade)
    put(img, 3, 5, trunk_shade)
    put(img, 12, 3, trunk_shade)
    put(img, 6, 21, trunk_shade)
    put(img, 9, 21, trunk_mid)
    if rng.random() < 0.5:
        put(img, 8, 12, c(0.10, 0.05, 0.03))


def draw_rock(img, rng):
    stone_mid = lerp(c(0.42, 0.42, 0.46), c(0.50, 0.50, 0.54), rng.random())
    stone_dark = darken(stone_mid, 0.30)
    stone_light = lighten(stone_mid, 0.20)
    moss = c(0.18, 0.38, 0.20)

    fill_ellipse(img, 8, 18, 6, 4, stone_mid)
    fill_ellipse(img, 8, 19, 6, 3, stone_dark)
    fill_ellipse(img, 7, 14, 4, 3, stone_mid)
    put(img, 5, 13, stone_light)
    put(img, 6, 12, stone_light)
    put(img, 4, 16, stone_light)
    if rng.random() < 0.7:
        put(img, 9, 13, moss)
        put(img, 10, 14, moss)
    if rng.random() < 0.5:
        put(img, 5, 17, moss)
    put(img, 8, 17, stone_dark)
    put(img, 9, 16, stone_dark)


def draw_tombstone(img, rng):
    stone_mid = c(0.46, 0.46, 0.50)
    stone_dark = darken(stone_mid, 0.30)
    stone_light = lighten(stone_mid, 0.18)

    lean = 0
    if rng.random() < 0.4:
        lean = -1
    elif rng.random() < 0.7:
        lean = 1

    fill_rect(img, 3, 19, 12, 22, stone_dark)

    for y in range(6, 20):
        x0 = (5 + lean) if y < 9 else (4 + lean)
        x1 = (10 + lean) if y < 9 else (11 + lean)
        fill_rect(img, x0, y, x1, y, stone_mid)

    put(img, 6 + lean, 5, stone_mid)
    put(img, 7 + lean, 4, stone_mid)
    put(img, 8 + lean, 4, stone_mid)
    put(img, 9 + lean, 5, stone_mid)

    for y in range(7, 18):
        put(img, 4 + lean, y, stone_light)

    if rng.random() < 0.5:
        put(img, 7 + lean, 9, stone_dark)
        put(img, 7 + lean, 10, stone_dark)
        put(img, 7 + lean, 11, stone_dark)
        put(img, 6 + lean, 10, stone_dark)
        put(img, 8 + lean, 10, stone_dark)
    else:
        put(img, 6 + lean, 10, stone_dark)
        put(img, 7 + lean, 10, stone_dark)
        put(img, 8 + lean, 10, stone_dark)
        put(img, 6 + lean, 12, stone_dark)
        put(img, 7 + lean, 12, stone_dark)
        put(img, 8 + lean, 12, stone_dark)


def draw_mushroom(img, rng):
    crimson = c(0.55, 0.10, 0.12)
    purple = c(0.32, 0.10, 0.36)
    cap_color = crimson if rng.random() < 0.6 else purple
    cap_dark = darken(cap_color, 0.30)
    cap_light = lighten(cap_color, 0.30)
    stem = c(0.86, 0.80, 0.70)
    stem_shade = darken(stem, 0.20)

    fill_ellipse(img, 5, 14, 3, 2, cap_color)
    put(img, 5, 12, cap_color)
    put(img, 5, 15, cap_dark)
    put(img, 3, 14, cap_color)
    put(img, 7, 14, cap_color)
    put(img, 4, 13, cap_light)
    put(img, 6, 13, c(1, 1, 1))
    put(img, 3, 13, c(1, 1, 1))
    put(img, 5, 16, stem)
    put(img, 5, 17, stem)
    put(img, 4, 17, stem_shade)
    put(img, 5, 18, stem_shade)

    fill_ellipse(img, 10, 17, 2, 1, cap_color)
    put(img, 10, 16, cap_color)
    put(img, 10, 18, stem)
    put(img, 10, 19, stem_shade)
    put(img, 9, 17, cap_dark)
    put(img, 11, 17, cap_light)


def draw_bush(img, rng):
    dark = c(0.08, 0.20, 0.10)
    mid = lerp(c(0.14, 0.32, 0.16), c(0.18, 0.40, 0.20), rng.random())
    light = c(0.28, 0.52, 0.28)

    fill_ellipse(img, 7, 18, 6, 3, mid)
    fill_ellipse(img, 5, 16, 3, 2, mid)
    fill_ellipse(img, 10, 16, 3, 2, mid)
    fill_ellipse(img, 8, 14, 2, 2, mid)
    fill_ellipse(img, 7, 20, 5, 1, dark)
    put(img, 10, 17, dark)
    put(img, 4, 18, dark)
    put(img, 5, 14, light)
    put(img, 8, 13, light)
    if rng.random() < 0.4:
        berry = c(0.55, 0.10, 0.10)
        put(img, 6, 17, berry)
        put(img, 9, 18, berry)


DRAW = {
    "tree": draw_tree,
    "dead_tree": draw_dead_tree,
    "rock": draw_rock,
    "tombstone": draw_tombstone,
    "mushroom": draw_mushroom,
    "bush": draw_bush,
}


def generate(kind, variant):
    rng = random.Random(f"{kind}_{variant}")
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    DRAW[kind](img, rng)
    outline_pass(img, OUTLINE)
    drop_shadow(img)
    return img


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    count = 0
    for kind in KINDS:
        for v in range(VARIANTS):
            img = generate(kind, v)
            path = os.path.join(OUT_DIR, f"{kind}_{v}.png")
            img.save(path, "PNG")
            print(f"baked {path}")
            count += 1
    print(f"done: {count} PNG sprites in {OUT_DIR}")


if __name__ == "__main__":
    main()
