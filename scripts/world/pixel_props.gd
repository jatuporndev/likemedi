class_name PixelProps
extends RefCounted

const W := 16
const H := 24

const OUTLINE := Color(0.06, 0.04, 0.06)

const PNG_DIR := "res://sprites/world/props/"
const KINDS := ["tree", "dead_tree", "rock", "tombstone", "mushroom", "bush"]
const VARIANTS := 4

static var _cache: Dictionary = {}


static func generate(kind: String, variant: int) -> Texture2D:
	var key := "%s_%d" % [kind, variant]
	if _cache.has(key):
		return _cache[key]

	var path := "%s%s.png" % [PNG_DIR, key]
	var tex: Texture2D = null
	if ResourceLoader.exists(path):
		tex = load(path) as Texture2D

	if tex == null:
		var img := generate_image(kind, variant)
		tex = ImageTexture.create_from_image(img)
		if OS.has_feature("editor"):
			_save_png(img, path)

	_cache[key] = tex
	return tex


static func generate_image(kind: String, variant: int) -> Image:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d" % [kind, variant])
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	match kind:
		"tree":
			_draw_tree(img, rng)
		"dead_tree":
			_draw_dead_tree(img, rng)
		"rock":
			_draw_rock(img, rng)
		"tombstone":
			_draw_tombstone(img, rng)
		"mushroom":
			_draw_mushroom(img, rng)
		_:
			_draw_bush(img, rng)
	_outline(img, OUTLINE)
	_drop_shadow(img)
	return img


static func _save_png(img: Image, path: String) -> void:
	if not DirAccess.dir_exists_absolute(PNG_DIR):
		DirAccess.make_dir_recursive_absolute(PNG_DIR)
	var err := img.save_png(path)
	if err != OK:
		push_warning("PixelProps: failed to save %s (err %d)" % [path, err])


# ---------- drawing primitives ----------

static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < img.get_width() and y < img.get_height():
		img.set_pixel(x, y, c)


static func _fill_ellipse(img: Image, cx: int, cy: int, rx: int, ry: int, c: Color) -> void:
	for y in range(cy - ry, cy + ry + 1):
		for x in range(cx - rx, cx + rx + 1):
			var dx := float(x - cx) / float(max(rx, 1))
			var dy := float(y - cy) / float(max(ry, 1))
			if dx * dx + dy * dy <= 1.0:
				_put(img, x, y, c)


static func _fill_rect(img: Image, x0: int, y0: int, x1: int, y1: int, c: Color) -> void:
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			_put(img, x, y, c)


static func _outline(img: Image, outline_color: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var copy := img.duplicate() as Image
	var offsets := [Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, -1), Vector2i(0, 1)]
	for y in range(h):
		for x in range(w):
			var pixel := copy.get_pixel(x, y)
			if pixel.a >= 0.5:
				continue
			var has_neighbor := false
			for off_variant in offsets:
				var off: Vector2i = off_variant
				var nx := x + off.x
				var ny := y + off.y
				if nx >= 0 and ny >= 0 and nx < w and ny < h:
					if copy.get_pixel(nx, ny).a >= 0.5:
						has_neighbor = true
						break
			if has_neighbor:
				img.set_pixel(x, y, outline_color)


static func _drop_shadow(img: Image) -> void:
	# Soft elliptical shadow at the base of the sprite.
	var shadow := Color(0.0, 0.0, 0.0, 0.45)
	for y in range(H - 3, H):
		for x in range(W):
			var dx := float(x - 8) / 6.0
			var dy := float(y - (H - 2)) / 1.5
			if dx * dx + dy * dy <= 1.0 and img.get_pixel(x, y).a < 0.1:
				img.set_pixel(x, y, shadow)


# ---------- kinds ----------

