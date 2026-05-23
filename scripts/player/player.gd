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
@export var cast_texture: Texture2D
@export var hurt_texture: Texture2D
@export var idle_frame_count := 8
@export var run_frame_count := 8
@export var attack_frame_count := 8
@export var cast_frame_count := 8
@export var hurt_frame_count := 2
@export var idle_hframes := 8
@export var run_hframes := 8
@export var attack_hframes := 8
@export var cast_hframes := 8
@export var hurt_hframes := 2
@export var idle_vframes := 1
@export var run_vframes := 1
@export var attack_vframes := 1
@export var cast_vframes := 1
@export var hurt_vframes := 1
@export var use_direction_rows := false
@export var direction_row_up := 0
@export var direction_row_left := 0
@export var direction_row_down := 0
@export var direction_row_right := 0
@export var dead_frame_index := 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var attack_marker: ColorRect = $AttackMarker
@onready var camera: Camera2D = $Camera2D

const IDLE_FPS := 4.0
const RUN_FPS := 10.0
const ATTACK_FPS := 14.0
const CAST_FPS := 8.0
const HURT_FPS := 8.0
const CHAT_BUBBLE_SECONDS := 4.0
const ACTION_BUBBLE_SECONDS := 1.0
const HOVER_RECT := Rect2(Vector2(-32.0, -48.0), Vector2(64.0, 112.0))
const STRIKE_SKILL_NAME := "strike"
const SWIFT_RAID_SKILL_NAME := "swift_raid"
const FAST_BOI_SKILL_NAME := "fast_boi"
const WAIT_BOI_SKILL_NAME := "wait_boi"
const STRIKE_ATTACK_FORWARD_OFFSET := 28.0
const SWIFT_RAID_HIT_COUNT := 3
const SWIFT_RAID_FORWARD_OFFSET := 22.0
const SWIFT_RAID_WIDTH := 46.0
const FIREBALL_PROJECTILE_FORWARD_OFFSET := 18.0
const STUN_SECONDS := 0.3
const DRAW_ORDER_FOOT_OFFSET := 34.0
const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4095
const SPELL_CAST_FLOOR_OFFSET := Vector2(0.0, 46.0)
const SPELL_CAST_FLOOR_RADIUS := 34.0
const SPELL_CAST_FLOOR_Y_SCALE := 0.52
const SPELL_CAST_FLOOR_SEGMENTS := 48
const SPELL_CAST_MARK_COUNT := 12
const SPELL_CAST_SECONDS := 0.46
const SPELL_CAST_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const HEAL_CAST_COLOR := Color(0.42, 1.0, 0.58, 1.0)
const BUFF_CAST_COLOR := Color(0.32, 0.72, 1.0, 1.0)
const DEBUFF_CAST_COLOR := Color(0.74, 0.38, 1.0, 1.0)
const REVIVE_WAIT_SECONDS := 3.0
const REVIVE_HEALTH_RATIO := 1.0
const REVIVE_FALLBACK_POSITION := Vector2(240, 220)
const SPAWN_ANCHOR_NODE_NAME := "SpawnAnchor"

var _server_input := Vector2.ZERO
var _health := 100
var _max_health := 100
var _is_dead := false
var _revive_wait_time := 0.0
var _attack_time := 0.0
var _stun_time := 0.0
var _cast_time := 0.0
var _cast_duration := 0.0
var _cast_interrupt_id := 0
var _spell_cast_time := 0.0
var _spell_cast_duration := SPELL_CAST_SECONDS
var _spell_cast_color := SPELL_CAST_COLOR
var _chat_bubble_time := 0.0
var _animation_time := 0.0
var _current_animation := ""
var _visual_velocity := Vector2.ZERO
var _visual_facing_direction := Vector2.RIGHT
var _server_facing_left := false
var _server_aim_direction := Vector2.RIGHT
var _server_is_skill_aiming_active := false
var _facing_left := false
var _aim_direction := Vector2.RIGHT
var _is_skill_aiming_active := false
var _skill_facing_lock_time := 0.0
var _skill_facing_lock_left := false
var _fast_boi_time := 0.0
var _fast_boi_duration := 0.0
var _fast_boi_speed_multiplier := 1.0
var _wait_boi_time := 0.0
var _wait_boi_duration := 0.0
var _wait_boi_speed_multiplier := 1.0
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
var _death_overlay_layer: CanvasLayer
var _death_overlay: PanelContainer
var _death_message: Label
var _revive_button: Button


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
	sprite.hframes = idle_hframes
	sprite.vframes = idle_vframes
	_set_animation("idle")
	_build_spell_cast_floor_circle()
	_build_cast_progress_bar()
	camera.enabled = _is_local_player()
	if camera.enabled:
		camera.make_current()
	_build_chat_bubble()
	if _is_local_player():
		_build_death_overlay()
	NetworkManager.chat_message_received.connect(_on_chat_message_received)


