extends Node

signal connection_failed(message: String)
signal server_disconnected
signal peer_left(peer_id: int)
signal chat_message_received(sender_id: int, message: String)
signal world_registry_failed(message: String)
signal firebase_auth_changed(player_name: String)
signal firebase_auth_failed(message: String)

const WORLD_SCENE := "res://scenes/world/world.tscn"
const MENU_SCENE := "res://scenes/menu/main_menu.tscn"
const ENET_TRANSPORT := preload("res://scripts/network/transports/enet_transport.gd")
const UNAVAILABLE_TRANSPORT := preload("res://scripts/network/transports/unavailable_transport.gd")
const FIRESTORE_WORLD_REGISTRY := preload("res://scripts/network/firestore_world_registry.gd")
const EOS_TRANSPORT_PATH := "res://scripts/network/transports/eos_transport.gd"
const FIREBASE_CONFIG_PATH := "res://config/firebase.local.json"
const FIREBASE_IDENTITY_PATH := "user://firebase_auth_identity.json"
const FIREBASE_ANONYMOUS_SIGN_UP_URL := "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=%s"
const FIREBASE_REFRESH_TOKEN_URL := "https://securetoken.googleapis.com/v1/token?key=%s"
const FIREBASE_DEFAULT_PLAYERS_COLLECTION := "players"

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
var _firebase_project_id := ""
var _firebase_api_key := ""
var _firebase_players_collection := FIREBASE_DEFAULT_PLAYERS_COLLECTION
var _firebase_identity: Dictionary = {}
var _is_quitting := false
var _network_shutdown_done := false


func _ready() -> void:
	_load_firebase_config()
	_load_firebase_identity()
	_world_registry = FIRESTORE_WORLD_REGISTRY.new()
	_world_registry.request_failed.connect(_on_world_registry_failed)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	call_deferred("_ensure_firebase_anonymous_auth")


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


func get_firebase_player_name() -> String:
	return str(_firebase_identity.get("player_name", "")).strip_edges()


func get_firebase_player_id() -> String:
	return str(_firebase_identity.get("local_id", "")).strip_edges()


func save_firebase_player_name(player_name: String) -> bool:
	player_name = _clean_player_name(player_name, "Player")
	if not await _ensure_firebase_anonymous_auth():
		return false

	if str(_firebase_identity.get("player_name", "")) == player_name:
		return true

	_firebase_identity["player_name"] = player_name
	var saved: bool = await _save_firebase_player_profile()
	if saved:
		_save_firebase_identity()
		firebase_auth_changed.emit(player_name)
	return saved


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


