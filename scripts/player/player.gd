extends CharacterBody2D

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const FIREBALL_PROJECTILE_SCENE := preload("res://scenes/effects/fireball_projectile.tscn")
const FLOATING_COMBAT_TEXT := preload("res://scripts/effects/floating_combat_text.gd")

@export var speed := 160.0
@export var peer_id := 1
@export var display_name := "Player"
@export var idle_texture: Texture2D
@export var run_texture: Texture2D
@export var attack_texture: Texture2D
@export var hurt_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var attack_marker: ColorRect = $AttackMarker
@onready var camera: Camera2D = $Camera2D

const FRAME_COUNT := 8
const HURT_FRAME_COUNT := 2
const IDLE_FPS := 4.0
const RUN_FPS := 10.0
const ATTACK_FPS := 14.0
const HURT_FPS := 8.0
const CHAT_BUBBLE_SECONDS := 4.0
const ACTION_BUBBLE_SECONDS := 1.0
const HOVER_RECT := Rect2(Vector2(-32.0, -48.0), Vector2(64.0, 112.0))
const STRIKE_SKILL_NAME := "strike"
const STRIKE_ATTACK_FORWARD_OFFSET := 28.0
const FIREBALL_PROJECTILE_FORWARD_OFFSET := 18.0
const STUN_SECONDS := 0.3
const DRAW_ORDER_FOOT_OFFSET := 34.0
const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4096
const SPELL_CAST_FLOOR_OFFSET := Vector2(0.0, 46.0)
const SPELL_CAST_FLOOR_RADIUS := 34.0
const SPELL_CAST_FLOOR_Y_SCALE := 0.52
const SPELL_CAST_FLOOR_SEGMENTS := 48
const SPELL_CAST_MARK_COUNT := 12
const SPELL_CAST_SECONDS := 0.46
const SPELL_CAST_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HEAL_CAST_COLOR := Color(0.42, 1.0, 0.58, 1.0)

var _server_input := Vector2.ZERO
var _health := 100
var _max_health := 100
var _attack_time := 0.0
var _stun_time := 0.0
var _cast_time := 0.0
var _cast_duration := 0.0
var _spell_cast_time := 0.0
var _spell_cast_duration := SPELL_CAST_SECONDS
var _spell_cast_color := SPELL_CAST_COLOR
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
var _cast_progress_bar: ProgressBar
var _spell_cast_floor_root: Node2D
var _spell_cast_fill: Polygon2D
var _spell_cast_ring: Line2D
var _spell_cast_inner_ring: Line2D
var _spell_cast_rune_ring: Line2D
var _spell_cast_marks: Array[Line2D] = []


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	platform_floor_layers = 0
	platform_wall_layers = 0
	add_to_group("damageable")
	z_as_relative = false
	_update_draw_order()
	name_label.text = display_name
	name_label.visible = false
	health_bar.max_value = 100
	health_bar.value = _health
	_apply_health_bar_style()
	_apply_stamina_bar_style()
	sprite.hframes = FRAME_COUNT
	sprite.vframes = 1
	_set_animation("idle")
	_build_spell_cast_floor_circle()
	_build_cast_progress_bar()
	camera.enabled = _is_local_player()
	if camera.enabled:
		camera.make_current()
	_build_chat_bubble()
	NetworkManager.chat_message_received.connect(_on_chat_message_received)


