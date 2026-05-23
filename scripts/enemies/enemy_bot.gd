extends CharacterBody2D

const CONFIG_PATH := "res://config/enemies.json"
const FLOATING_COMBAT_TEXT := preload("res://scripts/effects/floating_combat_text.gd")
const FIREBALL_PROJECTILE_SCENE := preload("res://scenes/effects/fireball_projectile.tscn")

@export var enemy_id := "e1"
@export var speed := 105.0
@export var attack_range := 46.0
@export var attack_damage := 12
@export var attack_cooldown := 1.2
@export var fireball_enabled := false
@export var fireball_range := 300.0
@export var fireball_damage := 14
@export var fireball_cast_time := 3.0
@export var fireball_cooldown := 4.0
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
const FIREBALL_PROJECTILE_FORWARD_OFFSET := 22.0
const SPELL_CAST_FLOOR_OFFSET := Vector2(0.0, 46.0)
const SPELL_CAST_FLOOR_RADIUS := 34.0
const SPELL_CAST_FLOOR_Y_SCALE := 0.52
const SPELL_CAST_FLOOR_SEGMENTS := 48
const SPELL_CAST_MARK_COUNT := 12
const SPELL_CAST_COLOR := Color(1.0, 1.0, 1.0, 1.0)
const STUCK_CHECK_MIN_SPEED := 12.0
const STUCK_PROGRESS_RATIO := 0.22
const STUCK_SECONDS := 0.22
const STUCK_AVOID_SECONDS := 0.7
const AVOID_TARGET_WEIGHT := 0.42
const AVOID_TANGENT_WEIGHT := 0.92

var _health := 60
var _attack_time := 0.0
var _attack_cooldown_time := 0.0
var _fireball_cooldown_time := 0.0
var _fireball_cast_time := 0.0
var _fireball_cast_duration := 0.0
var _fireball_cast_target_position := Vector2.ZERO
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
var _stuck_time := 0.0
var _avoidance_time := 0.0
var _avoidance_direction := Vector2.ZERO
var _wait_boi_time := 0.0
var _wait_boi_duration := 0.0
var _wait_boi_speed_multiplier := 1.0
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
	_build_spell_cast_floor_circle()


func _physics_process(delta: float) -> void:
	if _attack_time > 0.0:
		_attack_time = max(_attack_time - delta, 0.0)
	if _attack_cooldown_time > 0.0:
		_attack_cooldown_time = max(_attack_cooldown_time - delta, 0.0)
	if _fireball_cooldown_time > 0.0:
		_fireball_cooldown_time = maxf(_fireball_cooldown_time - delta, 0.0)
	if _fireball_cast_time > 0.0:
		_fireball_cast_time = maxf(_fireball_cast_time - delta, 0.0)
		if _fireball_cast_time <= 0.0 and multiplayer.is_server():
			_finish_fireball_cast()
		if _fireball_cast_time <= 0.0:
			_set_spell_cast_floor_visible(false)
	if _stun_time > 0.0:
		_stun_time = max(_stun_time - delta, 0.0)
	if _wait_boi_time > 0.0:
		_wait_boi_time = maxf(_wait_boi_time - delta, 0.0)
		if _wait_boi_time <= 0.0:
			_wait_boi_duration = 0.0
			_wait_boi_speed_multiplier = 1.0

	if multiplayer.is_server():
		_update_server_ai(delta)
		_sync_state.rpc(
			position,
			_health,
			velocity,
			_facing_left,
			_attack_time,
			_fireball_cast_time,
			_wait_boi_time,
			_wait_boi_duration
		)

	_update_draw_order()
	_update_spell_cast_floor_circle()
	_update_animation(delta)


func _update_server_ai(delta: float) -> void:
	if _stun_time > 0.0 or _fireball_cast_time > 0.0:
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

		_chase_target(_target, delta)
		return

	_wander(delta)