func _load_firebase_config() -> void:
	if not FileAccess.file_exists(FIREBASE_CONFIG_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(FIREBASE_CONFIG_PATH)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var config: Dictionary = parsed
	_firebase_project_id = str(config.get("project_id", "")).strip_edges()
	_firebase_api_key = str(config.get("api_key", "")).strip_edges()
	_firebase_players_collection = str(config.get("collection_players", FIREBASE_DEFAULT_PLAYERS_COLLECTION)).strip_edges()
	if _firebase_players_collection.is_empty():
		_firebase_players_collection = FIREBASE_DEFAULT_PLAYERS_COLLECTION


func _load_firebase_identity() -> void:
	if not FileAccess.file_exists(FIREBASE_IDENTITY_PATH):
		return

	var json_text: String = FileAccess.get_file_as_string(FIREBASE_IDENTITY_PATH)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return

	var identity: Dictionary = parsed
	if str(identity.get("local_id", "")).is_empty():
		return

	_firebase_identity = identity


func _save_firebase_identity() -> void:
	var file: FileAccess = FileAccess.open(FIREBASE_IDENTITY_PATH, FileAccess.WRITE)
	if file == null:
		firebase_auth_failed.emit("Could not save Firebase identity locally.")
		return

	file.store_string(JSON.stringify(_firebase_identity, "\t"))


func _ensure_firebase_anonymous_auth() -> bool:
	if not _firebase_identity.is_empty():
		await _sync_firebase_player_profile()
		return true

	if _firebase_api_key.is_empty():
		firebase_auth_failed.emit("Firebase api_key is missing in config/firebase.local.json.")
		return false

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var body: String = JSON.stringify({"returnSecureToken": true})
	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/json"])
	var error: Error = request.request(
		FIREBASE_ANONYMOUS_SIGN_UP_URL % _firebase_api_key.uri_encode(),
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		request.queue_free()
		firebase_auth_failed.emit("Could not start Firebase anonymous auth request.")
		return false

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	if response_code < 200 or response_code >= 300:
		firebase_auth_failed.emit(_format_firebase_auth_error(response_code, response_body))
		return false

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		firebase_auth_failed.emit("Firebase anonymous auth returned an invalid response.")
		return false

	var auth_data: Dictionary = parsed
	var local_id: String = str(auth_data.get("localId", "")).strip_edges()
	if local_id.is_empty():
		firebase_auth_failed.emit("Firebase anonymous auth did not return a local id.")
		return false

	var player_name: String = _build_default_firebase_player_name(local_id)
	_firebase_identity = {
		"local_id": local_id,
		"id_token": str(auth_data.get("idToken", "")),
		"refresh_token": str(auth_data.get("refreshToken", "")),
		"expires_at": int(Time.get_unix_time_from_system()) + int(auth_data.get("expiresIn", "0")),
		"player_name": player_name,
	}
	_save_firebase_identity()
	await _sync_firebase_player_profile()
	return true


func _sync_firebase_player_profile() -> void:
	if get_firebase_player_id().is_empty():
		return
	if _firebase_project_id.is_empty():
		firebase_auth_failed.emit("Firebase project_id is missing in config/firebase.local.json.")
		return
	if not await _ensure_firebase_id_token():
		return

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var error: Error = request.request(
		_firestore_player_document_url(),
		_firestore_auth_headers(),
		HTTPClient.METHOD_GET
	)
	if error != OK:
		request.queue_free()
		firebase_auth_failed.emit("Could not start Firebase player profile request.")
		return

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	if response_code == 404:
		var created: bool = await _save_firebase_player_profile(true)
		if created:
			firebase_auth_changed.emit(get_firebase_player_name())
		return
	if response_code < 200 or response_code >= 300:
		firebase_auth_failed.emit(_format_firestore_player_error("Firebase player profile load failed", response_code, response_body))
		return

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		firebase_auth_failed.emit("Firebase player profile returned an invalid response.")
		return

	var document: Dictionary = parsed
	var fields: Dictionary = document.get("fields", {})
	var player_name: String = _read_firestore_string(fields, "player_name", get_firebase_player_name())
	if player_name.is_empty():
		player_name = _build_default_firebase_player_name(get_firebase_player_id())
	_firebase_identity["player_name"] = player_name
	_save_firebase_identity()
	firebase_auth_changed.emit(player_name)


func _save_firebase_player_profile(is_new_profile: bool = false) -> bool:
	if get_firebase_player_id().is_empty():
		firebase_auth_failed.emit("Firebase player id is missing.")
		return false
	if _firebase_project_id.is_empty():
		firebase_auth_failed.emit("Firebase project_id is missing in config/firebase.local.json.")
		return false
	if not await _ensure_firebase_id_token():
		return false

	var now: int = int(Time.get_unix_time_from_system())
	var player_name: String = get_firebase_player_name()
	if player_name.is_empty():
		player_name = _build_default_firebase_player_name(get_firebase_player_id())
		_firebase_identity["player_name"] = player_name

	var fields: Dictionary = {
		"identifier_id": {"stringValue": get_firebase_player_id()},
		"player_name": {"stringValue": player_name},
		"updated_at": {"integerValue": str(now)},
	}
	if is_new_profile:
		fields["created_at"] = {"integerValue": str(now)}

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var body: String = JSON.stringify({"fields": fields})
	var error: Error = request.request(
		_firestore_player_document_url(not is_new_profile),
		_firestore_auth_headers(),
		HTTPClient.METHOD_PATCH,
		body
	)
	if error != OK:
		request.queue_free()
		firebase_auth_failed.emit("Could not start Firebase player profile save request.")
		return false

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	if response_code < 200 or response_code >= 300:
		firebase_auth_failed.emit(_format_firestore_player_error("Firebase player profile save failed", response_code, response_body))
		return false

	return true


func _ensure_firebase_id_token() -> bool:
	var expires_at: int = int(_firebase_identity.get("expires_at", 0))
	if not str(_firebase_identity.get("id_token", "")).is_empty() and expires_at > int(Time.get_unix_time_from_system()) + 60:
		return true

	var refresh_token: String = str(_firebase_identity.get("refresh_token", "")).strip_edges()
	if refresh_token.is_empty():
		firebase_auth_failed.emit("Firebase refresh token is missing.")
		return false

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	var headers: PackedStringArray = PackedStringArray(["Content-Type: application/x-www-form-urlencoded"])
	var body: String = "grant_type=refresh_token&refresh_token=%s" % refresh_token.uri_encode()
	var error: Error = request.request(
		FIREBASE_REFRESH_TOKEN_URL % _firebase_api_key.uri_encode(),
		headers,
		HTTPClient.METHOD_POST,
		body
	)
	if error != OK:
		request.queue_free()
		firebase_auth_failed.emit("Could not start Firebase token refresh request.")
		return false

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]
	if response_code < 200 or response_code >= 300:
		firebase_auth_failed.emit(_format_firebase_auth_error(response_code, response_body))
		return false

	var parsed = JSON.parse_string(response_body.get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		firebase_auth_failed.emit("Firebase token refresh returned an invalid response.")
		return false

	var token_data: Dictionary = parsed
	_firebase_identity["id_token"] = str(token_data.get("id_token", ""))
	_firebase_identity["refresh_token"] = str(token_data.get("refresh_token", refresh_token))
	_firebase_identity["expires_at"] = int(Time.get_unix_time_from_system()) + int(token_data.get("expires_in", "0"))
	_save_firebase_identity()
	return true


func _firestore_player_document_url(with_player_update_mask: bool = false) -> String:
	var url: String = "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents/%s/%s?key=%s" % [
		_firebase_project_id.uri_encode(),
		_firebase_players_collection.uri_encode(),
		get_firebase_player_id().uri_encode(),
		_firebase_api_key.uri_encode(),
	]
	if with_player_update_mask:
		url += "&updateMask.fieldPaths=identifier_id"
		url += "&updateMask.fieldPaths=player_name"
		url += "&updateMask.fieldPaths=updated_at"
	return url


func _firestore_auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % str(_firebase_identity.get("id_token", "")),
	])