func _physics_process(delta: float) -> void:
	if _stun_time > 0.0:
		_stun_time = max(_stun_time - delta, 0.0)
	if _cast_time > 0.0:
		_cast_time = maxf(_cast_time - delta, 0.0)
		if _cast_time <= 0.0:
			_set_cast_progress_visible(false)

	if multiplayer.is_server():
		var input_vector := _server_input
		var facing_left := _server_facing_left
		var aim_direction := _server_aim_direction
		if peer_id == multiplayer.get_unique_id():
			input_vector = _read_input()
			aim_direction = _read_mouse_aim_direction()
			facing_left = aim_direction.x < 0.0

		if _stun_time > 0.0 or _cast_time > 0.0:
			input_vector = Vector2.ZERO

		velocity = input_vector * speed
		move_and_slide()
		_visual_velocity = velocity
		_facing_left = facing_left
		_aim_direction = aim_direction
		_sync_state.rpc(position, _health, velocity, facing_left, aim_direction, _stun_time)
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

	_update_spell_cast_floor_circle(delta)
	_update_cast_progress_bar()
	_update_name_hover()
	_update_draw_order()
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
	if _attack_time > 0.0 or _stun_time > 0.0 or _cast_time > 0.0:
		return
	var definition := SKILL_CARD_DATABASE.get_definition(skill_name)
	var skill_type := str(definition["type"])
	var cast_time := maxf(float(definition["cast_time"]), 0.0)
	var bubble_text := str(definition["bubble_text"])
	var damage := int(definition["damage"])
	var heal := int(definition["heal"])
	var attack_range := float(definition["range"])
	var cast_origin := global_position
	var cast_direction := _aim_direction
	if multiplayer.multiplayer_peer == null:
		_play_skill(bubble_text, cast_time)
		_play_skill_cast_visuals(skill_type, cast_time)
		if cast_time > 0.0:
			await get_tree().create_timer(cast_time).timeout
		if not is_inside_tree():
			return
		_finish_skill_cast(
			skill_name,
			skill_type,
			damage,
			heal,
			attack_range,
			target_peer_id,
			cast_origin,
			cast_direction,
			cast_time
		)
	elif multiplayer.is_server():
		# Show action bubble above the caster for everyone (like other skills).
		_play_skill.rpc(bubble_text, cast_time)
		_play_skill_cast_visuals_rpc(skill_type, cast_time)
		if cast_time > 0.0:
			await get_tree().create_timer(cast_time).timeout
		if not is_inside_tree():
			return
		_finish_skill_cast(
			skill_name,
			skill_type,
			damage,
			heal,
			attack_range,
			target_peer_id,
			cast_origin,
			cast_direction,
			cast_time
		)
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
	_play_skill("Fireball!", 0.8)
	_play_spell_cast_floor_circle()


@rpc("authority", "call_local", "reliable")
func _play_skill(bubble_text: String, cast_time: float = 0.0) -> void:
	if _attack_time > 0.0 or _cast_time > 0.0:
		return
	if cast_time > 0.0:
		_start_cast_progress(cast_time)
	else:
		_attack_time = float(FRAME_COUNT) / ATTACK_FPS
		_set_animation("attack")
	attack_marker.visible = false
	_show_chat_bubble(bubble_text, ACTION_BUBBLE_SECONDS)


func _play_skill_cast_visuals(skill_type: String, cast_time: float) -> void:
	if skill_type == "spell":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), SPELL_CAST_COLOR)
	elif skill_type == "heal":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), HEAL_CAST_COLOR)


func _play_skill_cast_visuals_rpc(skill_type: String, cast_time: float) -> void:
	if skill_type == "spell":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), SPELL_CAST_COLOR)
	elif skill_type == "heal":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), HEAL_CAST_COLOR)


func _finish_skill_cast(
	skill_name: String,
	skill_type: String,
	damage: int,
	heal: int,
	attack_range: float,
	target_peer_id: int,
	cast_origin: Vector2,
	cast_direction: Vector2,
	cast_time: float
) -> void:
	if cast_time > 0.0:
		if multiplayer.multiplayer_peer == null:
			_play_skill_release_animation()
		else:
			_play_skill_release_animation.rpc()
	if skill_name == "fireball":
		if multiplayer.multiplayer_peer == null:
			_play_fireball_projectile(cast_origin, cast_direction, damage)
		else:
			_play_fireball_projectile.rpc(cast_origin, cast_direction, damage)
	_apply_skill_effect(skill_name, skill_type, damage, heal, attack_range, target_peer_id)


@rpc("authority", "call_local", "reliable")
func _play_skill_release_animation() -> void:
	_cast_time = 0.0
	_set_cast_progress_visible(false)
	_attack_time = float(FRAME_COUNT) / ATTACK_FPS
	_set_animation("attack")


