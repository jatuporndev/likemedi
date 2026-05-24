extends Area2D

@export_file("*.tscn") var target_map_scene := ""
@export var target_spawn_name := "SpawnPoint"
@export var display_name := "Warp"
@export var cooldown_seconds := 0.35
@export var visual_size := Vector2(72, 220)
@export var visual_color := Color(0.25, 0.65, 1.0, 0.38)

const LOCKED_UNTIL_META := "map_transition_locked_until_msec"

var _recent_bodies: Dictionary = {}
var _label: Label


func _ready() -> void:
	add_to_group("warp_points")
	body_entered.connect(_on_body_entered)
	_build_label()


func _process(delta: float) -> void:
	var expired_bodies: Array[Node] = []
	for body in _recent_bodies.keys():
		var remaining := float(_recent_bodies[body]) - delta
		if remaining <= 0.0:
			expired_bodies.append(body)
		else:
			_recent_bodies[body] = remaining
	for body in expired_bodies:
		_recent_bodies.erase(body)
	queue_redraw()


func _draw() -> void:
	var pulse := 0.78 + sin(float(Time.get_ticks_msec()) * 0.006) * 0.12
	var rect := Rect2(-visual_size / 2.0, visual_size)
	var fill := Color(visual_color.r, visual_color.g, visual_color.b, visual_color.a * pulse)
	var border := Color(1.0, 0.9, 0.45, 0.95)
	draw_rect(rect, fill, true)
	draw_rect(rect, border, false, 3.0)
	draw_line(Vector2(-visual_size.x * 0.26, 0.0), Vector2(visual_size.x * 0.26, 0.0), border, 4.0)
	draw_line(Vector2(visual_size.x * 0.1, -14.0), Vector2(visual_size.x * 0.26, 0.0), border, 4.0)
	draw_line(Vector2(visual_size.x * 0.1, 14.0), Vector2(visual_size.x * 0.26, 0.0), border, 4.0)


func _on_body_entered(body: Node2D) -> void:
	if body == null or _recent_bodies.has(body):
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return
	if not (body is CharacterBody2D):
		return
	if target_map_scene.is_empty():
		return
	if _is_transition_locked(body):
		return

	var world := get_tree().current_scene
	if world == null or not world.has_method("change_map_for_player"):
		return

	world.call("change_map_for_player", body, target_map_scene, target_spawn_name)
	_recent_bodies[body] = cooldown_seconds


func _is_transition_locked(body: Node) -> bool:
	return int(body.get_meta(LOCKED_UNTIL_META, 0)) > Time.get_ticks_msec()


func _build_label() -> void:
	_label = Label.new()
	_label.text = display_name
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.offset_left = -64.0
	_label.offset_top = -visual_size.y / 2.0 - 28.0
	_label.offset_right = 64.0
	_label.offset_bottom = -visual_size.y / 2.0 - 6.0
	_label.add_theme_font_size_override("font_size", 13)
	_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.46, 1.0))
	add_child(_label)
