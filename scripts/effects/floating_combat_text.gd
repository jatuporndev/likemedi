extends RefCounted
class_name FloatingCombatText

const FLOAT_DISTANCE := 42.0
const LIFETIME_SECONDS := 0.85
const TEXT_OFFSET := Vector2(0.0, -58.0)
const DAMAGE_COLOR := Color(1.0, 0.18, 0.08)
const HEAL_COLOR := Color(0.28, 1.0, 0.38)
const OUTLINE_COLOR := Color(0.08, 0.0, 0.0)
const DRAW_ORDER := 5000


static func spawn_damage(parent: Node, world_position: Vector2, amount: int) -> void:
	_spawn_number(parent, world_position, amount, DAMAGE_COLOR)


static func spawn_heal(parent: Node, world_position: Vector2, amount: int) -> void:
	_spawn_number(parent, world_position, amount, HEAL_COLOR)


static func _spawn_number(parent: Node, world_position: Vector2, amount: int, text_color: Color) -> void:
	if parent == null or amount <= 0:
		return

	var root := Node2D.new()
	root.z_as_relative = false
	root.z_index = DRAW_ORDER
	parent.add_child(root)
	root.global_position = world_position + TEXT_OFFSET

	var label := Label.new()
	label.text = str(amount)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", OUTLINE_COLOR)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_font_size_override("font_size", 18)
	label.offset_left = -38.0
	label.offset_top = -16.0
	label.offset_right = 38.0
	label.offset_bottom = 16.0
	root.add_child(label)

	var tween := root.create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		root,
		"global_position",
		root.global_position + Vector2(0.0, -FLOAT_DISTANCE),
		LIFETIME_SECONDS
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(root, "modulate:a", 0.0, LIFETIME_SECONDS).set_delay(0.2)
	tween.set_parallel(false)
	tween.tween_callback(root.queue_free)