@rpc("authority", "call_local", "reliable")
func _play_spell_cast_floor_circle(
	duration: float = SPELL_CAST_SECONDS,
	circle_color: Color = SPELL_CAST_COLOR
) -> void:
	_spell_cast_duration = maxf(duration, 0.01)
	_spell_cast_time = _spell_cast_duration
	_spell_cast_color = circle_color
	_set_spell_cast_floor_visible(true)


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
	aim_direction: Vector2,
	stun_time: float
) -> void:
	position = server_position
	_update_draw_order()
	_health = server_health
	_visual_velocity = server_velocity
	_facing_left = facing_left
	_aim_direction = aim_direction.normalized()
	_stun_time = stun_time
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

	var healing_done := mini(maxi(amount, 0), _max_health - _health)
	_health += healing_done
	health_bar.value = _health
	if healing_done > 0:
		if multiplayer.multiplayer_peer == null:
			_show_heal_number(healing_done)
		else:
			_show_heal_number.rpc(healing_done)
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

	var damage_dealt := mini(maxi(amount, 0), _health)
	_health = maxi(_health - amount, 0)
	health_bar.value = _health
	if damage_dealt > 0:
		if multiplayer.multiplayer_peer == null:
			_show_damage_number(damage_dealt)
		else:
			_show_damage_number.rpc(damage_dealt)
	if amount > 0:
		_stun_time = max(_stun_time, STUN_SECONDS)


func _read_input() -> Vector2:
	if _cast_time > 0.0:
		return Vector2.ZERO

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
	var frame_count := FRAME_COUNT

	if _stun_time > 0.0 and hurt_texture != null:
		animation_name = "hurt"
		fps = HURT_FPS
		frame_count = HURT_FRAME_COUNT
	elif _attack_time > 0.0 and attack_texture != null:
		animation_name = "attack"
		fps = ATTACK_FPS
		frame_count = FRAME_COUNT

	_set_animation(animation_name)
	sprite.flip_h = _facing_left

	_animation_time += delta * fps
	if animation_name == "attack":
		sprite.frame = min(int(_animation_time), frame_count - 1)
	else:
		sprite.frame = int(_animation_time) % frame_count


func _set_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return

	_current_animation = animation_name
	_animation_time = 0.0
	if animation_name == "attack" and attack_texture != null:
		sprite.texture = attack_texture
		sprite.hframes = FRAME_COUNT
	elif animation_name == "hurt" and hurt_texture != null:
		sprite.texture = hurt_texture
		sprite.hframes = HURT_FRAME_COUNT
	elif animation_name == "run" and run_texture != null:
		sprite.texture = run_texture
		sprite.hframes = FRAME_COUNT
	elif idle_texture != null:
		sprite.texture = idle_texture
		sprite.hframes = FRAME_COUNT
	sprite.frame = 0


func _update_name_hover() -> void:
	name_label.visible = HOVER_RECT.has_point(to_local(get_global_mouse_position()))


@rpc("authority", "call_local", "reliable")
func _show_damage_number(amount: int) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	FLOATING_COMBAT_TEXT.spawn_damage(parent, global_position, amount)


@rpc("authority", "call_local", "reliable")
func _show_heal_number(amount: int) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	FLOATING_COMBAT_TEXT.spawn_heal(parent, global_position, amount)