func _physics_process(delta: float) -> void:
	_update_death_overlay(delta)

	if _stun_time > 0.0:
		_stun_time = max(_stun_time - delta, 0.0)
	if _cast_time > 0.0:
		_cast_time = maxf(_cast_time - delta, 0.0)
		if _cast_time <= 0.0:
			_set_cast_progress_visible(false)
	if _skill_facing_lock_time > 0.0:
		_skill_facing_lock_time = maxf(_skill_facing_lock_time - delta, 0.0)
	if _fast_boi_time > 0.0:
		_fast_boi_time = maxf(_fast_boi_time - delta, 0.0)
		if _fast_boi_time <= 0.0:
			_fast_boi_duration = 0.0
			_fast_boi_speed_multiplier = 1.0
	if _wait_boi_time > 0.0:
		_wait_boi_time = maxf(_wait_boi_time - delta, 0.0)
		if _wait_boi_time <= 0.0:
			_wait_boi_duration = 0.0
			_wait_boi_speed_multiplier = 1.0

	if multiplayer.is_server():
		var input_vector := _server_input
		var facing_left := _server_facing_left
		var aim_direction := _server_aim_direction
		var is_skill_aiming_active := _server_is_skill_aiming_active
		if peer_id == multiplayer.get_unique_id():
			input_vector = _read_input()
			aim_direction = _read_mouse_aim_direction()
			is_skill_aiming_active = _is_skill_aiming_active
			facing_left = _resolve_facing_left(input_vector, aim_direction, _facing_left)

		var visual_facing_direction := _resolve_visual_facing_direction(
			input_vector,
			aim_direction,
			is_skill_aiming_active
		)
		if _is_dead or _stun_time > 0.0 or _cast_time > 0.0:
			input_vector = Vector2.ZERO

		velocity = input_vector * speed * _get_move_speed_multiplier()
		if not _is_dead:
			move_and_slide()
		else:
			velocity = Vector2.ZERO
		_visual_velocity = velocity
		_visual_facing_direction = visual_facing_direction
		_facing_left = facing_left
		_aim_direction = aim_direction
		_sync_state.rpc(
			position,
			_health,
			velocity,
			facing_left,
			aim_direction,
			_stun_time,
			_fast_boi_time,
			_fast_boi_duration,
			_wait_boi_time,
			_wait_boi_duration,
			_visual_facing_direction
		)
	else:
		if _is_local_player():
			_aim_direction = _read_mouse_aim_direction()
			var input_vector := _read_input()
			_facing_left = _resolve_facing_left(input_vector, _aim_direction, _facing_left)
			_visual_facing_direction = _resolve_visual_facing_direction(
				input_vector,
				_aim_direction,
				_is_skill_aiming_active
			)
			_send_input.rpc_id(1, input_vector, _facing_left, _aim_direction, _is_skill_aiming_active)

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
	if _is_dead:
		return


func try_attack() -> void:
	try_skill("strike")


func try_fireball() -> void:
	try_skill("fireball")


func set_skill_aiming_active(is_active: bool) -> void:
	_is_skill_aiming_active = is_active