func _chase_target(target: Node2D, delta: float) -> void:
	var target_position := target.global_position
	var to_target := target_position - global_position
	_facing_left = to_target.x < 0.0

	if to_target.length() <= attack_range:
		_reset_stuck_recovery()
		velocity = Vector2.ZERO
		_visual_velocity = velocity
		move_and_slide()
		_try_attack(target)
		return

	if _can_cast_fireball_at(to_target.length()):
		_reset_stuck_recovery()
		velocity = Vector2.ZERO
		_visual_velocity = velocity
		move_and_slide()
		_try_cast_fireball(target)
		return

	_move_toward(target_position, speed * _get_move_speed_multiplier(), delta)


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
	_move_toward(_wander_target, wander_speed * _get_move_speed_multiplier(), delta)
	if _wander_time <= 0.0:
		_wait_time = _rng.randf_range(WANDER_WAIT_MIN, WANDER_WAIT_MAX)


func _move_toward(target_position: Vector2, move_speed: float, delta: float) -> void:
	var to_target := target_position - global_position
	if to_target.length() <= 4.0:
		_reset_stuck_recovery()
		velocity = Vector2.ZERO
	else:
		_facing_left = to_target.x < 0.0
		velocity = _get_recovery_velocity(to_target.normalized(), move_speed, delta)

	var previous_position := global_position
	move_and_slide()
	_visual_velocity = velocity
	_update_stuck_recovery(previous_position, target_position, velocity, delta)


func _get_recovery_velocity(target_direction: Vector2, move_speed: float, delta: float) -> Vector2:
	if _avoidance_time <= 0.0 or _avoidance_direction == Vector2.ZERO:
		return target_direction * move_speed

	_avoidance_time = maxf(_avoidance_time - delta, 0.0)
	var recovery_direction := (
		target_direction * AVOID_TARGET_WEIGHT
		+ _avoidance_direction * AVOID_TANGENT_WEIGHT
	).normalized()

	if _avoidance_time <= 0.0:
		_avoidance_direction = Vector2.ZERO

	return recovery_direction * move_speed


func _get_move_speed_multiplier() -> float:
	return _wait_boi_speed_multiplier if _wait_boi_time > 0.0 else 1.0


func _update_stuck_recovery(
	previous_position: Vector2,
	target_position: Vector2,
	requested_velocity: Vector2,
	delta: float
) -> void:
	var expected_distance := requested_velocity.length() * delta
	if expected_distance < STUCK_CHECK_MIN_SPEED * delta:
		_stuck_time = 0.0
		return

	var actual_distance := previous_position.distance_to(global_position)
	var blocked := actual_distance < expected_distance * STUCK_PROGRESS_RATIO

	if blocked:
		_stuck_time += delta
		if _stuck_time >= STUCK_SECONDS:
			_begin_stuck_recovery(target_position)
			_stuck_time = 0.0
	else:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
		if get_slide_collision_count() == 0 and actual_distance >= expected_distance * 0.8:
			_avoidance_time = 0.0
			_avoidance_direction = Vector2.ZERO


func _begin_stuck_recovery(target_position: Vector2) -> void:
	var target_direction := (target_position - global_position).normalized()
	if target_direction == Vector2.ZERO:
		return

	var normal := Vector2.ZERO
	var collision_count := get_slide_collision_count()
	if collision_count > 0:
		var collision := get_slide_collision(collision_count - 1)
		if collision != null:
			normal = collision.get_normal()

	if normal == Vector2.ZERO:
		normal = -target_direction

	var tangent := Vector2(-normal.y, normal.x).normalized()
	if tangent == Vector2.ZERO:
		tangent = Vector2(-target_direction.y, target_direction.x).normalized()
	if tangent.dot(target_direction) < 0.0:
		tangent = -tangent

	if _avoidance_time > 0.0 and _avoidance_direction != Vector2.ZERO:
		_avoidance_direction = -_avoidance_direction
	else:
		_avoidance_direction = tangent

	_avoidance_time = STUCK_AVOID_SECONDS


