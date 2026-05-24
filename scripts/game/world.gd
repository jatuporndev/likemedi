extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy_bot.tscn")
const MAP_CONFIG_PATH := "res://config/maps.json"
const DEFAULT_MAP_SCENE := "res://scenes/world/maps/map_1.tscn"
const RANDOM_SPAWN_ATTEMPTS := 32
const FALLBACK_MAP_RECT := Rect2(Vector2(-700, -450), Vector2(6000, 2400))
const MAP_TRANSITION_LOCK_MSEC := 650
const MAP_TRANSITION_LOCKED_UNTIL_META := "map_transition_locked_until_msec"
const PLAYER_SPAWN_POINT_NODE_NAME := "PlayerSpawnPoint"
const SPAWN_ANCHOR_NODE_NAME := "SpawnAnchor"

@onready var map_root: Node2D = $MapRoot
@onready var enemies: Node2D = $Enemies

var _rng := RandomNumberGenerator.new()
var _next_enemy_id := 1
var _current_map_scene_path := ""
var _map_configs: Dictionary = {}
var _enemy_spawn_blocks: Array[Dictionary] = []
var _respawn_map_scene_path := ""
var _respawn_spawn_name := SPAWN_ANCHOR_NODE_NAME


func _ready() -> void:
	_load_map_configs()
	_rng.randomize()
	_load_map(DEFAULT_MAP_SCENE)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_update_enemy_spawn_blocks(delta)


func sync_enemies_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for enemy in enemies.get_children():
		var enemy_2d := enemy as Node2D
		if enemy_2d == null:
			continue
		spawn_enemy.rpc_id(
			peer_id,
			str(enemy.name),
			enemy_2d.position,
			str(enemy.get("enemy_id")),
			int(enemy.get_meta("spawn_block_index", -1))
		)


func sync_map_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or _current_map_scene_path.is_empty():
		return

	_load_map_rpc.rpc_id(peer_id, _current_map_scene_path)


func change_map_for_player(player: Node2D, map_scene_path: String, spawn_name: String) -> void:
	if player == null or map_scene_path.is_empty():
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	if multiplayer.multiplayer_peer == null:
		_change_map_for_player_local(map_scene_path, spawn_name, player.get_path())
	else:
		_change_map_for_player_rpc.rpc(map_scene_path, spawn_name, player.get_path())


func revive_player_at_spawn(player: Node2D) -> bool:
	if player == null or _respawn_map_scene_path.is_empty():
		return false
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false

	if multiplayer.multiplayer_peer == null:
		_change_map_for_player_local(_respawn_map_scene_path, _respawn_spawn_name, player.get_path())
	else:
		_change_map_for_player_rpc.rpc(_respawn_map_scene_path, _respawn_spawn_name, player.get_path())
	return true


@rpc("authority", "call_local", "reliable")
func _load_map_rpc(map_scene_path: String) -> void:
	_load_map(map_scene_path)


@rpc("authority", "call_local", "reliable")
func _change_map_for_player_rpc(map_scene_path: String, spawn_name: String, player_path: NodePath) -> void:
	_change_map_for_player_local(map_scene_path, spawn_name, player_path)


func _change_map_for_player_local(map_scene_path: String, spawn_name: String, player_path: NodePath) -> void:
	_load_map(map_scene_path)

	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return

	var spawn_marker := _find_spawn_marker(spawn_name)
	if spawn_marker == null:
		return

	player.set_meta(
		MAP_TRANSITION_LOCKED_UNTIL_META,
		Time.get_ticks_msec() + MAP_TRANSITION_LOCK_MSEC
	)
	player.global_position = spawn_marker.global_position
	player.set("velocity", Vector2.ZERO)


func _load_map(map_scene_path: String) -> void:
	if _current_map_scene_path == map_scene_path:
		return

	var map_scene := load(map_scene_path) as PackedScene
	if map_scene == null:
		push_warning("Unable to load map scene: %s" % map_scene_path)
		return

	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	var map := map_scene.instantiate()
	map_root.add_child(map)
	_current_map_scene_path = map_scene_path
	_update_respawn_crystal_for_current_map()
	_load_current_map_enemy_blocks()
	_clear_enemies()
	if multiplayer.is_server():
		_spawn_initial_map_enemies()


func _find_spawn_marker(spawn_name: String) -> Node2D:
	if map_root == null:
		return null
	var marker := map_root.find_child(spawn_name, true, false) as Node2D
	return marker


func _update_respawn_crystal_for_current_map() -> void:
	var spawn_point := _find_spawn_marker(PLAYER_SPAWN_POINT_NODE_NAME)
	if spawn_point == null:
		return

	_respawn_map_scene_path = _current_map_scene_path
	var spawn_anchor := spawn_point.get_node_or_null(SPAWN_ANCHOR_NODE_NAME) as Node2D
	_respawn_spawn_name = SPAWN_ANCHOR_NODE_NAME if spawn_anchor != null else PLAYER_SPAWN_POINT_NODE_NAME


