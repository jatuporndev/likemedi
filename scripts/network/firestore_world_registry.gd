extends RefCounted
class_name FirestoreWorldRegistry

signal request_failed(message: String)

const CONFIG_PATH := "res://config/firebase.local.json"
const DEFAULT_COLLECTION := "worlds"

var project_id := ""
var api_key := ""
var collection := DEFAULT_COLLECTION


func _init() -> void:
	var config := _load_config()
	project_id = str(config.get("project_id", ""))
	api_key = str(config.get("api_key", ""))
	collection = str(config.get("collection", DEFAULT_COLLECTION))


func is_configured() -> bool:
	return not project_id.is_empty()


func fetch_public_worlds(owner: Node) -> Array[Dictionary]:
	if not is_configured():
		request_failed.emit("Firebase is not configured. Create config/firebase.local.json.")
		return []

	var request := _create_request(owner)
	var error := request.request(_collection_url())
	if error != OK:
		request.queue_free()
		request_failed.emit("Could not start Firestore world list request.")
		return []

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code := int(response[1])
	if response_code < 200 or response_code >= 300:
		request_failed.emit(_format_error("Firestore world list failed", response_code, response[3]))
		return []

	var parsed = JSON.parse_string(response[3].get_string_from_utf8())
	if typeof(parsed) != TYPE_DICTIONARY:
		return []

	var worlds: Array[Dictionary] = []
	for document in parsed.get("documents", []):
		if typeof(document) != TYPE_DICTIONARY:
			continue
		var world := _document_to_world(document)
		if bool(world.get("public", false)):
			worlds.append(world)

	worlds.sort_custom(_sort_worlds_by_updated_at)
	return worlds


func publish_world(owner: Node, world: Dictionary) -> String:
	if not is_configured():
		request_failed.emit("Firebase is not configured. Create config/firebase.local.json.")
		return ""

	var room_code := str(world.get("eos_room_code", ""))
	if room_code.is_empty():
		request_failed.emit("EOS room code is empty, so the world cannot be published.")
		return ""

	var doc_id := room_code.uri_encode()
	var request := _create_request(owner)
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify({"fields": _world_to_fields(world)})
	var error := request.request(_document_url(doc_id), headers, HTTPClient.METHOD_PATCH, body)
	if error != OK:
		request.queue_free()
		request_failed.emit("Could not start Firestore publish request.")
		return ""

	var response: Array = await request.request_completed
	request.queue_free()

	var response_code := int(response[1])
	if response_code < 200 or response_code >= 300:
		request_failed.emit(_format_error("Firestore publish failed", response_code, response[3]))
		return ""
	return doc_id


func remove_world(owner: Node, doc_id: String) -> void:
	if not is_configured() or doc_id.is_empty():
		return

	var request := _create_request(owner)
	var error := request.request(_document_url(doc_id), [], HTTPClient.METHOD_DELETE)
	if error == OK:
		await request.request_completed
	request.queue_free()


func get_config_summary() -> String:
	if not is_configured():
		return "Firebase is not configured."
	return "Firebase project '%s', collection '%s'" % [project_id, collection]


func _create_request(owner: Node) -> HTTPRequest:
	var request := HTTPRequest.new()
	owner.add_child(request)
	return request


func _collection_url() -> String:
	return "%s/%s?%s" % [_base_url(), collection.uri_encode(), _query_string()]


func _document_url(doc_id: String) -> String:
	return "%s/%s/%s?%s" % [_base_url(), collection.uri_encode(), doc_id, _query_string()]


func _base_url() -> String:
	return "https://firestore.googleapis.com/v1/projects/%s/databases/(default)/documents" % project_id.uri_encode()


func _query_string() -> String:
	if api_key.is_empty():
		return ""
	return "key=%s" % api_key.uri_encode()


func _world_to_fields(world: Dictionary) -> Dictionary:
	var now := int(Time.get_unix_time_from_system())
	return {
		"world_name": {"stringValue": str(world.get("world_name", "New World"))},
		"host_name": {"stringValue": str(world.get("host_name", "Host"))},
		"eos_room_code": {"stringValue": str(world.get("eos_room_code", ""))},
		"public": {"booleanValue": bool(world.get("public", true))},
		"player_count": {"integerValue": str(world.get("player_count", 1))},
		"updated_at": {"integerValue": str(world.get("updated_at", now))},
	}


func _document_to_world(document: Dictionary) -> Dictionary:
	var fields: Dictionary = document.get("fields", {})
	var name := str(document.get("name", ""))
	return {
		"id": name.get_file(),
		"world_name": _read_string(fields, "world_name", "Unnamed World"),
		"host_name": _read_string(fields, "host_name", "Unknown"),
		"eos_room_code": _read_string(fields, "eos_room_code", ""),
		"public": _read_bool(fields, "public", false),
		"player_count": _read_int(fields, "player_count", 1),
		"updated_at": _read_int(fields, "updated_at", 0),
	}


func _read_string(fields: Dictionary, key: String, fallback: String) -> String:
	var field = fields.get(key, {})
	if typeof(field) != TYPE_DICTIONARY:
		return fallback
	return str(field.get("stringValue", fallback))


func _read_bool(fields: Dictionary, key: String, fallback: bool) -> bool:
	var field = fields.get(key, {})
	if typeof(field) != TYPE_DICTIONARY:
		return fallback
	return bool(field.get("booleanValue", fallback))


func _read_int(fields: Dictionary, key: String, fallback: int) -> int:
	var field = fields.get(key, {})
	if typeof(field) != TYPE_DICTIONARY:
		return fallback
	return int(field.get("integerValue", fallback))


func _sort_worlds_by_updated_at(left: Dictionary, right: Dictionary) -> bool:
	return int(left.get("updated_at", 0)) > int(right.get("updated_at", 0))


func _format_error(prefix: String, response_code: int, body: PackedByteArray) -> String:
	var detail := body.get_string_from_utf8()
	var parsed = JSON.parse_string(detail)
	if typeof(parsed) == TYPE_DICTIONARY:
		var error_data = parsed.get("error", {})
		if typeof(error_data) == TYPE_DICTIONARY:
			detail = str(error_data.get("message", detail))

	if detail.length() > 180:
		detail = detail.substr(0, 180) + "..."
	return "%s (%d): %s" % [prefix, response_code, detail]


func _load_config() -> Dictionary:
	if not FileAccess.file_exists(CONFIG_PATH):
		return {}

	var json_text := FileAccess.get_file_as_string(CONFIG_PATH)
	var parsed = JSON.parse_string(json_text)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