static func _draw_tree(img: Image, rng: RandomNumberGenerator) -> void:
	var trunk_mid := Color(0.30, 0.20, 0.10).lerp(Color(0.22, 0.14, 0.07), rng.randf())
	var trunk_shade := trunk_mid.darkened(0.25)
	var leaf_dark := Color(0.10, 0.22, 0.12)
	var leaf_mid := Color(0.16, 0.36, 0.18).lerp(Color(0.20, 0.42, 0.22), rng.randf())
	var leaf_light := Color(0.34, 0.60, 0.32)

	# Trunk
	for y in range(14, 22):
		_put(img, 7, y, trunk_shade)
		_put(img, 8, y, trunk_mid)
	# Roots flare
	_put(img, 6, 21, trunk_shade)
	_put(img, 9, 21, trunk_mid)

	# Canopy
	var rx := 5 + rng.randi_range(0, 1)
	var ry := 6 + rng.randi_range(0, 1)
	_fill_ellipse(img, 7, 8, rx, ry, leaf_mid)
	# Shadowed underside
	_fill_ellipse(img, 7, 11, rx - 1, 2, leaf_dark)
	# Dark clump
	_fill_ellipse(img, 10, 9, 2, 2, leaf_dark)
	# Highlight
	_fill_ellipse(img, 5, 5, 2, 2, leaf_light)
	_put(img, 4, 4, leaf_light)


static func _draw_dead_tree(img: Image, rng: RandomNumberGenerator) -> void:
	var trunk_mid := Color(0.24, 0.18, 0.13)
	var trunk_shade := trunk_mid.darkened(0.30)

	for y in range(4, 22):
		_put(img, 7, y, trunk_shade)
		_put(img, 8, y, trunk_mid)
	# Branches
	var branches := [
		Vector2i(6, 8), Vector2i(5, 7), Vector2i(4, 6),
		Vector2i(9, 10), Vector2i(10, 9), Vector2i(11, 8),
		Vector2i(6, 14), Vector2i(5, 13),
		Vector2i(10, 5), Vector2i(11, 4),
	]
	for b_variant in branches:
		var b: Vector2i = b_variant
		_put(img, b.x, b.y, trunk_shade)
	# Forks
	_put(img, 3, 5, trunk_shade)
	_put(img, 12, 3, trunk_shade)
	# Root flare
	_put(img, 6, 21, trunk_shade)
	_put(img, 9, 21, trunk_mid)
	# Tiny knothole highlight
	if rng.randf() < 0.5:
		_put(img, 8, 12, Color(0.10, 0.05, 0.03))


static func _draw_rock(img: Image, rng: RandomNumberGenerator) -> void:
	var stone_mid := Color(0.42, 0.42, 0.46).lerp(Color(0.50, 0.50, 0.54), rng.randf())
	var stone_dark := stone_mid.darkened(0.30)
	var stone_light := stone_mid.lightened(0.20)
	var moss := Color(0.18, 0.38, 0.20)

	_fill_ellipse(img, 8, 18, 6, 4, stone_mid)
	_fill_ellipse(img, 8, 19, 6, 3, stone_dark)
	# Top lump
	_fill_ellipse(img, 7, 14, 4, 3, stone_mid)
	# Highlights (top-left rim)
	_put(img, 5, 13, stone_light)
	_put(img, 6, 12, stone_light)
	_put(img, 4, 16, stone_light)
	# Moss patches
	if rng.randf() < 0.7:
		_put(img, 9, 13, moss)
		_put(img, 10, 14, moss)
	if rng.randf() < 0.5:
		_put(img, 5, 17, moss)
	# Cracks
	_put(img, 8, 17, stone_dark)
	_put(img, 9, 16, stone_dark)