func _update_draw_order() -> void:
	z_index = clampi(
		int(round(global_position.y + DRAW_ORDER_FOOT_OFFSET)),
		DRAW_ORDER_MIN,
		DRAW_ORDER_MAX
	)


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
	_chat_bubble_box.offset_left = -34.0
	_chat_bubble_box.offset_top = -90.0
	_chat_bubble_box.offset_right = 34.0
	_chat_bubble_box.offset_bottom = -72.0

	var bubble_style := StyleBoxFlat.new()
	bubble_style.bg_color = Color(0.12, 0.09, 0.06, 0.94)
	bubble_style.border_color = Color(0.74, 0.55, 0.28, 0.95)
	bubble_style.border_width_left = 1
	bubble_style.border_width_top = 1
	bubble_style.border_width_right = 1
	bubble_style.border_width_bottom = 1
	bubble_style.corner_radius_top_left = 3
	bubble_style.corner_radius_top_right = 3
	bubble_style.corner_radius_bottom_left = 3
	bubble_style.corner_radius_bottom_right = 3
	_chat_bubble_box.add_theme_stylebox_override("panel", bubble_style)
	add_child(_chat_bubble_box)

	var chat_margin := MarginContainer.new()
	chat_margin.add_theme_constant_override("margin_left", 4)
	chat_margin.add_theme_constant_override("margin_right", 4)
	chat_margin.add_theme_constant_override("margin_top", 1)
	chat_margin.add_theme_constant_override("margin_bottom", 1)
	_chat_bubble_box.add_child(chat_margin)

	_chat_bubble = Label.new()
	_chat_bubble.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_chat_bubble.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_chat_bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_chat_bubble.add_theme_color_override("font_color", Color(0.96, 0.86, 0.62))
	_chat_bubble.add_theme_font_size_override("font_size", 8)
	chat_margin.add_child(_chat_bubble)

	_chat_bubble_tail = Polygon2D.new()
	_chat_bubble_tail.visible = false
	_chat_bubble_tail.z_index = 19
	_chat_bubble_tail.color = Color(0.12, 0.09, 0.06, 0.94)
	_chat_bubble_tail.polygon = PackedVector2Array([
		Vector2(-4.0, -73.0),
		Vector2(5.0, -73.0),
		Vector2(0.0, -66.0),
	])
	add_child(_chat_bubble_tail)

	_chat_bubble_tail_outline = Line2D.new()
	_chat_bubble_tail_outline.visible = false
	_chat_bubble_tail_outline.z_index = 21
	_chat_bubble_tail_outline.width = 1.0
	_chat_bubble_tail_outline.default_color = Color(0.74, 0.55, 0.28, 0.95)
	_chat_bubble_tail_outline.points = PackedVector2Array([
		Vector2(-4.0, -73.0),
		Vector2(0.0, -66.0),
		Vector2(5.0, -73.0),
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


func _build_cast_progress_bar() -> void:
	_cast_progress_bar = ProgressBar.new()
	_cast_progress_bar.visible = false
	_cast_progress_bar.z_index = 22
	_cast_progress_bar.show_percentage = false
	_cast_progress_bar.max_value = 1.0
	_cast_progress_bar.value = 0.0
	_cast_progress_bar.offset_left = -22.0
	_cast_progress_bar.offset_top = -70.0
	_cast_progress_bar.offset_right = 22.0
	_cast_progress_bar.offset_bottom = -66.0

	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.06, 0.04, 0.88)
	background_style.corner_radius_top_left = 2
	background_style.corner_radius_top_right = 2
	background_style.corner_radius_bottom_left = 2
	background_style.corner_radius_bottom_right = 2
	_cast_progress_bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.22, 0.62, 1.0, 0.96)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	_cast_progress_bar.add_theme_stylebox_override("fill", fill_style)
	add_child(_cast_progress_bar)


func _start_cast_progress(duration: float) -> void:
	_cast_duration = maxf(duration, 0.01)
	_cast_time = _cast_duration
	if _cast_progress_bar != null:
		_cast_progress_bar.value = 0.0
		_set_cast_progress_visible(true)


func _update_cast_progress_bar() -> void:
	if _cast_progress_bar == null or _cast_duration <= 0.0:
		return
	if _cast_time <= 0.0:
		_cast_progress_bar.value = 1.0
		return

	_cast_progress_bar.value = 1.0 - (_cast_time / _cast_duration)


func _set_cast_progress_visible(is_visible: bool) -> void:
	if _cast_progress_bar != null:
		_cast_progress_bar.visible = is_visible


func _build_spell_cast_floor_circle() -> void:
	_spell_cast_floor_root = Node2D.new()
	_spell_cast_floor_root.z_index = -1
	_spell_cast_floor_root.y_sort_enabled = false
	add_child(_spell_cast_floor_root)

	_spell_cast_fill = Polygon2D.new()
	_spell_cast_fill.visible = false
	_spell_cast_fill.color = Color(1.0, 1.0, 1.0, 0.18)
	_spell_cast_floor_root.add_child(_spell_cast_fill)

	_spell_cast_ring = Line2D.new()
	_spell_cast_ring.visible = false
	_spell_cast_ring.width = 3.0
	_spell_cast_ring.default_color = Color(1.0, 1.0, 1.0, 0.92)
	_spell_cast_floor_root.add_child(_spell_cast_ring)

	_spell_cast_inner_ring = Line2D.new()
	_spell_cast_inner_ring.visible = false
	_spell_cast_inner_ring.width = 1.5
	_spell_cast_inner_ring.default_color = Color(1.0, 1.0, 1.0, 0.62)
	_spell_cast_floor_root.add_child(_spell_cast_inner_ring)

	_spell_cast_rune_ring = Line2D.new()
	_spell_cast_rune_ring.visible = false
	_spell_cast_rune_ring.width = 1.0
	_spell_cast_rune_ring.default_color = Color(1.0, 1.0, 1.0, 0.56)
	_spell_cast_floor_root.add_child(_spell_cast_rune_ring)

	_spell_cast_marks.clear()
	for _index in range(SPELL_CAST_MARK_COUNT):
		var mark := Line2D.new()
		mark.visible = false
		mark.width = 2.0
		mark.default_color = Color(1.0, 1.0, 1.0, 0.72)
		_spell_cast_marks.append(mark)
		_spell_cast_floor_root.add_child(mark)


