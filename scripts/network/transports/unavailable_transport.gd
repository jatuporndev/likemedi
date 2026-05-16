extends NetworkTransport
class_name UnavailableTransport

var transport_name := "unavailable"
var unavailable_message := "Network transport is unavailable."


func create_room(_player_name: String) -> Error:
	await Engine.get_main_loop().process_frame
	connection_failed.emit(unavailable_message)
	return ERR_UNAVAILABLE


func join_room(_room_code_or_address: String, _player_name: String) -> Error:
	await Engine.get_main_loop().process_frame
	connection_failed.emit(unavailable_message)
	return ERR_UNAVAILABLE


func get_name() -> String:
	return transport_name
