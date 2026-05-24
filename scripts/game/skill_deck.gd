extends RefCounted

const PLAYER_DECKS_CONFIG_PATH := "res://config/player_decks.json"
const PLAYER_DECKS_USER_PATH := "user://player_decks.json"
const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const MAX_DECK_CARDS := 25
const MAX_HAND_SIZE := 5

var draw_pile: Array[String] = []
var discard_pile: Array[String] = []
var hand: Array[String] = []
var is_shuffling := false
var is_waiting_to_draw_after_shuffle := false


func setup_default_deck() -> void:
	draw_pile = _load_deck("default")
	if draw_pile.is_empty():
		draw_pile = ["strike"]
	draw_pile.shuffle()
	discard_pile.clear()
	hand.clear()
	is_shuffling = false
	is_waiting_to_draw_after_shuffle = false


func can_add_to_hand() -> bool:
	return hand.size() < MAX_HAND_SIZE


func draw_card() -> String:
	if not can_add_to_hand():
		return ""
	if is_waiting_to_draw_after_shuffle or draw_pile.is_empty():
		return ""

	var skill_name: String = draw_pile.pop_front()
	hand.append(skill_name)
	return skill_name


func should_shuffle_before_draw() -> bool:
	return draw_pile.is_empty() and not discard_pile.is_empty() and not is_shuffling


func start_shuffle() -> void:
	if not should_shuffle_before_draw():
		return

	is_shuffling = true
	is_waiting_to_draw_after_shuffle = false


func finish_shuffle() -> void:
	draw_pile.clear()
	for skill_name in discard_pile:
		draw_pile.append(skill_name)
	draw_pile.shuffle()
	discard_pile.clear()
	is_shuffling = false
	is_waiting_to_draw_after_shuffle = true


func finish_draw_after_shuffle() -> void:
	is_waiting_to_draw_after_shuffle = false


func discard_card(skill_name: String) -> void:
	hand.erase(skill_name)
	if not skill_name.is_empty():
		discard_pile.append(skill_name)


func draw_pile_count() -> int:
	return draw_pile.size()


func discard_pile_count() -> int:
	return discard_pile.size()


func _load_deck(deck_id: String) -> Array[String]:
	var config_path := PLAYER_DECKS_CONFIG_PATH
	if FileAccess.file_exists(PLAYER_DECKS_USER_PATH):
		config_path = PLAYER_DECKS_USER_PATH
	elif not FileAccess.file_exists(config_path):
		push_warning("Player deck config not found: %s" % config_path)
		return []

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(config_path))
	if not (parsed is Dictionary):
		push_warning("Player deck config is not a dictionary: %s" % config_path)
		return []
	if not parsed.has(deck_id):
		push_warning("Deck id '%s' not found in %s" % [deck_id, config_path])
		return []

	var raw_deck = parsed[deck_id]
	if not (raw_deck is Array):
		push_warning("Deck id '%s' is not an array." % deck_id)
		return []

	var valid_skill_names := SKILL_CARD_DATABASE.get_all_skill_names()
	var deck: Array[String] = []
	for skill_name in raw_deck:
		var normalized_skill_name := str(skill_name)
		if valid_skill_names.has(normalized_skill_name):
			deck.append(normalized_skill_name)
	if deck.size() > MAX_DECK_CARDS:
		deck = deck.slice(0, MAX_DECK_CARDS)
	return deck
