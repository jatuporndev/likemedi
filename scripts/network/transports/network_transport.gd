extends RefCounted
class_name NetworkTransport

signal connection_failed(message: String)

var room_code := ""
var multiplayer_api: MultiplayerAPI


func setup(p_multiplayer_api: MultiplayerAPI) -> void:
	multiplayer_api = p_multiplayer_api


func create_room(_player_name: String) -> Error:
	await Engine.get_main_loop().process_frame
	return ERR_UNAVAILABLE


func join_room(_room_code_or_address: String, _player_name: String) -> Error:
	await Engine.get_main_loop().process_frame
	return ERR_UNAVAILABLE


func close() -> void:
	if multiplayer_has_peer():
		multiplayer_api.multiplayer_peer.close()
	if multiplayer_api != null:
		multiplayer_api.multiplayer_peer = null


func multiplayer_has_peer() -> bool:
	return multiplayer_api != null and multiplayer_api.multiplayer_peer != null


func get_room_code() -> String:
	return room_code


func get_name() -> String:
	return "unknown"