func _read_firestore_string(fields: Dictionary, key: String, fallback: String) -> String:
	var field = fields.get(key, {})
	if typeof(field) != TYPE_DICTIONARY:
		return fallback
	var field_data: Dictionary = field
	return str(field_data.get("stringValue", fallback))


func _build_default_firebase_player_name(local_id: String) -> String:
	var suffix: String = local_id.substr(0, mini(6, local_id.length())).to_upper()
	if suffix.is_empty():
		return "Player"
	return "Player %s" % suffix


func _format_firebase_auth_error(response_code: int, body: PackedByteArray) -> String:
	var detail: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(detail)
	if typeof(parsed) == TYPE_DICTIONARY:
		var response_data: Dictionary = parsed
		var error_data = response_data.get("error", {})
		if typeof(error_data) == TYPE_DICTIONARY:
			var error_dictionary: Dictionary = error_data
			detail = str(error_dictionary.get("message", detail))

	if detail.length() > 180:
		detail = detail.substr(0, 180) + "..."
	return "Firebase anonymous auth failed (%d): %s" % [response_code, detail]


func _format_firestore_player_error(prefix: String, response_code: int, body: PackedByteArray) -> String:
	var detail: String = body.get_string_from_utf8()
	var parsed = JSON.parse_string(detail)
	if typeof(parsed) == TYPE_DICTIONARY:
		var response_data: Dictionary = parsed
		var error_data = response_data.get("error", {})
		if typeof(error_data) == TYPE_DICTIONARY:
			var error_dictionary: Dictionary = error_data
			detail = str(error_dictionary.get("message", detail))

	if detail.length() > 180:
		detail = detail.substr(0, 180) + "..."
	return "%s (%d): %s" % [prefix, response_code, detail]


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
