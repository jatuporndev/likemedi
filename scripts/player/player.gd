extends CharacterBody2D

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const FIREBALL_PROJECTILE_SCENE := preload("res://scenes/effects/fireball_projectile.tscn")

@export var speed := 160.0
@export var peer_id := 1
@export var display_name := "Player"
@export var idle_texture: Texture2D
@export var run_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var attack_marker: ColorRect = $AttackMarker
@onready var camera: Camera2D = $Camera2D

const FRAME_COUNT := 8
const IDLE_FPS := 4.0
const RUN_FPS := 10.0
const ATTACK_FPS := 14.0
const CHAT_BUBBLE_SECONDS := 4.0
const ACTION_BUBBLE_SECONDS := 1.0
const HOVER_RECT := Rect2(Vector2(-32.0, -48.0), Vector2(64.0, 112.0))
const STRIKE_SKILL_NAME := "strike"
const STRIKE_ATTACK_FORWARD_OFFSET := 28.0
const FIREBALL_PROJECTILE_FORWARD_OFFSET := 18.0

var _server_input := Vector2.ZERO
var _health := 100
var _max_health := 100
var _attack_time := 0.0
var _chat_bubble_time := 0.0
var _animation_time := 0.0
var _current_animation := ""
var _visual_velocity := Vector2.ZERO
var _server_facing_left := false
var _server_aim_direction := Vector2.RIGHT
var _facing_left := false
var _aim_direction := Vector2.RIGHT
var _chat_bubble_box: PanelContainer
var _chat_bubble: Label
var _chat_bubble_tail: Polygon2D
var _chat_bubble_tail_outline: Line2D


func _ready() -> void:
	add_to_group("damageable")
	name_label.text = display_name
	name_label.visible = false
	health_bar.max_value = 100
	health_bar.value = _health
	_apply_health_bar_style()
	_apply_stamina_bar_style()
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 1
	_set_animation("idle")
	camera.enabled = _is_local_player()
	if camera.enabled:
		camera.make_current()
	_build_chat_bubble()
	NetworkManager.chat_message_received.connect(_on_chat_message_received)


func _physics_process(delta: float) -> void:
	if multiplayer.is_server():
		var input_vector := _server_input
		var facing_left := _server_facing_left
		var aim_direction := _server_aim_direction
		if peer_id == multiplayer.get_unique_id():
			input_vector = _read_input()
			aim_direction = _read_mouse_aim_direction()
			facing_left = aim_direction.x < 0.0

		velocity = input_vector * speed
		move_and_slide()
		_visual_velocity = velocity
		_facing_left = facing_left
		_aim_direction = aim_direction
		_sync_state.rpc(position, _health, velocity, facing_left, aim_direction)
	else:
		if _is_local_player():
			_aim_direction = _read_mouse_aim_direction()
			_facing_left = _aim_direction.x < 0.0
			_send_input.rpc_id(1, _read_input(), _facing_left, _aim_direction)

	if _attack_time > 0.0:
		_attack_time = max(_attack_time - delta, 0.0)

	if _chat_bubble_time > 0.0:
		_chat_bubble_time -= delta
		if _chat_bubble_time <= 0.0:
			_set_chat_bubble_visible(false)

	_update_name_hover()
	_update_animation(delta)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_local_player():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		try_attack()
		get_viewport().set_input_as_handled()


func try_attack() -> void:
	try_skill("strike")


func try_fireball() -> void:
	try_skill("fireball")


func try_skill(skill_name: String, target_peer_id: int = -1) -> void:
	if _attack_time > 0.0:
		return
	var definition := SKILL_CARD_DATABASE.get_definition(skill_name)
	var skill_type := str(definition["type"])
	if multiplayer.multiplayer_peer == null:
		_play_skill(str(definition["bubble_text"]))
		if skill_name == "fireball":
			_play_fireball_projectile(global_position, _aim_direction, int(definition["damage"]))
		_apply_skill_effect(skill_name, skill_type, int(definition["damage"]), int(definition["heal"]), float(definition["range"]), target_peer_id)
	elif multiplayer.is_server():
		# Show action bubble above the caster for everyone (like other skills).
		_play_skill.rpc(str(definition["bubble_text"]))
		if skill_name == "fireball":
			_play_fireball_projectile.rpc(global_position, _aim_direction, int(definition["damage"]))
		_apply_skill_effect(skill_name, skill_type, int(definition["damage"]), int(definition["heal"]), float(definition["range"]), target_peer_id)
	else:
		_request_skill.rpc_id(1, skill_name, target_peer_id)


@rpc("any_peer", "unreliable")
func _send_input(input_vector: Vector2, facing_left: bool, aim_direction: Vector2) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_input = input_vector.limit_length(1.0)
	_server_facing_left = facing_left
	_server_aim_direction = aim_direction.normalized()


@rpc("any_peer", "reliable")
func _request_attack() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == peer_id:
		try_skill("strike")


@rpc("any_peer", "reliable")
func _request_fireball() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == peer_id:
		try_skill("fireball")


