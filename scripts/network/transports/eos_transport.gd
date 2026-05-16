extends NetworkTransport

const SOCKET_NAME := "likemedievalgame"
const CONFIG_PATH := "res://config/eos.local.json"
const FALLBACK_CREDENTIALS_PATH := "res://docs/eos-credentials.md"

var _peer
var _lobby
var _ready := false


func create_room(player_name: String) -> Error:
	var setup_error := await _ensure_ready(player_name)
	if setup_error != OK:
		return setup_error

	_peer = EOSGMultiplayerPeer.new()
	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)

	var error = _peer.create_server(SOCKET_NAME)
	if error != OK:
		connection_failed.emit("EOS P2P host creation failed.")
		return error

	_peer.set_auto_accept_connection_requests(true)
	multiplayer_api.multiplayer_peer = _peer

	var lobby_error := await _create_lobby(player_name)
	if lobby_error != OK:
		close()
		return lobby_error

	room_code = str(_lobby.lobby_id)
	return OK


func join_room(room_code_or_address: String, player_name: String) -> Error:
	var setup_error := await _ensure_ready(player_name)
	if setup_error != OK:
		return setup_error

	var lobby_id := room_code_or_address.strip_edges()
	if lobby_id.is_empty():
		connection_failed.emit("Enter an EOS room code.")
		return ERR_INVALID_PARAMETER

	_lobby = await HLobbies.join_by_id_async(lobby_id)
	if not _lobby:
		connection_failed.emit("Could not join EOS lobby.")
		return ERR_CANT_CONNECT

	var host_user_id := str(_lobby.owner_product_user_id)
	_peer = EOSGMultiplayerPeer.new()
	HP2P.set_relay_control(EOS.P2P.RelayControl.AllowRelays)

	var error = _peer.create_client(SOCKET_NAME, host_user_id)
	if error != OK:
		connection_failed.emit("EOS P2P client connection failed.")
		return error

	multiplayer_api.multiplayer_peer = _peer
	room_code = lobby_id
	return OK


func close() -> void:
	if _lobby:
		if _lobby.is_owner():
			_lobby.destroy_async()
		else:
			_lobby.leave_async()
	_lobby = null

	if multiplayer_api != null and multiplayer_api.multiplayer_peer != null:
		multiplayer_api.multiplayer_peer.close()
	if multiplayer_api != null:
		multiplayer_api.multiplayer_peer = null
	_peer = null


func get_name() -> String:
	return "eos"


func _ensure_ready(player_name: String) -> Error:
	if _ready:
		return OK

	if not ClassDB.class_exists("EOSGMultiplayerPeer"):
		connection_failed.emit("EOSG addon is not installed or enabled.")
		return ERR_UNAVAILABLE

	var credentials_data := _load_credentials()
	if credentials_data.is_empty():
		connection_failed.emit("Missing EOS credentials.")
		return ERR_FILE_CANT_READ

	var credentials = HCredentials.new()
	credentials.product_name = str(credentials_data.get("product_name", "likemedieval"))
	credentials.product_version = str(credentials_data.get("product_version", "0.1.0"))
	credentials.product_id = str(credentials_data.get("product_id", ""))
	credentials.sandbox_id = str(credentials_data.get("sandbox_id", ""))
	credentials.deployment_id = str(credentials_data.get("deployment_id", ""))
	credentials.client_id = str(credentials_data.get("client_id", ""))
	credentials.client_secret = str(credentials_data.get("client_secret", ""))
	credentials.encryption_key = str(credentials_data.get("encryption_key", ""))

	var setup_success := await HPlatform.setup_eos_async(credentials)
	if not setup_success:
		connection_failed.emit("EOS setup failed.")
		return ERR_CANT_CREATE

	var logged_in := await _login(credentials_data, player_name)
	if not logged_in:
		connection_failed.emit("EOS login failed.")
		return ERR_CANT_CONNECT

	_ready = true
	return OK


func _login(credentials_data: Dictionary, player_name: String) -> bool:
	var login_method := str(credentials_data.get("login_method", "anonymous"))
	match login_method:
		"devtool":
			var host := str(credentials_data.get("devtool_host", "localhost:4545"))
			var credential_name := str(credentials_data.get("devtool_credential_name", player_name))
			return await HAuth.login_devtool_async(host, credential_name)
		"account_portal":
			return await HAuth.login_account_portal_async()
		_:
			return await HAuth.login_anonymous_async(player_name)


func _create_lobby(player_name: String) -> Error:
	var opts = EOS.Lobby.CreateLobbyOptions.new()
	opts.bucket_id = "likemedieval"
	opts.max_lobby_members = 8
	opts.permission_level = EOS.Lobby.LobbyPermissionLevel.PublicAdvertised
	opts.allow_invites = false
	opts.enable_join_by_id = true
	opts.presence_enabled = false
	opts.enable_rtc_room = false

	_lobby = await HLobbies.create_lobby_async(opts)
	if not _lobby:
		connection_failed.emit("Could not create EOS lobby.")
		return ERR_CANT_CREATE

	_lobby.add_attribute("game", "likemedieval")
	_lobby.add_attribute("transport", "eos_p2p")
	_lobby.add_attribute("host_name", player_name)
	_lobby.add_current_member_attribute("username", player_name)
	await _lobby.update_async()
	return OK


func _load_credentials() -> Dictionary:
	if FileAccess.file_exists(CONFIG_PATH):
		var json_text := FileAccess.get_file_as_string(CONFIG_PATH)
		var parsed = JSON.parse_string(json_text)
		if typeof(parsed) == TYPE_DICTIONARY:
			return parsed

	if not FileAccess.file_exists(FALLBACK_CREDENTIALS_PATH):
		return {}

	var text := FileAccess.get_file_as_string(FALLBACK_CREDENTIALS_PATH)
	return _parse_sample_constants(text)


func _parse_sample_constants(text: String) -> Dictionary:
	return {
		"product_id": _find_constant(text, "ProductId"),
		"sandbox_id": _find_constant(text, "SandboxId"),
		"deployment_id": _find_constant(text, "DeploymentId"),
		"client_id": _find_constant(text, "ClientCredentialsId"),
		"client_secret": _find_constant(text, "ClientCredentialsSecret"),
		"product_name": _find_constant(text, "GameName", "likemedieval"),
		"product_version": "0.1.0",
		"encryption_key": _find_constant(text, "EncryptionKey"),
		"login_method": "anonymous",
	}


func _find_constant(text: String, constant_name: String, fallback := "") -> String:
	var pattern := "static constexpr char %s[]" % constant_name
	var line_start := text.find(pattern)
	if line_start == -1:
		return fallback

	var quote_start := text.find("\"", line_start)
	if quote_start == -1:
		return fallback

	var quote_end := text.find("\"", quote_start + 1)
	if quote_end == -1:
		return fallback

	var value := text.substr(quote_start + 1, quote_end - quote_start - 1)
	if value.is_empty():
		return fallback
	return value
