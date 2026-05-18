extends CharacterBody2D

const CONFIG_PATH := "res://config/enemies.json"
const FLOATING_COMBAT_TEXT := preload("res://scripts/effects/floating_combat_text.gd")

@export var enemy_id := "e1"
@export var speed := 105.0
@export var attack_range := 46.0
@export var attack_damage := 12
@export var attack_cooldown := 1.2
@export var aggro_range := 230.0
@export var give_up_range := 340.0
@export var give_up_seconds := 0.6
@export var wander_radius := 120.0
@export var wander_speed := 42.0
@export var max_health := 60
@export var idle_texture: Texture2D
@export var run_texture: Texture2D
@export var attack_texture: Texture2D
@export var idle_frame_count := 11
@export var run_frame_count := 8
@export var attack_frame_count := 7
@export var idle_fps := 5.0
@export var run_fps := 10.0
@export var attack_fps := 14.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

const WANDER_WAIT_MIN := 1.2
const WANDER_WAIT_MAX := 3.0
const WANDER_MOVE_MIN := 1.0
const WANDER_MOVE_MAX := 2.4
const STUN_SECONDS := 0.3
const DRAW_ORDER_FOOT_OFFSET := 34.0
const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4096

var _health := 60
var _attack_time := 0.0
var _attack_cooldown_time := 0.0
var _stun_time := 0.0
var _give_up_time := 0.0
var _wander_time := 0.0
var _wait_time := 0.0
var _animation_time := 0.0
var _current_animation := ""
var _home_position := Vector2.ZERO
var _wander_target := Vector2.ZERO
var _facing_left := false
var _visual_velocity := Vector2.ZERO
var _target: Node2D
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	platform_floor_layers = 0
	platform_wall_layers = 0
	_apply_enemy_config()
	add_to_group("damageable")
	z_as_relative = false
	_update_draw_order()
	_rng.randomize()
	_home_position = global_position
	_wait_time = _rng.randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	_health = max_health
	health_bar.max_value = max_health
	health_bar.value = _health
	_apply_health_bar_style()
	sprite.vframes = 1
	_set_animation("idle")


func _physics_process(delta: float) -> void:
	if _attack_time > 0.0:
		_attack_time = max(_attack_time - delta, 0.0)
	if _attack_cooldown_time > 0.0:
		_attack_cooldown_time = max(_attack_cooldown_time - delta, 0.0)
	if _stun_time > 0.0:
		_stun_time = max(_stun_time - delta, 0.0)

	if multiplayer.is_server():
		_update_server_ai(delta)
		_sync_state.rpc(position, _health, velocity, _facing_left, _attack_time)

	_update_draw_order()
	_update_animation(delta)


func _update_server_ai(delta: float) -> void:
	if _stun_time > 0.0:
		velocity = Vector2.ZERO
		_visual_velocity = velocity
		move_and_slide()
		return

	if _target == null or not is_instance_valid(_target) or _is_dead_player(_target):
		_target = _find_closest_player(aggro_range)
		_give_up_time = 0.0

	if _target != null:
		var target_distance := global_position.distance_to(_target.global_position)
		if target_distance > give_up_range:
			_give_up_time += delta
		else:
			_give_up_time = 0.0

		if _give_up_time >= give_up_seconds:
			_forget_target_here()
			return

		_chase_target(_target)
		return

	_wander(delta)


func _chase_target(target: Node2D) -> void:
	var target_position := target.global_position
	var to_target := target_position - global_position
	_facing_left = to_target.x < 0.0

	if to_target.length() <= attack_range:
		velocity = Vector2.ZERO
		_visual_velocity = velocity
		move_and_slide()
		_try_attack(target)
		return

	velocity = to_target.normalized() * speed
	move_and_slide()
	_visual_velocity = velocity


func _wander(delta: float) -> void:
	if _wait_time > 0.0:
		_wait_time = max(_wait_time - delta, 0.0)
		velocity = Vector2.ZERO
		_visual_velocity = velocity
		move_and_slide()
		return

	if _wander_time <= 0.0 or global_position.distance_to(_wander_target) <= 8.0:
		var angle := _rng.randf_range(0.0, TAU)
		var distance := _rng.randf_range(24.0, wander_radius)
		_wander_target = _home_position + Vector2.RIGHT.rotated(angle) * distance
		_wander_time = _rng.randf_range(WANDER_MOVE_MIN, WANDER_MOVE_MAX)

	_wander_time = max(_wander_time - delta, 0.0)
	_move_toward(_wander_target, wander_speed)
	if _wander_time <= 0.0:
		_wait_time = _rng.randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)


func _move_toward(target_position: Vector2, move_speed: float) -> void:
	var to_target := target_position - global_position
	if to_target.length() <= 4.0:
		velocity = Vector2.ZERO
	else:
		_facing_left = to_target.x < 0.0
		velocity = to_target.normalized() * move_speed

	move_and_slide()
	_visual_velocity = velocity


