extends CharacterBody2D

@export var speed := 160.0
@export var peer_id := 1
@export var display_name := "Player"
@export var idle_texture: Texture2D
@export var run_texture: Texture2D
@export var attack_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D
@onready var name_label: Label = $NameLabel
@onready var health_bar: ProgressBar = $HealthBar
@onready var attack_marker: ColorRect = $AttackMarker
@onready var camera: Camera2D = $Camera2D

const FRAME_COUNT := 8
const IDLE_FPS := 4.0
const RUN_FPS := 10.0
const ATTACK_FPS := 14.0
const TEST_ATTACK_DAMAGE := 20
const TEST_ATTACK_RANGE := 92.0
const TEST_FIREBALL_DAMAGE := 35
const TEST_FIREBALL_RANGE := 180.0
const CHAT_BUBBLE_SECONDS := 4.0
const ACTION_BUBBLE_SECONDS := 1.0
const HOVER_RECT := Rect2(Vector2(-32.0, -48.0), Vector2(64.0, 112.0))

var _server_input := Vector2.ZERO
var _health := 100
var _attack_time := 0.0
var _chat_bubble_time := 0.0
var _animation_time := 0.0
var _current_animation := ""
var _visual_velocity := Vector2.ZERO
var _server_facing_left := false
var _facing_left := false
var _chat_bubble_box: PanelContainer
var _chat_bubble: Label
var _chat_bubble_tail: Polygon2D
var _chat_bubble_tail_outline: Line2D


func _ready() -> void:
	name_label.text = display_name
	name_label.visible = false
	health_bar.max_value = 100
	health_bar.value = _health
	_apply_health_bar_style()
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
		if peer_id == multiplayer.get_unique_id():
			input_vector = _read_input()
			facing_left = _read_mouse_facing_left()

		velocity = input_vector * speed
		move_and_slide()
		_visual_velocity = velocity
		_facing_left = facing_left
		_sync_state.rpc(position, _health, velocity, facing_left)
	else:
		if _is_local_player():
			_facing_left = _read_mouse_facing_left()
			_send_input.rpc_id(1, _read_input(), _facing_left)

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
	if _attack_time > 0.0:
		return
	if multiplayer.multiplayer_peer == null:
		_play_attack()
		_apply_test_attack_damage()
	elif multiplayer.is_server():
		_play_attack.rpc()
		_apply_test_attack_damage()
	else:
		_request_attack.rpc_id(1)


func try_fireball() -> void:
	if _attack_time > 0.0:
		return
	if multiplayer.multiplayer_peer == null:
		_play_fireball()
		_apply_test_skill_damage(TEST_FIREBALL_DAMAGE, TEST_FIREBALL_RANGE)
	elif multiplayer.is_server():
		_play_fireball.rpc()
		_apply_test_skill_damage(TEST_FIREBALL_DAMAGE, TEST_FIREBALL_RANGE)
	else:
		_request_fireball.rpc_id(1)


@rpc("any_peer", "unreliable")
func _send_input(input_vector: Vector2, facing_left: bool) -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() != peer_id:
		return
	_server_input = input_vector.limit_length(1.0)
	_server_facing_left = facing_left


@rpc("any_peer", "reliable")
func _request_attack() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == peer_id:
		if _attack_time > 0.0:
			return
		_play_attack.rpc()
		_apply_test_attack_damage()


@rpc("any_peer", "reliable")
func _request_fireball() -> void:
	if not multiplayer.is_server():
		return
	if multiplayer.get_remote_sender_id() == peer_id:
		if _attack_time > 0.0:
			return
		_play_fireball.rpc()
		_apply_test_skill_damage(TEST_FIREBALL_DAMAGE, TEST_FIREBALL_RANGE)


@rpc("authority", "call_local", "reliable")
func _play_attack() -> void:
	if _attack_time > 0.0:
		return
	_attack_time = float(FRAME_COUNT) / ATTACK_FPS
	attack_marker.visible = false
	_set_animation("attack")
	_show_chat_bubble("Strike!", ACTION_BUBBLE_SECONDS)


@rpc("authority", "call_local", "reliable")
func _play_fireball() -> void:
	if _attack_time > 0.0:
		return
	_attack_time = float(FRAME_COUNT) / ATTACK_FPS
	attack_marker.visible = false
	_set_animation("attack")
	_show_chat_bubble("Fireball!", ACTION_BUBBLE_SECONDS)


@rpc("authority", "unreliable")
func _sync_state(
	server_position: Vector2,
	server_health: int,
	server_velocity: Vector2,
	facing_left: bool
) -> void:
	position = server_position
	_health = server_health
	_visual_velocity = server_velocity
	_facing_left = facing_left
	health_bar.value = _health


func _apply_test_attack_damage() -> void:
	_apply_test_skill_damage(TEST_ATTACK_DAMAGE, TEST_ATTACK_RANGE)


func _apply_test_skill_damage(amount: int, attack_range: float) -> void:
	var target := _find_test_attack_target(attack_range)
	if target == null:
		return

	target.call("_take_test_damage", amount)


func _find_test_attack_target(attack_range: float) -> Node:
	var players := get_parent()
	if players == null:
		return null

	var closest_target: Node = null
	var closest_distance_squared := attack_range * attack_range
	for node in players.get_children():
		if node == self or not node.has_method("_take_test_damage"):
			continue

		var player := node as Node2D
		if player == null:
			continue
		if int(node.get("_health")) <= 0:
			continue

		var distance_squared := global_position.distance_squared_to(player.global_position)
		if distance_squared <= closest_distance_squared:
			closest_distance_squared = distance_squared
			closest_target = node

	return closest_target


func _take_test_damage(amount: int) -> void:
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


func _read_mouse_facing_left() -> bool:
	return get_global_mouse_position().x < global_position.x


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
