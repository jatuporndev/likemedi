# Skill: Generate Pixel-Art Prop Sprites

Hand-off doc for another agent. Goal: produce PNG sprites for world props
(trees, rocks, tombstones, mushrooms, bushes, etc.) that the game loads from
disk at runtime — no in-engine drawing tools, no Aseprite, all reproducible
from code.

## What exists already

- **`scripts/world/pixel_props.gd`** — runtime loader/generator. Looks up
  `res://sprites/world/props/<kind>_<variant>.png`; if missing, falls back to
  procedural drawing and (in editor) auto-bakes the PNG.
- **`tools/bake_pixel_props.gd`** — Godot `EditorScript`. Run via
  *File → Run* in the script editor. Generates PNGs using the GDScript drawer.
- **`tools/bake_pixel_props.py`** — Python + Pillow port of the same drawing
  logic. Produces byte-identical-ish PNGs without Godot. Run with
  `python tools/bake_pixel_props.py` from the repo root.
- **`sprites/world/props/*.png`** — current baked output (4 variants × 6 kinds
  = 24 files, 16×24 RGBA).

## How the runtime consumes the sprites

`scripts/game/world.gd::_spawn_procedural_prop()`:

1. Calls `PixelProps.generate(kind, variant)` → `Texture2D`.
2. Wraps it in a `Sprite2D` with `texture_filter = NEAREST` and
   `scale = (PROP_PIXEL_SCALE, PROP_PIXEL_SCALE)` (currently 4×).
3. Adds a `CollisionShape2D` whose size/offset come from
   `PixelProps.collision_size_for(kind)` / `collision_offset_for(kind)`.

So changing a sprite's silhouette may require updating the collision metadata
in `pixel_props.gd` to match.

## Adding a new prop kind (workflow)

1. **Add the kind to the kind list** in both files:
   - `scripts/world/pixel_props.gd` → `KINDS` array.
   - `tools/bake_pixel_props.py` → `KINDS` list.
2. **Write the drawer.** Add a function (e.g. `_draw_lantern`) in
   `pixel_props.gd` that paints into a 16×24 `Image` using `_put`,
   `_fill_ellipse`, `_fill_rect`. Mirror it in `bake_pixel_props.py` with
   matching `put` / `fill_ellipse` / `fill_rect` helpers. **Keep the two
   drawers in lockstep** — divergence here is the main failure mode.
3. **Register collision metadata** in `pixel_props.gd::collision_size_for`
   and `collision_offset_for` for the new kind.
4. **Add the kind to the world spawn roll** in
   `scripts/game/world.gd::_spawn_current_map_props` (the `kind_roll`
   if/elif chain) if it should appear in random scatter.
5. **Bake.** Run `python tools/bake_pixel_props.py`. Confirm
   `sprites/world/props/<kind>_0..3.png` exist.
6. **Re-import.** Open Godot and let the FileSystem dock import the new
   PNGs (creates `.import` siblings). After that, the runtime loads PNGs
   from disk; the procedural generator only runs as a fallback.

## Constraints (from CLAUDE.md)

- Do **not** hand-edit `.tscn`, `.tres`, `.import`, or `.uid` files. Let the
  Godot editor manage them.
- GDScript style: tabs, typed vars, `_underscore` private prefix,
  `snake_case.gd` filenames.
- Determinism: every sprite is seeded with `random.Random(f"{kind}_{variant}")`
  in Python or `RandomNumberGenerator.seed = hash("%s_%d" % [kind, variant])`
  in GDScript. Same seed → same sprite, so server and client agree.

## Drawing primitives reference

All sprites are 16 wide × 24 tall, RGBA, transparent background.
Coordinate `(0,0)` is top-left. The prop's "foot" (for Y-sort and collision)
is at the bottom of the image.

| Helper | Purpose |
|--------|---------|
| `put(img, x, y, col)` | single pixel |
| `fill_ellipse(img, cx, cy, rx, ry, col)` | filled ellipse |
| `fill_rect(img, x0, y0, x1, y1, col)` | filled rect (inclusive) |
| `outline_pass(img, OUTLINE)` | adds a 1px dark border on transparent pixels adjacent to opaque ones |
| `drop_shadow(img)` | adds a semi-transparent ellipse in the bottom 3 rows |

Standard order inside `generate()`: draw shape → `outline_pass` →
`drop_shadow`.

## Color guidelines (medieval-fantasy-dark palette)

- Foliage greens: `(0.16, 0.36, 0.18)` mid → `(0.34, 0.60, 0.32)` highlight,
  `(0.10, 0.22, 0.12)` shadow.
- Stone: `(0.42, 0.42, 0.46)` mid, darken 30% for shade, lighten 20% for
  highlight.
- Tree bark: `(0.30, 0.20, 0.10)` mid, darken 25%.
- Moss accent on stone: `(0.18, 0.38, 0.20)`.
- Mushroom caps: crimson `(0.55, 0.10, 0.12)` or purple `(0.32, 0.10, 0.36)`.
- Outline: `(0.06, 0.04, 0.06)` (near-black, slightly warm).

## Verifying the result

After baking, open one of the PNGs in any image viewer. Check:

- Dimensions are exactly 16×24.
- The shape's "foot" sits at the bottom of the canvas (rows 21–23), so the
  drop shadow lands under it.
- There is a 1-pixel dark outline around every opaque silhouette.
- Variants 0–3 look distinct (color jitter, lean, branch arrangement, etc.)
  but recognisably the same kind.

Then run the game from `scenes/menu/main_menu.tscn`; props should render
sharp at 4× nearest-neighbor scale with shadows under their feet.