func try_skill(skill_name: String, target_peer_id: int = -1) -> void:
	if _is_dead:
		return
	if _attack_time > 0.0 or _stun_time > 0.0 or _cast_time > 0.0:
		return
	var definition := SKILL_CARD_DATABASE.get_definition(skill_name)
	var skill_type := str(definition["type"])
	var cast_time := maxf(float(definition["cast_time"]), 0.0)
	var bubble_text := str(definition["bubble_text"])
	var damage := int(definition["damage"])
	var heal := int(definition["heal"])
	var attack_range := float(definition["range"])
	var buff_speed_percent := float(definition["buff_speed_percent"])
	var buff_duration := float(definition["buff_duration"])
	var cast_origin := global_position
	var cast_direction := _aim_direction
	if cast_direction.length_squared() <= 0.0:
		cast_direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var cast_interrupt_id := _cast_interrupt_id
	if cast_time > 0.0:
		_cast_interrupt_id += 1
		cast_interrupt_id = _cast_interrupt_id
	var facing_lock_duration := cast_time + _attack_animation_seconds()
	if skill_name == SWIFT_RAID_SKILL_NAME:
		facing_lock_duration = cast_time + (_attack_animation_seconds() * SWIFT_RAID_HIT_COUNT)
	_lock_skill_facing(cast_direction, facing_lock_duration)
	if multiplayer.multiplayer_peer == null:
		_play_skill(bubble_text, cast_time)
		_play_skill_cast_visuals(skill_type, cast_time)
		if cast_time > 0.0:
			await get_tree().create_timer(cast_time).timeout
			if cast_interrupt_id != _cast_interrupt_id:
				return
		if not is_inside_tree():
			return
		_finish_skill_cast(
			skill_name,
			skill_type,
			damage,
			heal,
			attack_range,
			buff_speed_percent,
			buff_duration,
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
			if cast_interrupt_id != _cast_interrupt_id:
				return
		if not is_inside_tree():
			return
		_finish_skill_cast(
			skill_name,
			skill_type,
			damage,
			heal,
			attack_range,
			buff_speed_percent,
			buff_duration,
			target_peer_id,
			cast_origin,
			cast_direction,
			cast_time
		)
	else:
		_request_skill.rpc_id(1, skill_name, target_peer_id)


@rpc("any_peer", "unreliable")
func _send_input(
	input_vector: Vector2,
	facing_left: bool,
	aim_direction: Vector2,
	is_skill_aiming_active: bool = false
) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_input = input_vector.limit_length(1.0)
	_server_facing_left = facing_left
	_server_aim_direction = aim_direction.normalized()
	_server_is_skill_aiming_active = is_skill_aiming_active


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
		_set_animation("cast")
	else:
		_attack_time = _attack_animation_seconds()
		_set_animation("attack")
	attack_marker.visible = false
	_show_chat_bubble(bubble_text, ACTION_BUBBLE_SECONDS)


func _play_skill_cast_visuals(skill_type: String, cast_time: float) -> void:
	if skill_type == "spell":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), SPELL_CAST_COLOR)
	elif skill_type == "heal":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), HEAL_CAST_COLOR)
	elif skill_type == "buff":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), BUFF_CAST_COLOR)
	elif skill_type == "debuff":
		_play_spell_cast_floor_circle(maxf(cast_time, SPELL_CAST_SECONDS), DEBUFF_CAST_COLOR)


func _play_skill_cast_visuals_rpc(skill_type: String, cast_time: float) -> void:
	if skill_type == "spell":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), SPELL_CAST_COLOR)
	elif skill_type == "heal":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), HEAL_CAST_COLOR)
	elif skill_type == "buff":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), BUFF_CAST_COLOR)
	elif skill_type == "debuff":
		_play_spell_cast_floor_circle.rpc(maxf(cast_time, SPELL_CAST_SECONDS), DEBUFF_CAST_COLOR)


