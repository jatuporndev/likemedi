extends Node

signal connection_failed(message: String)
signal server_disconnected
signal peer_left(peer_id: int)
signal chat_message_received(sender_id: int, message: String)
signal world_registry_failed(message: String)

const WORLD_SCENE := "res://scenes/world/world.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const ENET_TRANSPORT := preload("res://scripts/network/transports/enet_transport.gd")
const UNAVAILABLE_TRANSPORT := preload("res://scripts/network/transports/unavailable_transport.gd")
const FIRESTORE_WORLD_REGISTRY := preload("res://scripts/network/firestore_world_registry.gd")
const EOS_TRANSPORT_PATH := "res://scripts/network/transports/eos_transport.gd"

var player_names: Dictionary = {}
var last_error := ""
var transport_mode := "enet"
var server_name := "Local Server"
var dedicated_server_enabled := false

var _transport: NetworkTransport
var _world_registry: FirestoreWorldRegistry
var _published_world_doc_id := ""
var _published_world_name := ""
var _published_host_name := ""
var _is_quitting := false
var _network_shutdown_done := false


func _ready() -> void:
	_world_registry = FIRESTORE_WORLD_REGISTRY.new()
	_world_registry.request_failed.connect(_on_world_registry_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		quit_game()
	elif what == NOTIFICATION_PREDELETE:
		_shutdown_network()


func host_game(player_name := "Host", world_name := "", is_public := false) -> void:
	dedicated_server_enabled = false
	player_name = _clean_player_name(player_name, "Host")
	_ensure_transport()
	var error: Error = await _transport.create_room(player_name)
	if error != OK:
		return

	if _transport.get_name() == "eos" and is_public:
		world_name = _clean_player_name(world_name, "%s's World" % player_name)
		_published_world_name = world_name
		_published_host_name = player_name
		_published_world_doc_id = await _world_registry.publish_world(
			self,
			{
				"world_name": world_name,
				"host_name": player_name,
				"eos_room_code": _transport.get_room_code(),
				"public": true,
				"player_count": 1,
			}
		)
		if _published_world_doc_id.is_empty():
			close_current_peer()
			return

	player_names = {1: player_name}
	get_tree().change_scene_to_file(WORLD_SCENE)


func host_dedicated_server(p_server_name := "Local Server") -> void:
	dedicated_server_enabled = true
	server_name = _clean_player_name(p_server_name, "Local Server")
	_ensure_transport()
	var error: Error = await _transport.create_room(server_name)
	if error != OK:
		dedicated_server_enabled = false
		return

	player_names = {}
	get_tree().change_scene_to_file(WORLD_SCENE)


func join_game(address: String, player_name := "Player") -> void:
	dedicated_server_enabled = false
	player_name = _clean_player_name(player_name, "Player")
	_ensure_transport()
	player_names = {0: player_name}
	var error: Error = await _transport.join_room(address, player_name)
	if error != OK:
		return


func fetch_public_worlds() -> Array[Dictionary]:
	return await _world_registry.fetch_public_worlds(self)


func get_world_registry_status() -> String:
	return _world_registry.get_config_summary()


func leave_game() -> void:
	_close_peer()
	get_tree().change_scene_to_file(MENU_SCENE)


func close_current_peer() -> void:
	_close_peer()


func quit_game() -> void:
	if _is_quitting:
		return

	_is_quitting = true
	_shutdown_network()
	get_tree().quit()


func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()


func is_dedicated_server() -> bool:
	return dedicated_server_enabled and is_host()


func set_transport_mode(mode: String) -> void:
	if mode != "enet" and mode != "eos":
		return
	ProjectSettings.set_setting("likemedieval/network/transport", mode)
	transport_mode = mode
	if _transport != null and _transport.get_name() != mode:
		_transport.close()
		_transport = null


func get_transport_mode() -> String:
	return str(ProjectSettings.get_setting("likemedieval/network/transport", transport_mode))


func get_host_info() -> String:
	_ensure_transport()
	return _transport.get_room_code()


func submit_chat_message(message: String) -> void:
	message = message.strip_edges()
	if message.is_empty():
		return

	if is_host():
		_receive_chat_message.rpc(multiplayer.get_unique_id(), message)
	else:
		_send_chat_message.rpc_id(1, message)


@rpc("any_peer", "reliable")
func register_player_name(player_name: String) -> void:
	if not is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	player_names[sender_id] = _clean_player_name(player_name, "Player %d" % sender_id)
	_update_published_world_player_count()


@rpc("any_peer", "reliable")
func _send_chat_message(message: String) -> void:
	if not is_host():
		return
	var sender_id := multiplayer.get_remote_sender_id()
	_receive_chat_message.rpc(sender_id, message.strip_edges())


@rpc("authority", "call_local", "reliable")
func _receive_chat_message(sender_id: int, message: String) -> void:
	chat_message_received.emit(sender_id, message)


func _on_connected_to_server() -> void:
	var requested_name := str(player_names.get(0, "Player"))
	register_player_name.rpc_id(1, requested_name)
	get_tree().change_scene_to_file(WORLD_SCENE)


func _on_connection_failed() -> void:
	last_error = "Could not connect to host."
	_close_peer()
	connection_failed.emit(last_error)


func _on_server_disconnected() -> void:
	_close_peer()
	server_disconnected.emit()
	get_tree().change_scene_to_file(MENU_SCENE)


func _on_peer_disconnected(peer_id: int) -> void:
	player_names.erase(peer_id)
	_update_published_world_player_count()
	peer_left.emit(peer_id)


func _close_peer() -> void:
	if not _published_world_doc_id.is_empty():
		_world_registry.remove_world(self, _published_world_doc_id)
		_published_world_doc_id = ""
		_published_world_name = ""
		_published_host_name = ""

	if _transport != null:
		_transport.close()
	else:
		if multiplayer.multiplayer_peer != null:
			multiplayer.multiplayer_peer.close()
		multiplayer.multiplayer_peer = null


func _update_published_world_player_count() -> void:
	if _published_world_doc_id.is_empty() or _world_registry == null:
		return

	await _world_registry.publish_world(
		self,
		{
			"world_name": _published_world_name,
			"host_name": str(player_names.get(1, _published_host_name)),
			"eos_room_code": _published_world_doc_id.uri_decode(),
			"public": true,
			"player_count": player_names.size(),
		}
	)


func _shutdown_network() -> void:
	if _network_shutdown_done:
		return

	_network_shutdown_done = true
	_close_peer()
	if ClassDB.class_exists("EOSGMultiplayerPeer"):
		EOS.Platform.PlatformInterface.release()
		EOS.Platform.PlatformInterface.shutdown()


func _clean_player_name(player_name: String, fallback: String) -> String:
	player_name = player_name.strip_edges()
	if player_name.is_empty():
		return fallback
	return player_name


func _ensure_transport() -> void:
	var selected_mode := str(ProjectSettings.get_setting("likemedieval/network/transport", transport_mode))
	if _transport != null and _transport.get_name() == selected_mode:
		return

	if _transport != null:
		_transport.close()

	transport_mode = selected_mode
	if transport_mode == "eos":
		if not ClassDB.class_exists("EOSGMultiplayerPeer"):
			_transport = UNAVAILABLE_TRANSPORT.new()
			_transport.transport_name = "eos"
			_transport.unavailable_message = "EOSG addon is not installed or enabled."
			_transport.setup(multiplayer)
			_transport.connection_failed.connect(_on_transport_connection_failed)
			return

		var eos_script := load(EOS_TRANSPORT_PATH)
		if eos_script != null:
			_transport = eos_script.new()
		else:
			_transport = UNAVAILABLE_TRANSPORT.new()
			_transport.transport_name = "eos"
			_transport.unavailable_message = "EOS transport could not load."
	else:
		_transport = ENET_TRANSPORT.new()

	_transport.setup(multiplayer)
	_transport.connection_failed.connect(_on_transport_connection_failed)


func _on_transport_connection_failed(message: String) -> void:
	last_error = message
	connection_failed.emit(message)


func _on_world_registry_failed(message: String) -> void:
	last_error = message
	world_registry_failed.emit(message)