static func _draw_tombstone(img: Image, rng: RandomNumberGenerator) -> void:
	var stone_mid := Color(0.46, 0.46, 0.50)
	var stone_dark := stone_mid.darkened(0.30)
	var stone_light := stone_mid.lightened(0.18)
	var lean := 0
	if rng.randf() < 0.4:
		lean = -1
	elif rng.randf() < 0.7:
		lean = 1

	# Base
	_fill_rect(img, 3, 19, 12, 22, stone_dark)
	# Slab
	var top_y := 6
	for y in range(top_y, 20):
		var x0 := 5 + lean if y < 9 else 4 + lean
		var x1 := 10 + lean if y < 9 else 11 + lean
		_fill_rect(img, x0, y, x1, y, stone_mid)
	# Rounded top
	_put(img, 6 + lean, 5, stone_mid)
	_put(img, 7 + lean, 4, stone_mid)
	_put(img, 8 + lean, 4, stone_mid)
	_put(img, 9 + lean, 5, stone_mid)
	# Highlight on left edge
	for y in range(7, 18):
		_put(img, 4 + lean, y, stone_light)
	# Cross / RIP marking
	if rng.randf() < 0.5:
		_put(img, 7 + lean, 9, stone_dark)
		_put(img, 7 + lean, 10, stone_dark)
		_put(img, 7 + lean, 11, stone_dark)
		_put(img, 6 + lean, 10, stone_dark)
		_put(img, 8 + lean, 10, stone_dark)
	else:
		_put(img, 6 + lean, 10, stone_dark)
		_put(img, 7 + lean, 10, stone_dark)
		_put(img, 8 + lean, 10, stone_dark)
		_put(img, 6 + lean, 12, stone_dark)
		_put(img, 7 + lean, 12, stone_dark)
		_put(img, 8 + lean, 12, stone_dark)


static func _draw_mushroom(img: Image, rng: RandomNumberGenerator) -> void:
	var crimson := Color(0.55, 0.10, 0.12)
	var purple := Color(0.32, 0.10, 0.36)
	var cap_color: Color = crimson if rng.randf() < 0.6 else purple
	var cap_dark := cap_color.darkened(0.30)
	var cap_light := cap_color.lightened(0.30)
	var stem := Color(0.86, 0.80, 0.70)
	var stem_shade := stem.darkened(0.20)

	# Big mushroom
	_fill_ellipse(img, 5, 14, 3, 2, cap_color)
	_put(img, 5, 12, cap_color)
	_put(img, 5, 15, cap_dark)
	_put(img, 3, 14, cap_color)
	_put(img, 7, 14, cap_color)
	_put(img, 4, 13, cap_light)
	# Spots
	_put(img, 6, 13, Color.WHITE)
	_put(img, 3, 13, Color.WHITE)
	# Stem
	_put(img, 5, 16, stem)
	_put(img, 5, 17, stem)
	_put(img, 4, 17, stem_shade)
	_put(img, 5, 18, stem_shade)

	# Smaller mushroom
	_fill_ellipse(img, 10, 17, 2, 1, cap_color)
	_put(img, 10, 16, cap_color)
	_put(img, 10, 18, stem)
	_put(img, 10, 19, stem_shade)
	_put(img, 9, 17, cap_dark)
	_put(img, 11, 17, cap_light)


static func _draw_bush(img: Image, rng: RandomNumberGenerator) -> void:
	var dark := Color(0.08, 0.20, 0.10)
	var mid := Color(0.14, 0.32, 0.16).lerp(Color(0.18, 0.40, 0.20), rng.randf())
	var light := Color(0.28, 0.52, 0.28)

	_fill_ellipse(img, 7, 18, 6, 3, mid)
	_fill_ellipse(img, 5, 16, 3, 2, mid)
	_fill_ellipse(img, 10, 16, 3, 2, mid)
	_fill_ellipse(img, 8, 14, 2, 2, mid)
	# Shadow underside
	_fill_ellipse(img, 7, 20, 5, 1, dark)
	# Dark clumps
	_put(img, 10, 17, dark)
	_put(img, 4, 18, dark)
	# Highlights
	_put(img, 5, 14, light)
	_put(img, 8, 13, light)
	# Optional berries
	if rng.randf() < 0.4:
		var berry := Color(0.55, 0.10, 0.10)
		_put(img, 6, 17, berry)
		_put(img, 9, 18, berry)


# ---------- per-kind collision metadata ----------

static func collision_size_for(kind: String) -> Vector2:
	match kind:
		"tree":
			return Vector2(28.0, 16.0)
		"dead_tree":
			return Vector2(22.0, 14.0)
		"rock":
			return Vector2(40.0, 22.0)
		"tombstone":
			return Vector2(32.0, 18.0)
		"mushroom":
			return Vector2(22.0, 10.0)
		_:
			return Vector2(36.0, 16.0)


static func collision_offset_for(kind: String) -> Vector2:
	# Sit just above the foot (sprite bottom is at body origin y=0).
	var size := collision_size_for(kind)
	return Vector2(0.0, -size.y * 0.5)
