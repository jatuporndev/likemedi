extends NetworkTransport
class_name EnetTransport

const DEFAULT_PORT := 8910
const MAX_PLAYERS := 8

var _peer: ENetMultiplayerPeer


func create_room(_player_name: String) -> Error:
	close()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_server(DEFAULT_PORT, MAX_PLAYERS - 1)
	if error != OK:
		connection_failed.emit("Could not host on UDP port %d." % DEFAULT_PORT)
		return error

	multiplayer_api.multiplayer_peer = _peer
	room_code = _build_room_code()
	await Engine.get_main_loop().process_frame
	return OK


func join_room(room_code_or_address: String, _player_name: String) -> Error:
	var endpoint := _parse_endpoint(room_code_or_address)
	if str(endpoint["address"]).is_empty():
		connection_failed.emit("Enter a host IP address.")
		return ERR_INVALID_PARAMETER

	close()
	_peer = ENetMultiplayerPeer.new()
	var error := _peer.create_client(endpoint["address"], endpoint["port"])
	if error != OK:
		connection_failed.emit("Could not start client connection to %s:%d." % [
			endpoint["address"],
			endpoint["port"],
		])
		return error

	multiplayer_api.multiplayer_peer = _peer
	room_code = "%s:%d" % [endpoint["address"], endpoint["port"]]
	await Engine.get_main_loop().process_frame
	return OK


func close() -> void:
	if multiplayer_api != null and multiplayer_api.multiplayer_peer != null:
		multiplayer_api.multiplayer_peer.close()
	if multiplayer_api != null:
		multiplayer_api.multiplayer_peer = null
	_peer = null


func get_name() -> String:
	return "enet"


func _build_room_code() -> String:
	var private_addresses := []
	var fallback_addresses := []
	for address in IP.get_local_addresses():
		if not _is_usable_ipv4(address):
			continue
		if _is_private_lan_ipv4(address):
			private_addresses.append(address)
		else:
			fallback_addresses.append(address)

	var ip := "127.0.0.1"
	if not private_addresses.is_empty():
		ip = private_addresses[0]
	elif not fallback_addresses.is_empty():
		ip = fallback_addresses[0]
	return "%s:%d" % [ip, DEFAULT_PORT]


func _parse_endpoint(endpoint_text: String) -> Dictionary:
	var endpoint := endpoint_text.strip_edges()
	if endpoint.begins_with("enet://"):
		endpoint = endpoint.trim_prefix("enet://")

	var address := endpoint
	var port := DEFAULT_PORT
	var port_separator := endpoint.rfind(":")
	if port_separator > -1:
		var port_text := endpoint.substr(port_separator + 1).strip_edges()
		if port_text.is_valid_int():
			port = int(port_text)
			address = endpoint.substr(0, port_separator)

	address = address.strip_edges()
	if address.begins_with("[") and address.ends_with("]"):
		address = address.substr(1, address.length() - 2)

	return {
		"address": address,
		"port": port,
	}


func _is_usable_ipv4(address: String) -> bool:
	if address.contains(":"):
		return false
	if address.begins_with("127."):
		return false
	if address.begins_with("169.254."):
		return false
	return address.is_valid_ip_address()


func _is_private_lan_ipv4(address: String) -> bool:
	if address.begins_with("10."):
		return true
	if address.begins_with("192.168."):
		return true

	var parts := address.split(".")
	if parts.size() == 4 and parts[0] == "172" and parts[1].is_valid_int():
		var second_octet := int(parts[1])
		return second_octet >= 16 and second_octet <= 31

	return false
