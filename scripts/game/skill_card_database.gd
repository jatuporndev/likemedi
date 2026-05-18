extends RefCounted

const CONFIG_PATH := "res://config/cards.json"

static var _card_definitions: Dictionary = {}
static var _is_loaded := false


static func get_definition(skill_name: String) -> Dictionary:
	_ensure_loaded()
	if _card_definitions.has(skill_name):
		return _card_definitions[skill_name].duplicate(true)
	return _fallback_definition(skill_name)


static func _ensure_loaded() -> void:
	if _is_loaded:
		return

	_is_loaded = true
	_card_definitions.clear()
	if not FileAccess.file_exists(CONFIG_PATH):
		push_warning("Card config not found: %s" % CONFIG_PATH)
		_card_definitions["strike"] = _fallback_definition("strike")
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(CONFIG_PATH))
	if not (parsed is Dictionary):
		push_warning("Card config is not a dictionary: %s" % CONFIG_PATH)
		_card_definitions["strike"] = _fallback_definition("strike")
		return

	var cards = parsed.get("cards", {})
	if not (cards is Dictionary):
		push_warning("Card config has no cards dictionary: %s" % CONFIG_PATH)
		_card_definitions["strike"] = _fallback_definition("strike")
		return

	for skill_name in cards.keys():
		var raw_definition = cards[skill_name]
		if raw_definition is Dictionary:
			_card_definitions[str(skill_name)] = _normalize_definition(str(skill_name), raw_definition)


static func _normalize_definition(skill_name: String, raw_definition: Dictionary) -> Dictionary:
	var fallback := _fallback_definition(skill_name)
	var definition := {
		"title": str(raw_definition.get("title", fallback["title"])),
		"type": str(raw_definition.get("type", fallback["type"])),
		"cost": int(raw_definition.get("cost", fallback["cost"])),
		"cast_time": float(raw_definition.get("cast_time", fallback["cast_time"])),
		"damage": int(raw_definition.get("damage", fallback["damage"])),
		"heal": int(raw_definition.get("heal", fallback["heal"])),
		"range": float(raw_definition.get("range", fallback["range"])),
		"description": str(raw_definition.get("description", fallback["description"])),
		"bubble_text": str(raw_definition.get("bubble_text", fallback["bubble_text"])),
		"art_color": _parse_color(raw_definition.get("art_color", fallback["art_color"])),
	}
	return definition


static func _parse_color(value) -> Color:
	if value is Color:
		return value
	if value is Array and value.size() >= 3:
		var alpha := 1.0
		if value.size() >= 4:
			alpha = float(value[3])
		return Color(float(value[0]), float(value[1]), float(value[2]), alpha)
	if value is String:
		return Color(value)
	return Color(0.32, 0.08, 0.08, 1.0)


static func _fallback_definition(skill_name: String) -> Dictionary:
	if skill_name == "fireball":
		return {
			"title": "Fireball",
			"type": "spell",
			"cost": 2,
			"cast_time": 0.8,
			"damage": 35,
			"heal": 0,
			"range": 180.0,
			"description": "Deal 35 damage",
			"bubble_text": "Fireball!",
			"art_color": Color(0.82, 0.22, 0.04, 1.0),
		}
	if skill_name == "heal":
		return {
			"title": "Heal",
			"type": "heal",
			"cost": 4,
			"cast_time": 1.0,
			"damage": 0,
			"heal": 30,
			"range": 0.0,
			"description": "Restore 30 health",
			"bubble_text": "Heal!",
			"art_color": Color(0.12, 0.58, 0.30, 1.0),
		}
	return {
		"title": "Strike",
		"type": "attack",
		"cost": 1,
		"cast_time": 0.0,
		"damage": 5,
		"heal": 0,
		"range": 72.0,
		"description": "Deal 5 damage",
		"bubble_text": "Strike!",
		"art_color": Color(0.32, 0.08, 0.08, 1.0),
	}
