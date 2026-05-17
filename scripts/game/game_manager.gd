extends Node

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

@onready var players: Node2D = $"../Players"

var _known_players: Dictionary = {}


func _ready() -> void:
	NetworkManager.peer_left.connect(_on_peer_left)

	if multiplayer.is_server():
		if not NetworkManager.is_dedicated_server():
			_add_player(1, str(NetworkManager.player_names.get(1, "Host")))
	else:
		request_initial_state.rpc_id(1)


@rpc("any_peer", "reliable")
func request_initial_state() -> void:
	if not multiplayer.is_server():
		return

	var requester_id := multiplayer.get_remote_sender_id()
	var requested_name := str(NetworkManager.player_names.get(requester_id, "Player %d" % requester_id))

	for peer_id in _known_players.keys():
		var data: Dictionary = _known_players[peer_id]
		spawn_player.rpc_id(requester_id, peer_id, data["name"], data["position"])

	var world := get_parent()
	if world != null and world.has_method("sync_enemies_to_peer"):
		world.call("sync_enemies_to_peer", requester_id)

	_add_player(requester_id, requested_name)


@rpc("authority", "call_local", "reliable")
func spawn_player(peer_id: int, display_name: String, spawn_position: Vector2) -> void:
	if players.has_node(str(peer_id)):
		return

	var player := PLAYER_SCENE.instantiate()
	player.name = str(peer_id)
	player.peer_id = peer_id
	player.display_name = display_name
	player.position = spawn_position
	player.set_multiplayer_authority(1)
	players.add_child(player)
	NetworkManager.player_names[peer_id] = display_name


@rpc("authority", "call_local", "reliable")
func despawn_player(peer_id: int) -> void:
	var node := players.get_node_or_null(str(peer_id))
	if node != null:
		node.queue_free()


func _add_player(peer_id: int, display_name: String) -> void:
	if _known_players.has(peer_id):
		return

	var spawn_position := Vector2(240 + (_known_players.size() * 54), 220)
	_known_players[peer_id] = {
		"name": display_name,
		"position": spawn_position,
	}
	spawn_player.rpc(peer_id, display_name, spawn_position)


func _on_peer_left(peer_id: int) -> void:
	if multiplayer.is_server():
		_known_players.erase(peer_id)
		despawn_player.rpc(peer_id)


func request_local_skill(skill_name: String, target_peer_id: int = -1) -> bool:
	var player := _get_local_player()
	if player == null:
		return false

	if player.has_method("try_skill"):
		player.try_skill(skill_name, target_peer_id)
		return true
	if player.has_method("try_attack"):
		player.try_attack()
		return true
	return false


func set_local_stamina_bar(current_value: float, max_value: float) -> void:
	var player := _get_local_player()
	if player == null or not player.has_method("set_stamina_bar"):
		return

	player.set_stamina_bar(current_value, max_value)


func _get_local_player() -> Node:
	return players.get_node_or_null(str(multiplayer.get_unique_id()))