func _finish_skill_cast(
	skill_name: String,
	skill_type: String,
	damage: int,
	heal: int,
	attack_range: float,
	buff_speed_percent: float,
	buff_duration: float,
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
	_apply_skill_effect(
		skill_name,
		skill_type,
		damage,
		heal,
		attack_range,
		buff_speed_percent,
		buff_duration,
		target_peer_id
	)


@rpc("authority", "call_local", "reliable")
func _play_skill_release_animation() -> void:
	_cast_time = 0.0
	_set_cast_progress_visible(false)
	_attack_time = _attack_animation_seconds()
	_set_animation("attack")


@rpc("authority", "call_local", "reliable")
func _cancel_active_cast() -> void:
	if _cast_time <= 0.0:
		return

	_cast_interrupt_id += 1
	_cast_time = 0.0
	_cast_duration = 0.0
	_spell_cast_time = 0.0
	_set_cast_progress_visible(false)
	_set_spell_cast_floor_visible(false)


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
	stun_time: float,
	fast_boi_time: float = 0.0,
	fast_boi_duration: float = 0.0,
	wait_boi_time: float = 0.0,
	wait_boi_duration: float = 0.0,
	visual_facing_direction: Vector2 = Vector2.RIGHT
) -> void:
	position = server_position
	_update_draw_order()
	_health = server_health
	_set_dead(_health <= 0)
	_visual_velocity = server_velocity
	_facing_left = facing_left
	_aim_direction = aim_direction.normalized()
	if visual_facing_direction.length_squared() > 0.01:
		_visual_facing_direction = visual_facing_direction.normalized()
	_stun_time = stun_time
	_fast_boi_time = maxf(fast_boi_time, 0.0)
	_fast_boi_duration = maxf(fast_boi_duration, 0.0)
	_fast_boi_speed_multiplier = 1.15 if _fast_boi_time > 0.0 else 1.0
	_wait_boi_time = maxf(wait_boi_time, 0.0)
	_wait_boi_duration = maxf(wait_boi_duration, 0.0)
	_wait_boi_speed_multiplier = 0.85 if _wait_boi_time > 0.0 else 1.0
	health_bar.value = _health


func _apply_test_attack_damage() -> void:
	var definition := SKILL_CARD_DATABASE.get_definition("strike")
	_apply_test_skill_damage(STRIKE_SKILL_NAME, int(definition["damage"]), float(definition["range"]))


func _apply_test_skill_damage(skill_name: String, amount: int, attack_range: float) -> void:
	var targets := _find_test_attack_targets(skill_name, attack_range)
	if targets.is_empty():
		return

	for target in targets:
		target.call("_take_test_damage", amount, self)


func _apply_skill_effect(
	skill_name: String,
	skill_type: String,
	damage: int,
	heal: int,
	attack_range: float,
	buff_speed_percent: float,
	buff_duration: float,
	target_peer_id: int = -1
) -> void:
	if skill_type == "heal":
		_heal_target(heal, target_peer_id)
		return
	if skill_type == "buff":
		_apply_buff_skill(skill_name, buff_speed_percent, buff_duration, target_peer_id)
		return
	if skill_type == "debuff":
		_apply_debuff_skill(skill_name, buff_speed_percent, buff_duration, target_peer_id)
		return

	if skill_name == "fireball":
		return
	if skill_name == SWIFT_RAID_SKILL_NAME:
		_apply_swift_raid_damage(damage, attack_range)
		return

	_apply_test_skill_damage(skill_name, damage, attack_range)


func _apply_buff_skill(
	skill_name: String,
	buff_speed_percent: float,
	buff_duration: float,
	target_peer_id: int = -1
) -> void:
	if skill_name != FAST_BOI_SKILL_NAME or buff_duration <= 0.0:
		return

	var target := _find_player_skill_target(target_peer_id)
	if target == null or not target.has_method("_receive_fast_boi_buff"):
		return

	target.call("_receive_fast_boi_buff", buff_speed_percent, buff_duration)


func _apply_debuff_skill(
	skill_name: String,
	debuff_speed_percent: float,
	debuff_duration: float,
	target_id: int = -1
) -> void:
	if skill_name != WAIT_BOI_SKILL_NAME or debuff_duration <= 0.0:
		return

	var target := _find_debuff_target(target_id)
	if target == null or not target.has_method("_receive_wait_boi_debuff"):
		return

	target.call("_receive_wait_boi_debuff", debuff_speed_percent, debuff_duration)


func _receive_fast_boi_buff(buff_speed_percent: float, buff_duration: float) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return
	if _is_dead:
		return

	_fast_boi_duration = buff_duration
	_fast_boi_time = buff_duration
	_fast_boi_speed_multiplier = 1.0 + maxf(buff_speed_percent, 0.0) / 100.0


func _receive_wait_boi_debuff(debuff_speed_percent: float, debuff_duration: float) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return
	if _is_dead:
		return

	_wait_boi_duration = debuff_duration
	_wait_boi_time = debuff_duration
	_wait_boi_speed_multiplier = maxf(1.0 - maxf(debuff_speed_percent, 0.0) / 100.0, 0.0)