func _find_closest_player(max_range: float) -> Node2D:
	var players := get_tree().get_nodes_in_group("damageable")
	var closest_target: Node2D = null
	var closest_distance_squared := max_range * max_range

	for node in players:
		if node == self or not node.has_method("_take_test_damage"):
			continue
		if not str(node.name).is_valid_int():
			continue
		if int(node.get("_health")) <= 0:
			continue

		var player := node as Node2D
		if player == null:
			continue

		var distance_squared := global_position.distance_squared_to(player.global_position)
		if distance_squared < closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = player

	return closest_target


func _try_attack(target: Node) -> void:
	if _attack_cooldown_time > 0.0 or _attack_time > 0.0 or _stun_time > 0.0:
		return

	_attack_time = float(attack_frame_count) / attack_fps
	_attack_cooldown_time = attack_cooldown
	if target.has_method("_take_test_damage"):
		target.call("_take_test_damage", attack_damage)


@rpc("authority", "unreliable")
func _sync_state(
	server_position: Vector2,
	server_health: int,
	server_velocity: Vector2,
	facing_left: bool,
	attack_time: float
) -> void:
	position = server_position
	_update_draw_order()
	_health = server_health
	_visual_velocity = server_velocity
	_facing_left = facing_left
	_attack_time = attack_time
	health_bar.value = _health


func _take_test_damage(amount: int, attacker: Node = null) -> void:
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
	if attacker is Node2D:
		_target = attacker as Node2D
	elif _health > 0:
		_target = _find_closest_player(give_up_range)

	if _health <= 0:
		if multiplayer.multiplayer_peer == null:
			_die()
		else:
			_die.rpc()


@rpc("authority", "call_local", "reliable")
func _die() -> void:
	queue_free()


func _forget_target_here() -> void:
	_target = null
	_give_up_time = 0.0
	_home_position = global_position
	_wander_target = global_position
	_wander_time = 0.0
	_wait_time = _rng.randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)
	velocity = Vector2.ZERO
	_visual_velocity = velocity
	move_and_slide()


func _update_animation(delta: float) -> void:
	var is_running := _visual_velocity.length_squared() > 1.0
	var animation_name := "run" if is_running else "idle"
	var fps := run_fps
	var frame_count := run_frame_count

	if not is_running:
		fps = idle_fps
		frame_count = idle_frame_count

	if _attack_time > 0.0 and attack_texture != null:
		animation_name = "attack"
		fps = attack_fps
		frame_count = attack_frame_count

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
		sprite.hframes = attack_frame_count
	elif run_texture != null:
		sprite.texture = run_texture
		sprite.hframes = run_frame_count
	if animation_name == "idle" and idle_texture != null:
		sprite.texture = idle_texture
		sprite.hframes = idle_frame_count
	sprite.frame = 0


func _is_dead_player(player: Node) -> bool:
	return int(player.get("_health")) <= 0


@rpc("authority", "call_local", "reliable")
func _show_damage_number(amount: int) -> void:
	var parent := get_parent()
	if parent == null:
		parent = get_tree().current_scene
	FLOATING_COMBAT_TEXT.spawn_damage(parent, global_position, amount)


func _update_draw_order() -> void:
	z_index = clampi(
		int(round(global_position.y + DRAW_ORDER_FOOT_OFFSET)),
		DRAW_ORDER_MIN,
		DRAW_ORDER_MAX
	)


func _apply_enemy_config() -> void:
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Enemy config not found: %s" % CONFIG_PATH)
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not (parsed is Dictionary):
		push_warning("Enemy config is not a dictionary: %s" % CONFIG_PATH)
		return
	if not parsed.has(enemy_id):
		push_warning("Enemy id '%s' not found in %s" % [enemy_id, CONFIG_PATH])
		return

	var config: Dictionary = parsed[enemy_id]
	speed = float(config.get("speed", speed))
	attack_range = float(config.get("attack_range", attack_range))
	attack_damage = int(config.get("attack_damage", attack_damage))
	attack_cooldown = float(config.get("attack_cooldown", attack_cooldown))
	aggro_range = float(config.get("aggro_range", aggro_range))
	give_up_range = float(config.get("give_up_range", give_up_range))
	give_up_seconds = float(config.get("give_up_seconds", give_up_seconds))
	wander_radius = float(config.get("wander_radius", wander_radius))
	wander_speed = float(config.get("wander_speed", wander_speed))
	max_health = int(config.get("max_health", max_health))
	idle_fps = float(config.get("idle_fps", idle_fps))
	run_fps = float(config.get("run_fps", run_fps))
	attack_fps = float(config.get("attack_fps", attack_fps))
	idle_frame_count = int(config.get("idle_frames", idle_frame_count))
	run_frame_count = int(config.get("run_frames", run_frame_count))
	attack_frame_count = int(config.get("attack_frames", attack_frame_count))


func _apply_health_bar_style() -> void:
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = Color(0.08, 0.08, 0.08, 0.85)
	background_style.corner_radius_top_left = 2
	background_style.corner_radius_top_right = 2
	background_style.corner_radius_bottom_left = 2
	background_style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = Color(0.82, 0.16, 0.12)
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("fill", fill_style)