func _reset_stuck_recovery() -> void:
	_stuck_time = 0.0
	_avoidance_time = 0.0
	_avoidance_direction = Vector2.ZERO


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
	if (
		_attack_cooldown_time > 0.0
		or _attack_time > 0.0
		or _stun_time > 0.0
		or _fireball_cast_time > 0.0
	):
		return

	_attack_time = float(attack_frame_count) / attack_fps
	_attack_cooldown_time = attack_cooldown
	if target.has_method("_take_test_damage"):
		target.call("_take_test_damage", attack_damage)


func _can_cast_fireball_at(target_distance: float) -> bool:
	return (
		fireball_enabled
		and _fireball_cooldown_time <= 0.0
		and _fireball_cast_time <= 0.0
		and _attack_time <= 0.0
		and target_distance <= fireball_range
	)


func _try_cast_fireball(target: Node2D) -> void:
	if target == null:
		return

	_fireball_cast_duration = maxf(fireball_cast_time, 0.01)
	_fireball_cast_time = _fireball_cast_duration
	_fireball_cooldown_time = fireball_cooldown + _fireball_cast_duration
	_fireball_cast_target_position = target.global_position
	_set_spell_cast_floor_visible(true)


func _finish_fireball_cast() -> void:
	var direction := (_fireball_cast_target_position - global_position).normalized()
	if direction.length_squared() <= 0.0:
		direction = Vector2.LEFT if _facing_left else Vector2.RIGHT
	_attack_time = float(attack_frame_count) / attack_fps

	if multiplayer.multiplayer_peer == null:
		_play_fireball_projectile(global_position, direction, fireball_damage)
	else:
		_play_fireball_projectile.rpc(global_position, direction, fireball_damage)


@rpc("authority", "call_local", "reliable")
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
		fireball.call("setup", spawn_origin, forward, damage, -1, self, true)


@rpc("authority", "unreliable")
func _sync_state(
	server_position: Vector2,
	server_health: int,
	server_velocity: Vector2,
	facing_left: bool,
	attack_time: float,
	fireball_cast_time: float = 0.0,
	wait_boi_time: float = 0.0,
	wait_boi_duration: float = 0.0
) -> void:
	var was_casting_fireball := _fireball_cast_time > 0.0
	position = server_position
	_update_draw_order()
	_health = server_health
	_visual_velocity = server_velocity
	_facing_left = facing_left
	_attack_time = attack_time
	_fireball_cast_time = maxf(fireball_cast_time, 0.0)
	if _fireball_cast_time > 0.0 and not was_casting_fireball:
		_fireball_cast_duration = maxf(fireball_cast_time, 0.01)
		_set_spell_cast_floor_visible(true)
	elif _fireball_cast_time <= 0.0 and was_casting_fireball:
		_set_spell_cast_floor_visible(false)
	_wait_boi_time = maxf(wait_boi_time, 0.0)
	_wait_boi_duration = maxf(wait_boi_duration, 0.0)
	_wait_boi_speed_multiplier = 0.85 if _wait_boi_time > 0.0 else 1.0
	health_bar.value = _health


func _receive_wait_boi_debuff(debuff_speed_percent: float, debuff_duration: float) -> void:
	if not multiplayer.is_server() and multiplayer.multiplayer_peer != null:
		return
	if _health <= 0:
		return

	_wait_boi_duration = debuff_duration
	_wait_boi_time = debuff_duration
	_wait_boi_speed_multiplier = maxf(1.0 - maxf(debuff_speed_percent, 0.0) / 100.0, 0.0)


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
	if attacker is Node2D and str(attacker.name).is_valid_int():
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