func _get_move_speed_multiplier() -> float:
	var multiplier := _fast_boi_speed_multiplier if _fast_boi_time > 0.0 else 1.0
	if _wait_boi_time > 0.0:
		multiplier *= _wait_boi_speed_multiplier
	return multiplier


func _apply_swift_raid_damage(amount: int, attack_range: float) -> void:
	var hit_interval := _attack_animation_seconds()
	for hit_index in range(SWIFT_RAID_HIT_COUNT):
		if hit_index > 0:
			await get_tree().create_timer(hit_interval).timeout
		if not is_inside_tree():
			return
		var target := _find_swift_raid_target(attack_range)
		if target != null:
			target.call("_take_test_damage", amount, self)
		if multiplayer.multiplayer_peer == null:
			_play_swift_raid_hit_animation()
		elif multiplayer.is_server():
			_play_swift_raid_hit_animation.rpc()


@rpc("authority", "call_local", "reliable")
func _play_swift_raid_hit_animation() -> void:
	_cast_time = 0.0
	_set_cast_progress_visible(false)
	_attack_time = _attack_animation_seconds()
	if _current_animation == "attack":
		_current_animation = ""
	_set_animation("attack")


func _find_swift_raid_target(attack_range: float) -> Node:
	var forward := _aim_direction.normalized()
	if forward.length_squared() <= 0.0:
		forward = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var attack_origin := global_position + forward * SWIFT_RAID_FORWARD_OFFSET
	var closest_target: Node = null
	var closest_forward_distance := attack_range

	for node in get_tree().get_nodes_in_group("damageable"):
		if node == self or not node.has_method("_take_test_damage"):
			continue

		var target := node as Node2D
		if target == null:
			continue
		if int(node.get("_health")) <= 0:
			continue

		var to_target := target.global_position - attack_origin
		var forward_distance := to_target.dot(forward)
		if forward_distance < 0.0 or forward_distance > attack_range:
			continue

		var side_distance := absf(to_target.cross(forward))
		if side_distance > SWIFT_RAID_WIDTH:
			continue

		if closest_target == null or forward_distance < closest_forward_distance:
			closest_target = node
			closest_forward_distance = forward_distance

	return closest_target


func _heal_target(amount: int, target_peer_id: int = -1) -> void:
	if amount <= 0:
		return

	var target := _find_heal_target(target_peer_id)
	if target == null or not target.has_method("_receive_heal"):
		return

	target.call("_receive_heal", amount)


func _find_heal_target(target_peer_id: int = -1) -> Node:
	return _find_player_skill_target(target_peer_id)


func _find_player_skill_target(target_peer_id: int = -1) -> Node:
	var players := get_parent()
	if players == null:
		return self

	if target_peer_id >= 0:
		var target := players.get_node_or_null(str(target_peer_id))
		if target != null:
			return target

	return self


func _find_debuff_target(target_id: int = -1) -> Node:
	var players := get_parent()
	if players == null:
		return null

	if target_id >= 0:
		var player_target := players.get_node_or_null(str(target_id))
		if player_target != null and player_target != self:
			return player_target
		return null

	if target_id <= -2:
		var world := players.get_parent()
		if world == null:
			return null
		var enemies := world.get_node_or_null("Enemies")
		if enemies == null:
			return null
		var enemy_index := -target_id - 2
		if enemy_index < 0 or enemy_index >= enemies.get_child_count():
			return null
		return enemies.get_child(enemy_index)

	return null


func _receive_heal(amount: int) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return
	if _is_dead:
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


func _find_test_attack_targets(skill_name: String, attack_range: float) -> Array[Node]:
	var targets: Array[Node] = []
	var forward := _aim_direction.normalized()
	if forward.length_squared() <= 0.0:
		forward = Vector2.LEFT if _facing_left else Vector2.RIGHT
	var attack_origin := global_position
	if skill_name == STRIKE_SKILL_NAME:
		attack_origin += forward * STRIKE_ATTACK_FORWARD_OFFSET
	var max_distance_squared := attack_range * attack_range
	var closest_target: Node = null
	var closest_distance_squared := max_distance_squared
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
		if distance_squared > max_distance_squared:
			continue

		if skill_name == STRIKE_SKILL_NAME:
			targets.append(node)
		elif distance_squared <= closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = node

	if skill_name != STRIKE_SKILL_NAME and closest_target != null:
		targets.append(closest_target)
	return targets