@rpc("any_peer", "reliable")
func _request_skill(skill_name: String, target_peer_id: int = -1) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == peer_id:
		try_skill(skill_name, target_peer_id)


@rpc("authority", "call_local", "reliable")
func _play_attack() -> void:
	_play_skill("Strike!")


@rpc("authority", "call_local", "reliable")
func _play_fireball() -> void:
	_play_skill("Fireball!")


@rpc("authority", "call_local", "reliable")
func _play_skill(bubble_text: String) -> void:
	if _attack_time > 0.0:
		return
	_attack_time = float(FRAME_COUNT) / ATTACK_FPS
	attack_marker.visible = false
	_set_animation("attack")
	_show_chat_bubble(bubble_text, ACTION_BUBBLE_SECONDS)


@rpc("authority", "call_local", "unreliable")
func _play_fireball_projectile(origin: Vector2, direction: Vector2, damage: int) -> void:
	var parent := get_parent()
	if parent == null:
		return

	var fireball := FIREBALL_PROJECTILE_SCENE.instantiate()
	if fireball == null:
		return

	parent.add_child(fireball)
	var forward := direction.normalized()
	if forward.length_squared() <= 0.0:
		forward = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var spawn_origin := origin + forward * FIREBALL_PROJECTILE_FORWARD_OFFSET
	if fireball.has_method("setup"):
		fireball.call("setup", spawn_origin, forward, damage, peer_id, self)


@rpc("authority", "unreliable")
func _sync_state(
	server_position: Vector2,
	server_health: int,
	server_velocity: Vector2,
	facing_left: bool,
	aim_direction: Vector2
) -> void:
	position = server_position
	_health = server_health
	_visual_velocity = server_velocity
	_facing_left = facing_left
	_aim_direction = aim_direction.normalized()
	health_bar.value = _health


func _apply_test_attack_damage() -> void:
	var definition := SKILL_CARD_DATABASE.get_definition("strike")
	_apply_test_skill_damage(STRIKE_SKILL_NAME, int(definition["damage"]), float(definition["range"]))


func _apply_test_skill_damage(skill_name: String, amount: int, attack_range: float) -> void:
	var target := _find_test_attack_target(skill_name, attack_range)
	if target == null:
		return

	target.call("_take_test_damage", amount, self)


func _apply_skill_effect(
	skill_name: String,
	skill_type: String,
	damage: int,
	heal: int,
	attack_range: float,
	target_peer_id: int = -1
) -> void:
	if skill_type == "heal":
		_heal_target(heal, target_peer_id)
		return

	if skill_name == "fireball":
		return

	_apply_test_skill_damage(skill_name, damage, attack_range)


func _heal_target(amount: int, target_peer_id: int = -1) -> void:
	if amount <= 0:
		return

	var target := _find_heal_target(target_peer_id)
	if target == null or not target.has_method("_receive_heal"):
		return

	target.call("_receive_heal", amount)


func _find_heal_target(target_peer_id: int = -1) -> Node:
	var players := get_parent()
	if players == null:
		return self

	if target_peer_id >= 0:
		var target := players.get_node_or_null(str(target_peer_id))
		if target != null:
			return target

	return self


func _receive_heal(amount: int) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return

	_health = mini(_health + amount, _max_health)
	health_bar.value = _health
	# Note: the healer already shows the "Heal!" action bubble via `_play_skill()`.
	# Do not show a bubble on the healed target.


func _find_test_attack_target(skill_name: String, attack_range: float) -> Node:
	var closest_target: Node = null
	var closest_distance_squared := attack_range * attack_range
	var forward := _aim_direction.normalized()
	if forward.length_squared() <= 0.0:
		forward = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var attack_origin := global_position
	if skill_name == STRIKE_SKILL_NAME:
		attack_origin += forward * STRIKE_ATTACK_FORWARD_OFFSET
	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not node.has_method("_take_test_damage"):
			continue

		var player := node as Node2D
		if player == null:
			continue
		if int(node.get("_health")) <= 0:
			continue

		var to_target := player.global_position - attack_origin
		if skill_name == STRIKE_SKILL_NAME and to_target.normalized().dot(forward) <= 0.0:
			continue

		var distance_squared := to_target.length_squared()
		if distance_squared <= closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = node

	return closest_target


func _take_test_damage(amount: int, _attacker: Node = null) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return

	_health = maxi(_health - amount, 0)
	health_bar.value = _health


func _read_input() -> Vector2:
	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control is LineEdit or focused_control is TextEdit:
		return Vector2.ZERO

	return Input.get_vector("move_left", "move_right", "move_up", "move_down").limit_length(1.0)


func _is_local_player() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _update_animation(delta: float) -> void:
	var is_running := _visual_velocity.length_squared() > 1.0
	var animation_name := "run" if is_running else "idle"
	var fps := RUN_FPS if is_running else IDLE_FPS

	if _attack_time > 0.0 and attack_texture != null:
		animation_name = "attack"
		fps = ATTACK_FPS

	_set_animation(animation_name)
	sprite.flip_h = _facing_left

	_animation_time += delta * fps
	if animation_name == "attack":
		sprite.frame = min(int(_animation_time), FRAME_COUNT - 1)
	else:
		sprite.frame = int(_animation_time) % FRAME_COUNT