func _load_map_configs() -> void:
	if not FileAccess.file_exists(MAP_CONFIG_PATH):
		push_warning("Map config not found: %s" % MAP_CONFIG_PATH)
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_CONFIG_PATH))
	if not (parsed is Dictionary):
		push_warning("Map config is not a dictionary: %s" % MAP_CONFIG_PATH)
		return

	_map_configs = parsed


func _load_current_map_enemy_blocks() -> void:
	_enemy_spawn_blocks.clear()
	if not _map_configs.has(_current_map_scene_path):
		return

	var map_config = _map_configs[_current_map_scene_path]
	if not (map_config is Dictionary):
		return

	var enemy_blocks = map_config.get("enemies", [])
	if not (enemy_blocks is Array):
		return

	for index in range(enemy_blocks.size()):
		var block = enemy_blocks[index]
		if not (block is Dictionary):
			continue

		var enemy_id := str(block.get("enemy_id", ""))
		var count := maxi(int(block.get("count", 0)), 0)
		var respawn_seconds := maxf(float(block.get("respawn_seconds", 0.0)), 0.0)
		if enemy_id.is_empty() or count <= 0:
			continue

		_enemy_spawn_blocks.append({
			"id": "block_%d" % index,
			"enemy_id": enemy_id,
			"count": count,
			"respawn_seconds": respawn_seconds,
			"respawn_time": 0.0,
		})


func _spawn_initial_map_enemies() -> void:
	for index in range(_enemy_spawn_blocks.size()):
		while _get_enemy_count_for_block(index) < int(_enemy_spawn_blocks[index]["count"]):
			_spawn_enemy_from_block(index)


func _update_enemy_spawn_blocks(delta: float) -> void:
	for index in range(_enemy_spawn_blocks.size()):
		var block := _enemy_spawn_blocks[index]
		var target_count := int(block["count"])
		if _get_enemy_count_for_block(index) >= target_count:
			block["respawn_time"] = 0.0
			_enemy_spawn_blocks[index] = block
			continue

		block["respawn_time"] = maxf(float(block["respawn_time"]) - delta, 0.0)
		if float(block["respawn_time"]) <= 0.0:
			_spawn_enemy_from_block(index)
			block["respawn_time"] = float(block["respawn_seconds"])
		_enemy_spawn_blocks[index] = block


func _spawn_enemy_from_block(block_index: int) -> void:
	if block_index < 0 or block_index >= _enemy_spawn_blocks.size():
		return

	var block := _enemy_spawn_blocks[block_index]
	var enemy_name := "Enemy%d" % _next_enemy_id
	_next_enemy_id += 1
	var spawn_position := _get_random_walkable_spawn_position()

	if multiplayer.multiplayer_peer == null:
		spawn_enemy(enemy_name, spawn_position, str(block["enemy_id"]), block_index)
	else:
		spawn_enemy.rpc(enemy_name, spawn_position, str(block["enemy_id"]), block_index)


@rpc("authority", "call_local", "reliable")
func spawn_enemy(enemy_name: String, spawn_position: Vector2, enemy_id: String, spawn_block_index: int = -1) -> void:
	if enemies.has_node(enemy_name):
		return

	var enemy := ENEMY_SCENE.instantiate()
	enemy.name = enemy_name
	enemy.enemy_id = enemy_id
	enemy.position = spawn_position
	enemy.set_meta("spawn_block_index", spawn_block_index)
	enemy.set_multiplayer_authority(1)
	enemies.add_child(enemy)


func _get_enemy_count_for_block(block_index: int) -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not enemy.is_queued_for_deletion() and int(enemy.get_meta("spawn_block_index", -1)) == block_index:
			count += 1
	return count


func _clear_enemies() -> void:
	for enemy in enemies.get_children():
		enemies.remove_child(enemy)
		enemy.queue_free()


func _get_random_walkable_spawn_position() -> Vector2:
	var map_rect := _get_current_map_rect()
	for _attempt in range(RANDOM_SPAWN_ATTEMPTS):
		var candidate := Vector2(
			_rng.randf_range(map_rect.position.x, map_rect.end.x),
			_rng.randf_range(map_rect.position.y, map_rect.end.y)
		)
		if _is_spawn_position_walkable(candidate):
			return candidate

	return map_rect.get_center()


func _get_current_map_rect() -> Rect2:
	if map_root == null or map_root.get_child_count() <= 0:
		return FALLBACK_MAP_RECT

	var current_map := map_root.get_child(0)
	var ground := current_map.get_node_or_null("Ground") as ColorRect
	if ground == null:
		return FALLBACK_MAP_RECT

	return Rect2(ground.global_position, ground.size)


func get_current_map_rect() -> Rect2:
	return _get_current_map_rect()


func _is_spawn_position_walkable(candidate: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = candidate
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xffffffff

	var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
	return hits.is_empty()