func _take_test_damage(amount: int, _attacker: Node = null) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return
	if _is_dead:
		return

	var damage_dealt := mini(maxi(amount, 0), _health)
	_health = maxi(_health - amount, 0)
	health_bar.value = _health
	if damage_dealt > 0:
		if _cast_time > 0.0:
			if multiplayer.multiplayer_peer == null:
				_cancel_active_cast()
			else:
				_cancel_active_cast.rpc()
		if multiplayer.multiplayer_peer == null:
			_show_damage_number(damage_dealt)
		else:
			_show_damage_number.rpc(damage_dealt)
	if _health <= 0:
		_die()
	if amount > 0:
		_stun_time = max(_stun_time, STUN_SECONDS)


func _read_input() -> Vector2:
	if _is_dead or _cast_time > 0.0:
		return Vector2.ZERO

	var focused_control := get_viewport().gui_get_focus_owner()
	if focused_control is LineEdit or focused_control is TextEdit:
		return Vector2.ZERO

	return Input.get_vector("move_left", "move_right", "move_up", "move_down").limit_length(1.0)


func _is_local_player() -> bool:
	return peer_id == multiplayer.get_unique_id()


func _update_animation(delta: float) -> void:
	if _is_dead:
		_set_animation("dead")
		sprite.flip_h = _should_flip_sprite()
		_set_sprite_animation_frame("dead", dead_frame_index)
		return

	var is_running := _visual_velocity.length_squared() > 1.0
	var animation_name := "run" if is_running else "idle"
	var fps := RUN_FPS if is_running else IDLE_FPS
	var frame_count := run_frame_count if is_running else idle_frame_count

	if _stun_time > 0.0 and hurt_texture != null:
		animation_name = "hurt"
		fps = HURT_FPS
		frame_count = hurt_frame_count
	elif _cast_time > 0.0 and cast_texture != null:
		animation_name = "cast"
		fps = CAST_FPS
		frame_count = cast_frame_count
	elif _attack_time > 0.0 and attack_texture != null:
		animation_name = "attack"
		fps = ATTACK_FPS
		frame_count = attack_frame_count

	_set_animation(animation_name)
	sprite.flip_h = _should_flip_sprite()

	_animation_time += delta * fps
	if animation_name == "attack":
		_set_sprite_animation_frame(animation_name, min(int(_animation_time), frame_count - 1))
	else:
		_set_sprite_animation_frame(animation_name, int(_animation_time) % frame_count)


func _set_animation(animation_name: String) -> void:
	if _current_animation == animation_name:
		return

	_current_animation = animation_name
	_animation_time = 0.0
	if animation_name == "attack" and attack_texture != null:
		sprite.texture = attack_texture
		sprite.hframes = attack_hframes
		sprite.vframes = attack_vframes
	elif animation_name == "cast" and cast_texture != null:
		sprite.texture = cast_texture
		sprite.hframes = cast_hframes
		sprite.vframes = cast_vframes
	elif animation_name == "hurt" and hurt_texture != null:
		sprite.texture = hurt_texture
		sprite.hframes = hurt_hframes
		sprite.vframes = hurt_vframes
	elif animation_name == "dead":
		if hurt_texture != null:
			sprite.texture = hurt_texture
			sprite.hframes = hurt_hframes
			sprite.vframes = hurt_vframes
		elif idle_texture != null:
			sprite.texture = idle_texture
			sprite.hframes = idle_hframes
			sprite.vframes = idle_vframes
	elif animation_name == "run" and run_texture != null:
		sprite.texture = run_texture
		sprite.hframes = run_hframes
		sprite.vframes = run_vframes
	elif idle_texture != null:
		sprite.texture = idle_texture
		sprite.hframes = idle_hframes
		sprite.vframes = idle_vframes
	_set_sprite_animation_frame(animation_name, 0)
	sprite.rotation_degrees = 0.0