func _set_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return

	_current_animation = animation_name
	_animation_time = 0.0
	if animation_name == "attack" and attack_texture != null:
		sprite.texture = attack_texture
	elif animation_name == "run" and run_texture != null:
		sprite.texture = run_texture
	elif idle_texture != null:
		sprite.texture = idle_texture
	sprite.frame = 0


func _update_name_hover() -> void:
	name_label.visible = HOVER_RECT.has_point(to_local(get_global_mouse_position()))


func _apply_health_bar_style() -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	background_style.corner_radius_top_left = 2
	background_style.corner_radius_top_right = 2
	background_style.corner_radius_bottom_left = 2
	background_style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.18, 0.82, 0.28)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("fill", fill_style)


func set_stamina_bar(current_value: float, max_value: float) -> void:
	stamina_bar.max_value = max_value
	stamina_bar.value = clampf(current_value, 0.0, max_value)


func _apply_stamina_bar_style() -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.06, 0.08, 0.10, 0.85)
	background_style.corner_radius_top_left = 2
	background_style.corner_radius_top_right = 2
	background_style.corner_radius_bottom_left = 2
	background_style.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.21, 0.66, 0.86)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	stamina_bar.add_theme_stylebox_override("fill", fill_style)


func _read_mouse_facing_left() -> bool:
	return _read_mouse_aim_direction().x < 0.0


func _read_mouse_aim_direction() -> Vector2:
	var to_mouse := get_global_mouse_position() - global_position
	if to_mouse.length_squared() <= 1.0:
		return _aim_direction
	return to_mouse.normalized()


func _build_chat_bubble() -> void:
	_chat_bubble_box = PanelContainer.new()
	_chat_bubble_box.visible = false
	_chat_bubble_box.z_index = 20
	_chat_bubble_box.offset_left = -48.0
	_chat_bubble_box.offset_top = -100.0
	_chat_bubble_box.offset_right = 48.0
	_chat_bubble_box.offset_bottom = -74.0

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(1.0, 1.0, 1.0)
	bubble_style.border_color = Color(0.0, 0.0, 0.0)
	bubble_style.border_width_left = 2
	bubble_style.border_width_top = 2
	bubble_style.border_width_right = 2
	bubble_style.border_width_bottom = 2
	bubble_style.corner_radius_top_left = 6
	bubble_style.corner_radius_top_right = 6
	bubble_style.corner_radius_bottom_left = 6
	bubble_style.corner_radius_bottom_right = 6
	_chat_bubble_box.add_theme_stylebox_override("panel", bubble_style)
	add_child(_chat_bubble_box)

	var chat_margin := MarginContainer.new()
	chat_margin.add_theme_constant_override("margin_left", 5)
	chat_margin.add_theme_constant_override("margin_right", 5)
	chat_margin.add_theme_constant_override("margin_top", 3)
	chat_margin.add_theme_constant_override("margin_bottom", 3)
	_chat_bubble_box.add_child(chat_margin)

	_chat_bubble = Label.new()
	_chat_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chat_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_bubble.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0))
	_chat_bubble.add_theme_font_size_override("font_size", 9)
	chat_margin.add_child(_chat_bubble)

	_chat_bubble_tail = Polygon2D.new()
	_chat_bubble_tail.visible = false
	_chat_bubble_tail.z_index = 19
	_chat_bubble_tail.color = Color(1.0, 1.0, 1.0)
	_chat_bubble_tail.polygon = PackedVector2Array([
		Vector2(-6.0, -76.0),
		Vector2(7.0, -76.0),
		Vector2(0.0, -66.0),
	])
	add_child(_chat_bubble_tail)

	_chat_bubble_tail_outline = Line2D.new()
	_chat_bubble_tail_outline.visible = false
	_chat_bubble_tail_outline.z_index = 21
	_chat_bubble_tail_outline.width = 2.0
	_chat_bubble_tail_outline.default_color = Color(0.0, 0.0, 0.0)
	_chat_bubble_tail_outline.points = PackedVector2Array([
		Vector2(-6.0, -76.0),
		Vector2(0.0, -66.0),
		Vector2(7.0, -76.0),
	])
	add_child(_chat_bubble_tail_outline)


func _on_chat_message_received(sender_id: int, message: String) -> void:
	if sender_id != peer_id:
		return

	_show_chat_bubble(message, CHAT_BUBBLE_SECONDS)


func _show_chat_bubble(message: String, duration: float) -> void:
	_chat_bubble.text = message
	_set_chat_bubble_visible(true)
	_chat_bubble_time = duration


func _set_chat_bubble_visible(is_visible: bool) -> void:
	_chat_bubble_box.visible = is_visible
	_chat_bubble_tail.visible = is_visible
	_chat_bubble_tail_outline.visible = is_visible
