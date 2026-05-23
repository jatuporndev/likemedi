extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy_bot.tscn")
const MAX_ENEMIES := 3
const RESPAWN_SECONDS := 60.0
const ENEMY_IDS := ["e1", "e2"]
const SPAWN_RECT := Rect2(Vector2(-620, -370), Vector2(1840, 1240))
const DRAW_ORDER_MIN := -4096
const ROCK_DRAW_ORDER_FOOT_OFFSET := 21.0

@onready var enemies: Node2D = $Enemies

var _rng := RandomNumberGenerator.new()
var _next_enemy_id := 1


func _ready() -> void:
	_build_map()
	_rng.randomize()

	if multiplayer.is_server():
		for i in range(MAX_ENEMIES):
			_spawn_random_enemy(str(ENEMY_IDS[i % ENEMY_IDS.size()]))
		var respawn_timer := Timer.new()
		respawn_timer.wait_time = RESPAWN_SECONDS
		respawn_timer.autostart = true
		respawn_timer.timeout.connect(_on_respawn_timer_timeout)
		add_child(respawn_timer)


func sync_enemies_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for enemy in enemies.get_children():
		var enemy_2d := enemy as Node2D
		if enemy_2d == null:
			continue
		spawn_enemy.rpc_id(peer_id, str(enemy.name), enemy_2d.position, str(enemy.get("enemy_id")))


func _build_map() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.18, 0.28, 0.18)
	ground.size = Vector2(2000, 1400)
	ground.position = Vector2(-700, -450)
	ground.z_as_relative = false
	ground.z_index = DRAW_ORDER_MIN
	add_child(ground)
	move_child(ground, 0)

	for i in range(12):
		var rock := StaticBody2D.new()
		rock.position = Vector2(130 + (i % 4) * 190, 120 + (i / 4) * 180)
		rock.z_as_relative = false
		rock.z_index = int(round(rock.position.y + ROCK_DRAW_ORDER_FOOT_OFFSET))
		add_child(rock)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(54, 42)
		shape.shape = rect
		rock.add_child(shape)

		var visual := ColorRect.new()
		visual.color = Color(0.24, 0.24, 0.22)
		visual.size = rect.size
		visual.position = -rect.size / 2.0
		rock.add_child(visual)


func _on_respawn_timer_timeout() -> void:
	if _get_enemy_count() < MAX_ENEMIES:
		_spawn_random_enemy()


func _spawn_random_enemy(preferred_enemy_id: String = "") -> void:
	if _get_enemy_count() >= MAX_ENEMIES:
		return

	var enemy_name := "Enemy%d" % _next_enemy_id
	_next_enemy_id += 1
	var spawn_position := Vector2(
		_rng.randf_range(SPAWN_RECT.position.x, SPAWN_RECT.end.x),
		_rng.randf_range(SPAWN_RECT.position.y, SPAWN_RECT.end.y)
	)

	var enemy_id := preferred_enemy_id
	if enemy_id.is_empty():
		enemy_id = str(ENEMY_IDS[_rng.randi_range(0, ENEMY_IDS.size() - 1)])

	if multiplayer.multiplayer_peer == null:
		spawn_enemy(enemy_name, spawn_position, enemy_id)
	else:
		spawn_enemy.rpc(enemy_name, spawn_position, enemy_id)


@rpc("authority", "call_local", "reliable")
func spawn_enemy(enemy_name: String, spawn_position: Vector2, enemy_id: String) -> void:
	if enemies.has_node(enemy_name):
		return

	var enemy := ENEMY_SCENE.instantiate()
	enemy.name = enemy_name
	enemy.enemy_id = enemy_id
	enemy.position = spawn_position
	enemy.set_multiplayer_authority(1)
	enemies.add_child(enemy)


func _get_enemy_count() -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not enemy.is_queued_for_deletion():
			count += 1
	return count