func _set_sprite_animation_frame(animation_name: String, frame_index: int) -> void:
	var safe_frame_index := clampi(frame_index, 0, maxi(sprite.hframes - 1, 0))
	if use_direction_rows and sprite.vframes > 1:
		sprite.frame_coords = Vector2i(safe_frame_index, _get_animation_direction_row(animation_name))
	else:
		sprite.frame = safe_frame_index


func _get_animation_direction_row(animation_name: String) -> int:
	var direction := _get_animation_direction(animation_name)
	var row := direction_row_down
	if absf(direction.x) >= absf(direction.y) and absf(direction.x) > 0.01:
		row = direction_row_left if direction.x < 0.0 else direction_row_right
	elif absf(direction.y) > 0.01:
		row = direction_row_up if direction.y < 0.0 else direction_row_down
	elif _facing_left:
		row = direction_row_left
	else:
		row = direction_row_right
	return clampi(row, 0, maxi(sprite.vframes - 1, 0))


func _get_animation_direction(animation_name: String) -> Vector2:
	if animation_name == "attack" and _skill_facing_lock_time > 0.0:
		return _visual_facing_direction
	if _is_skill_aiming_active and _aim_direction.length_squared() > 0.01:
		return _aim_direction.normalized()
	if animation_name == "run" and _visual_velocity.length_squared() > 1.0:
		return _visual_velocity.normalized()
	if _visual_facing_direction.length_squared() > 0.01:
		return _visual_facing_direction.normalized()
	return Vector2.LEFT if _facing_left else Vector2.RIGHT


func _should_flip_sprite() -> bool:
	return false if use_direction_rows and sprite.vframes > 1 else _facing_left


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


func _resolve_facing_left(input_vector: Vector2, aim_direction: Vector2, fallback_facing_left: bool) -> bool:
	if _skill_facing_lock_time > 0.0:
		return _skill_facing_lock_left
	if _is_skill_aiming_active:
		return aim_direction.x < 0.0
	if absf(input_vector.x) > 0.01:
		return input_vector.x < 0.0
	return fallback_facing_left


func _resolve_visual_facing_direction(
	input_vector: Vector2,
	aim_direction: Vector2,
	is_skill_aiming_active: bool
) -> Vector2:
	if _skill_facing_lock_time > 0.0:
		return _visual_facing_direction
	if is_skill_aiming_active and aim_direction.length_squared() > 0.01:
		return aim_direction.normalized()
	if input_vector.length_squared() > 0.01:
		return input_vector.normalized()
	return _visual_facing_direction


func _lock_skill_facing(direction: Vector2, duration: float) -> void:
	if direction.length_squared() <= 0.0:
		return
	var normalized_direction := direction.normalized()
	_skill_facing_lock_left = normalized_direction.x < 0.0
	_skill_facing_lock_time = maxf(duration, _attack_animation_seconds())
	_facing_left = _skill_facing_lock_left
	_visual_facing_direction = normalized_direction


func _attack_animation_seconds() -> float:
	return float(attack_frame_count) / ATTACK_FPS


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


func _die() -> void:
	if _is_dead:
		return

	_set_dead(true)
	_health = 0
	health_bar.value = _health
	velocity = Vector2.ZERO
	_server_input = Vector2.ZERO
	_attack_time = 0.0
	_cast_time = 0.0
	_stun_time = 0.0
	_fast_boi_time = 0.0
	_fast_boi_duration = 0.0
	_fast_boi_speed_multiplier = 1.0
	_wait_boi_time = 0.0
	_wait_boi_duration = 0.0
	_wait_boi_speed_multiplier = 1.0
	_set_cast_progress_visible(false)
	_set_spell_cast_floor_visible(false)
	if multiplayer.multiplayer_peer != null:
		_sync_state.rpc(
			position,
			_health,
			Vector2.ZERO,
			_facing_left,
			_aim_direction,
			_stun_time,
			_fast_boi_time,
			_fast_boi_duration,
			_wait_boi_time,
			_wait_boi_duration,
			_visual_facing_direction
		)


func _set_dead(is_dead: bool) -> void:
	if _is_dead == is_dead:
		return

	_is_dead = is_dead
	if _is_dead:
		_visual_velocity = Vector2.ZERO
		_revive_wait_time = REVIVE_WAIT_SECONDS
		_set_death_overlay_visible(_is_local_player())
	else:
		_revive_wait_time = 0.0
		_set_death_overlay_visible(false)
		sprite.rotation_degrees = 0.0
		_set_animation("idle")