func _update_spell_cast_floor_circle(delta: float) -> void:
	if _spell_cast_time <= 0.0:
		return

	_spell_cast_time = maxf(_spell_cast_time - delta, 0.0)
	if _spell_cast_time <= 0.0:
		_set_spell_cast_floor_visible(false)
		return

	var progress := 1.0 - (_spell_cast_time / _spell_cast_duration)
	var pulse := 1.0 + sin(progress * PI) * 0.18
	var fade := maxf(sin(progress * PI), 0.48)
	var radius := SPELL_CAST_FLOOR_RADIUS * pulse
	var radii := Vector2(radius, radius * SPELL_CAST_FLOOR_Y_SCALE)
	var center := SPELL_CAST_FLOOR_OFFSET
	var spin := float(Time.get_ticks_msec()) * 0.0032

	if _spell_cast_fill != null:
		_spell_cast_fill.color = Color(
			_spell_cast_color.r,
			_spell_cast_color.g,
			_spell_cast_color.b,
			0.16 * fade
		)
		_spell_cast_fill.polygon = _make_spell_cast_ellipse_polygon(
			center,
			radii * 0.96,
			SPELL_CAST_FLOOR_SEGMENTS
		)

	_spell_cast_ring.default_color = Color(
		_spell_cast_color.r,
		_spell_cast_color.g,
		_spell_cast_color.b,
		0.86 * fade
	)
	_update_spell_cast_ellipse_ring_points(_spell_cast_ring, center, radii, SPELL_CAST_FLOOR_SEGMENTS)
	_spell_cast_inner_ring.default_color = Color(
		_spell_cast_color.r,
		_spell_cast_color.g,
		_spell_cast_color.b,
		0.58 * fade
	)
	_update_spell_cast_ellipse_ring_points(
		_spell_cast_inner_ring,
		center,
		radii * 0.66,
		SPELL_CAST_FLOOR_SEGMENTS
	)
	_spell_cast_rune_ring.default_color = Color(
		_spell_cast_color.r,
		_spell_cast_color.g,
		_spell_cast_color.b,
		0.48 * fade
	)
	_update_spell_cast_rotated_ellipse_ring_points(
		_spell_cast_rune_ring,
		center,
		radii * 0.82,
		SPELL_CAST_FLOOR_SEGMENTS,
		spin
	)
	_update_spell_cast_marks(center, radii, spin, fade)


func _set_spell_cast_floor_visible(is_visible: bool) -> void:
	if _spell_cast_fill != null:
		_spell_cast_fill.visible = is_visible
	if _spell_cast_ring != null:
		_spell_cast_ring.visible = is_visible
	if _spell_cast_inner_ring != null:
		_spell_cast_inner_ring.visible = is_visible
	if _spell_cast_rune_ring != null:
		_spell_cast_rune_ring.visible = is_visible
	for mark in _spell_cast_marks:
		mark.visible = is_visible


func _update_spell_cast_marks(center: Vector2, radii: Vector2, spin: float, fade: float) -> void:
	for index in range(_spell_cast_marks.size()):
		var angle := spin + TAU * float(index) / float(_spell_cast_marks.size())
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * radii * 0.74
		var outer := center + direction * radii * 0.98
		_spell_cast_marks[index].default_color = Color(
			_spell_cast_color.r,
			_spell_cast_color.g,
			_spell_cast_color.b,
			0.70 * fade
		)
		_spell_cast_marks[index].points = PackedVector2Array([inner, outer])


func _make_spell_cast_ellipse_polygon(
	center: Vector2,
	radii: Vector2,
	segment_count: int
) -> PackedVector2Array:
	var points := PackedVector2Array([center])
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _update_spell_cast_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_spell_cast_rotated_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int,
	rotation: float
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := rotation + TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points