func _update_spell_cast_floor_circle() -> void:
	if _fireball_cast_time <= 0.0 or _fireball_cast_duration <= 0.0:
		return

	var progress := 1.0 - (_fireball_cast_time / _fireball_cast_duration)
	var pulse := 1.0 + sin(progress * PI) * 0.18
	var fade := maxf(sin(progress * PI), 0.48)
	var radius := SPELL_CAST_FLOOR_RADIUS * pulse
	var radii := Vector2(radius, radius * SPELL_CAST_FLOOR_Y_SCALE)
	var center := SPELL_CAST_FLOOR_OFFSET
	var spin := float(Time.get_ticks_msec()) * 0.0032

	if _spell_cast_fill != null:
		_spell_cast_fill.color = Color(
			SPELL_CAST_COLOR.r,
			SPELL_CAST_COLOR.g,
			SPELL_CAST_COLOR.b,
			0.16 * fade
		)
		_spell_cast_fill.polygon = _make_spell_cast_ellipse_polygon(center, radii * 0.96)
	if _spell_cast_ring != null:
		_spell_cast_ring.default_color = Color(
			SPELL_CAST_COLOR.r,
			SPELL_CAST_COLOR.g,
			SPELL_CAST_COLOR.b,
			0.78 * fade
		)
		_update_spell_cast_ellipse_ring_points(_spell_cast_ring, center, radii)
	if _spell_cast_inner_ring != null:
		_spell_cast_inner_ring.default_color = Color(
			SPELL_CAST_COLOR.r,
			SPELL_CAST_COLOR.g,
			SPELL_CAST_COLOR.b,
			0.52 * fade
		)
		_update_spell_cast_ellipse_ring_points(_spell_cast_inner_ring, center, radii * 0.62)
	if _spell_cast_rune_ring != null:
		_spell_cast_rune_ring.default_color = Color(
			SPELL_CAST_COLOR.r,
			SPELL_CAST_COLOR.g,
			SPELL_CAST_COLOR.b,
			0.42 * fade
		)
		_update_spell_cast_rotated_ellipse_ring_points(_spell_cast_rune_ring, center, radii * 0.78, spin)
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


func _make_spell_cast_ellipse_polygon(center: Vector2, radii: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array([center])
	for i in range(SPELL_CAST_FLOOR_SEGMENTS + 1):
		var angle := TAU * float(i) / float(SPELL_CAST_FLOOR_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _update_spell_cast_ellipse_ring_points(ring: Line2D, center: Vector2, radii: Vector2) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(SPELL_CAST_FLOOR_SEGMENTS + 1):
		var angle := TAU * float(i) / float(SPELL_CAST_FLOOR_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_spell_cast_rotated_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	rotation: float
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(SPELL_CAST_FLOOR_SEGMENTS + 1):
		var angle := rotation + TAU * float(i) / float(SPELL_CAST_FLOOR_SEGMENTS)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_spell_cast_marks(center: Vector2, radii: Vector2, spin: float, fade: float) -> void:
	for index in range(_spell_cast_marks.size()):
		var angle := spin + TAU * float(index) / float(_spell_cast_marks.size())
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * radii * 0.72
		var outer := center + direction * radii
		_spell_cast_marks[index].default_color = Color(
			SPELL_CAST_COLOR.r,
			SPELL_CAST_COLOR.g,
			SPELL_CAST_COLOR.b,
			0.56 * fade
		)
		_spell_cast_marks[index].points = PackedVector2Array([inner, outer])


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
	fireball_enabled = bool(config.get("fireball_enabled", fireball_enabled))
	fireball_range = float(config.get("fireball_range", fireball_range))
	fireball_damage = int(config.get("fireball_damage", fireball_damage))
	fireball_cast_time = float(config.get("fireball_cast_time", fireball_cast_time))
	fireball_cooldown = float(config.get("fireball_cooldown", fireball_cooldown))
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
	_apply_texture_config(str(config.get("texture_dir", "")))


func _apply_texture_config(texture_dir: String) -> void:
	if texture_dir.is_empty():
		return

	var idle_path := "%s/Idle.png" % texture_dir
	var run_path := "%s/Run.png" % texture_dir
	var attack_path := "%s/Attack1.png" % texture_dir
	if ResourceLoader.exists(idle_path):
		idle_texture = load(idle_path) as Texture2D
	if ResourceLoader.exists(run_path):
		run_texture = load(run_path) as Texture2D
	if ResourceLoader.exists(attack_path):
		attack_texture = load(attack_path) as Texture2D


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