func _update_death_overlay(delta: float) -> void:
	if not _is_dead:
		return

	if _revive_wait_time > 0.0:
		_revive_wait_time = maxf(_revive_wait_time - delta, 0.0)

	if not _is_local_player():
		return

	if _death_message != null:
		if _revive_wait_time > 0.0:
			_death_message.text = "You died\nRevive available in %d" % ceili(_revive_wait_time)
		else:
			_death_message.text = "You died"
	if _revive_button != null:
		_revive_button.disabled = _revive_wait_time > 0.0
		_revive_button.visible = _revive_wait_time <= 0.0


func _build_death_overlay() -> void:
	_death_overlay_layer = CanvasLayer.new()
	_death_overlay_layer.layer = 60
	add_child(_death_overlay_layer)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_death_overlay_layer.add_child(root)

	_death_overlay = PanelContainer.new()
	_death_overlay.visible = false
	_death_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_death_overlay.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_death_overlay.offset_left = -130.0
	_death_overlay.offset_top = 72.0
	_death_overlay.offset_right = 130.0
	_death_overlay.offset_bottom = 164.0
	root.add_child(_death_overlay)

	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.05, 0.04, 0.94)
	panel_style.border_color = Color(0.72, 0.48, 0.22, 0.96)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	_death_overlay.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_death_overlay.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	_death_message = Label.new()
	_death_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_death_message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_death_message.add_theme_color_override("font_color", Color(1.0, 0.84, 0.55))
	_death_message.add_theme_font_size_override("font_size", 16)
	layout.add_child(_death_message)

	_revive_button = Button.new()
	_revive_button.text = "Revive"
	_revive_button.disabled = true
	_revive_button.visible = false
	_revive_button.pressed.connect(_on_revive_button_pressed)
	layout.add_child(_revive_button)


func _set_death_overlay_visible(is_visible: bool) -> void:
	if _death_overlay != null:
		_death_overlay.visible = is_visible


func _on_revive_button_pressed() -> void:
	if not _is_dead or _revive_wait_time > 0.0:
		return

	if multiplayer.multiplayer_peer == null:
		_revive_at_center()
	elif multiplayer.is_server():
		_revive_at_center()
	else:
		_request_revive.rpc_id(1)


@rpc("any_peer", "reliable")
func _request_revive() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	if not _is_dead or _revive_wait_time > 0.0:
		return

	_revive_at_center()


func _revive_at_center() -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return

	if not _revive_at_crystal_spawn():
		position = _get_center_respawn_position()
	_health = maxi(int(round(float(_max_health) * REVIVE_HEALTH_RATIO)), 1)
	health_bar.value = _health
	velocity = Vector2.ZERO
	_server_input = Vector2.ZERO
	_set_dead(false)
	_update_draw_order()
	if multiplayer.multiplayer_peer != null:
		_sync_state.rpc(
			position,
			_health,
			Vector2.ZERO,
			_facing_left,
			_aim_direction,
			0.0,
			_fast_boi_time,
			_fast_boi_duration,
			_wait_boi_time,
			_wait_boi_duration,
			_visual_facing_direction
		)


func _revive_at_crystal_spawn() -> bool:
	var players_parent := get_parent() as Node2D
	if players_parent == null:
		return false

	var world := players_parent.get_parent()
	if world == null or not world.has_method("revive_player_at_spawn"):
		return false

	return bool(world.call("revive_player_at_spawn", self))


func _get_center_respawn_position() -> Vector2:
	var players_parent := get_parent() as Node2D
	if players_parent == null:
		return REVIVE_FALLBACK_POSITION

	var world := players_parent.get_parent()
	if world == null:
		return REVIVE_FALLBACK_POSITION

	var spawn_point := world.find_child("PlayerSpawnPoint", true, false) as Node2D
	if spawn_point == null:
		return REVIVE_FALLBACK_POSITION

	var spawn_anchor := spawn_point.get_node_or_null(SPAWN_ANCHOR_NODE_NAME) as Node2D
	var respawn_global_position := spawn_anchor.global_position if spawn_anchor != null else spawn_point.global_position
	return players_parent.to_local(respawn_global_position)


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
