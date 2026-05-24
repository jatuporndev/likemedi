extends Control

signal closed
signal deck_changed

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const DECK_CARD := preload("res://scripts/ui/deck_builder_card.gd")

const RES_DECKS_PATH := "res://config/player_decks.json"
const USER_DECKS_PATH := "user://player_decks.json"
const RES_COLLECTION_PATH := "res://config/player_collection.json"
const USER_COLLECTION_PATH := "user://player_collection.json"

const DECK_ID := "default"
const MAX_DECK_CARDS := 25
const DRAG_RETURN_SECONDS := 0.16

const COLOR_INK := Color(0.045, 0.032, 0.024, 1.0)
const COLOR_PANEL := Color(0.075, 0.055, 0.038, 0.96)
const COLOR_PANEL_SOFT := Color(0.12, 0.085, 0.052, 0.88)
const COLOR_GOLD := Color(0.82, 0.55, 0.22, 1.0)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.78, 0.34, 1.0)
const COLOR_TEXT := Color(0.94, 0.86, 0.68, 1.0)
const COLOR_MUTED_TEXT := Color(0.67, 0.56, 0.38, 1.0)
const COLOR_RED := Color(0.55, 0.14, 0.09, 1.0)

var _deck: Array[String] = []
var _deck_counts: Dictionary = {}
var _collection_counts: Dictionary = {}

var _type_filter: OptionButton
var _search_edit: LineEdit
var _deck_grid: GridContainer
var _library_grid: GridContainer
var _deck_count_label: Label
var _status_label: Label
var _deck_drop_area: Control
var _library_drop_area: Control

var _dragging := false
var _drag_skill_name := ""
var _drag_from := ""
var _drag_definition: Dictionary = {}
var _drag_card: DeckBuilderCard
var _drag_card_start_position := Vector2.ZERO
var _drag_card_tween: Tween
var _drag_source_parent: Container
var _drag_source_index := -1
var _drag_placeholder: Control
var _drag_placeholder_grid: GridContainer
var _drag_placeholder_index := -1


func _ready() -> void:
	_load_collection()
	_load_deck()
	_build_ui()
	_refresh_all()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		closed.emit()
		queue_free()
		get_viewport().set_input_as_handled()
		return


func _input(event: InputEvent) -> void:
	if not _dragging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_drag(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()


func _process(_delta: float) -> void:
	if not _dragging or _drag_card == null:
		return

	var mouse_pos := get_viewport().get_mouse_position()
	_move_drag_card_to_mouse(mouse_pos, false)
	_update_drag_placeholder(mouse_pos)


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.color = COLOR_INK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(1160, 660)
	panel.offset_left = -580
	panel.offset_top = -330
	panel.offset_right = 580
	panel.offset_bottom = 330
	panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL, COLOR_GOLD, 2, 8))
	add_child(panel)

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 14)
	root.add_theme_constant_override("margin_top", 14)
	root.add_theme_constant_override("margin_right", 14)
	root.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(root)

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 10)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	layout.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_on_back_pressed)
	back_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(back_button)
	header.add_child(back_button)

	var title := Label.new()
	title.text = "Deck Builder"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.add_theme_font_size_override("font_size", 26)
	header.add_child(title)

	var reset_button := Button.new()
	reset_button.text = "Reset"
	reset_button.pressed.connect(_on_reset_pressed)
	reset_button.mouse_filter = Control.MOUSE_FILTER_STOP
	_style_button(reset_button)
	header.add_child(reset_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 14)
	columns.mouse_filter = Control.MOUSE_FILTER_PASS
	layout.add_child(columns)

	columns.add_child(_build_deck_column())
	columns.add_child(_build_library_column())

	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_status_label.add_theme_font_size_override("font_size", 12)
	layout.add_child(_status_label)


func _build_deck_column() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(520, 0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL_SOFT, COLOR_GOLD, 2, 8))
	_deck_drop_area = panel

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(root)

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var title := Label.new()
	title.text = "Deck (drag cards here)"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 18)
	header.add_child(title)

	_deck_count_label = Label.new()
	_deck_count_label.text = "0/%d" % MAX_DECK_CARDS
	_deck_count_label.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	_deck_count_label.add_theme_font_size_override("font_size", 14)
	header.add_child(_deck_count_label)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 6)
	grid_margin.add_theme_constant_override("margin_top", 6)
	grid_margin.add_theme_constant_override("margin_right", 22)
	grid_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(grid_margin)
	grid_margin.mouse_filter = Control.MOUSE_FILTER_PASS

	_deck_grid = GridContainer.new()
	_deck_grid.columns = 4
	_deck_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deck_grid.add_theme_constant_override("h_separation", 10)
	_deck_grid.add_theme_constant_override("v_separation", 10)
	_deck_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_margin.add_child(_deck_grid)

	return panel


func _build_library_column() -> Control:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL_SOFT, COLOR_GOLD, 2, 8))
	_library_drop_area = panel

	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override("margin_left", 12)
	root.add_theme_constant_override("margin_top", 10)
	root.add_theme_constant_override("margin_right", 12)
	root.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(root)

	var layout := VBoxContainer.new()
	layout.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_theme_constant_override("separation", 8)
	root.add_child(layout)

	var title := Label.new()
	title.text = "Library (drag to deck)"
	title.add_theme_color_override("font_color", COLOR_TEXT)
	title.add_theme_font_size_override("font_size", 18)
	layout.add_child(title)

	var filters := HBoxContainer.new()
	filters.add_theme_constant_override("separation", 8)
	layout.add_child(filters)

	_type_filter = OptionButton.new()
	_type_filter.add_item("All", 0)
	_type_filter.add_item("Attack", 1)
	_type_filter.add_item("Spell", 2)
	_type_filter.add_item("Heal", 3)
	_type_filter.add_item("Buff", 4)
	_type_filter.add_item("Debuff", 5)
	_type_filter.item_selected.connect(_on_filters_changed)
	filters.add_child(_type_filter)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search cards..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(_on_search_changed)
	_style_line_edit(_search_edit)
	filters.add_child(_search_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)

	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 6)
	grid_margin.add_theme_constant_override("margin_top", 6)
	grid_margin.add_theme_constant_override("margin_right", 22)
	grid_margin.add_theme_constant_override("margin_bottom", 16)
	scroll.add_child(grid_margin)
	grid_margin.mouse_filter = Control.MOUSE_FILTER_PASS

	_library_grid = GridContainer.new()
	_library_grid.columns = 4
	_library_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_library_grid.add_theme_constant_override("h_separation", 10)
	_library_grid.add_theme_constant_override("v_separation", 10)
	_library_grid.mouse_filter = Control.MOUSE_FILTER_STOP
	grid_margin.add_child(_library_grid)

	return panel


func _refresh_all() -> void:
	_rebuild_deck_counts()
	_update_deck_count_label()
	_rebuild_deck_grid()
	_rebuild_library_grid()


func _rebuild_deck_counts() -> void:
	_deck_counts.clear()
	for skill_name in _deck:
		var key := str(skill_name)
		_deck_counts[key] = int(_deck_counts.get(key, 0)) + 1


func _update_deck_count_label() -> void:
	if _deck_count_label == null:
		return

	var total := _deck.size()
	_deck_count_label.text = "%d/%d" % [total, MAX_DECK_CARDS]
	_deck_count_label.add_theme_color_override(
		"font_color",
		COLOR_RED if total > MAX_DECK_CARDS else COLOR_GOLD_BRIGHT
	)


func _rebuild_deck_grid() -> void:
	if _deck_grid == null:
		return

	for child in _deck_grid.get_children():
		child.queue_free()

	if _deck.is_empty():
		var empty := Label.new()
		empty.text = "Drop cards here"
		empty.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
		empty.add_theme_font_size_override("font_size", 12)
		_deck_grid.add_child(empty)
		return

	for skill_name in _deck:
		_deck_grid.add_child(_create_drag_card(skill_name, "deck"))


func _rebuild_library_grid() -> void:
	if _library_grid == null:
		return

	for child in _library_grid.get_children():
		child.queue_free()

	var filter_type := _get_selected_filter_type()
	var search_text := _search_edit.text.strip_edges().to_lower() if is_instance_valid(_search_edit) else ""

	for skill_name in SKILL_CARD_DATABASE.get_all_skill_names():
		var definition: Dictionary = SKILL_CARD_DATABASE.get_definition(skill_name)
		if not _matches_filter(definition, filter_type, search_text):
			continue

		var available := _get_available_count(skill_name)
		for _copy_index in range(available):
			_library_grid.add_child(_create_drag_card(skill_name, "library"))


func _create_drag_card(skill_name: String, from: String) -> Control:
	var definition: Dictionary = SKILL_CARD_DATABASE.get_definition(skill_name)
	var card := DECK_CARD.new()
	card.setup(skill_name, definition, from)
	card.drag_requested.connect(_start_drag)
	return card


func _get_available_count(skill_name: String) -> int:
	var owned := int(_collection_counts.get(skill_name, 0))
	var in_deck := int(_deck_counts.get(skill_name, 0))
	return maxi(0, owned - in_deck)


func _on_filters_changed(_index: int) -> void:
	_rebuild_library_grid()


func _on_search_changed(_text: String) -> void:
	_rebuild_library_grid()


func _get_selected_filter_type() -> String:
	if _type_filter == null:
		return ""
	match _type_filter.get_selected_id():
		1:
			return "attack"
		2:
			return "spell"
		3:
			return "heal"
		4:
			return "buff"
		5:
			return "debuff"
		_:
			return ""


func _matches_filter(definition: Dictionary, filter_type: String, search_text: String) -> bool:
	var type_text := str(definition.get("type", "")).to_lower()
	if not filter_type.is_empty() and type_text != filter_type:
		return false

	if search_text.is_empty():
		return true

	var title := str(definition.get("title", "")).to_lower()
	var description := str(definition.get("description", "")).to_lower()
	return title.contains(search_text) or description.contains(search_text) or type_text.contains(search_text)


func _start_drag(card: DeckBuilderCard, skill_name: String, from: String, definition: Dictionary) -> void:
	if _dragging or _drag_card_tween != null:
		return

	var source_parent := card.get_parent() as Container
	if source_parent == null:
		return

	_dragging = true
	_drag_skill_name = skill_name
	_drag_from = from
	_drag_definition = definition
	_drag_card = card
	_drag_card_start_position = card.global_position
	_drag_source_parent = source_parent
	_drag_source_index = card.get_index()
	_create_drag_placeholder(card.custom_minimum_size)
	_move_placeholder_to_grid(source_parent as GridContainer, _drag_source_index)
	card.reparent(self, true)
	_drag_card.top_level = true
	_drag_card.z_index = 2000
	_drag_card.modulate.a = 0.88
	_drag_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_move_drag_card_to_mouse(get_viewport().get_mouse_position(), true)


func _finish_drag(mouse_pos: Vector2) -> void:
	if not _dragging:
		return

	var should_add_to_deck := _drag_from == "library" and _is_over_control(_deck_drop_area, mouse_pos)
	var should_remove_from_deck := _drag_from == "deck" and _is_over_control(_library_drop_area, mouse_pos)
	var should_reorder_deck := (
		_drag_from == "deck"
		and _is_over_control(_deck_drop_area, mouse_pos)
		and _drag_placeholder_grid == _deck_grid
		and _drag_placeholder_index >= 0
	)
	var dropped := should_add_to_deck or should_remove_from_deck or should_reorder_deck
	var skill_name := _drag_skill_name
	var insert_index := _drag_placeholder_index
	var source_index := _drag_source_index

	_dragging = false
	_drag_skill_name = ""
	_drag_from = ""
	_drag_definition = {}
	if _drag_card != null:
		if dropped:
			_reset_drag_card()
		else:
			_return_drag_card_to_slot()
	_drag_card_start_position = Vector2.ZERO

	if should_add_to_deck:
		_try_add_to_deck(skill_name, insert_index)
	elif should_remove_from_deck:
		_try_remove_from_deck(skill_name, source_index)
	elif should_reorder_deck:
		_try_reorder_deck(skill_name, source_index, insert_index)
	else:
		_set_status("Drop on the other side to move.", false)


func _move_drag_card_to_mouse(mouse_pos: Vector2, immediate: bool) -> void:
	if _drag_card == null:
		return

	var target_position := mouse_pos - _drag_card.size * 0.5
	if immediate:
		_drag_card.global_position = target_position
	else:
		_drag_card.global_position = _drag_card.global_position.lerp(target_position, 0.45)


func _reset_drag_card() -> void:
	if _drag_card == null:
		return

	if _drag_card_tween != null:
		_drag_card_tween.kill()
		_drag_card_tween = null
	_drag_card.queue_free()
	_drag_card = null
	_clear_drag_placeholder()
	_clear_drag_source()


func _return_drag_card_to_slot() -> void:
	if _drag_card == null:
		return

	var returning_card := _drag_card
	returning_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _drag_source_parent != null:
		_move_placeholder_to_grid(_drag_source_parent as GridContainer, _drag_source_index)
	if _drag_card_tween != null:
		_drag_card_tween.kill()
	_drag_card_tween = create_tween()
	_drag_card_tween.set_trans(Tween.TRANS_CUBIC)
	_drag_card_tween.set_ease(Tween.EASE_OUT)
	_drag_card_tween.tween_property(returning_card, "global_position", _drag_card_start_position, DRAG_RETURN_SECONDS)
	_drag_card_tween.tween_property(returning_card, "modulate:a", 1.0, 0.08)
	_drag_card_tween.finished.connect(_on_drag_return_finished.bind(returning_card))
	_drag_card = null


func _on_drag_return_finished(returning_card: DeckBuilderCard) -> void:
	_drag_card_tween = null
	if not is_instance_valid(returning_card):
		_clear_drag_placeholder()
		_clear_drag_source()
		return

	if _drag_source_parent != null:
		returning_card.reparent(_drag_source_parent, false)
		_drag_source_parent.move_child(returning_card, _drag_source_index)
	returning_card.top_level = false
	returning_card.z_index = 0
	returning_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_clear_drag_placeholder()
	_clear_drag_source()


func _create_drag_placeholder(minimum_size: Vector2) -> void:
	_clear_drag_placeholder()
	_drag_placeholder = PanelContainer.new()
	_drag_placeholder.custom_minimum_size = minimum_size
	_drag_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_drag_placeholder.modulate.a = 0.45
	_drag_placeholder.add_theme_stylebox_override(
		"panel",
		_create_panel_style(Color(0.20, 0.14, 0.08, 0.62), COLOR_GOLD_BRIGHT, 2, 7)
	)


func _update_drag_placeholder(mouse_pos: Vector2) -> void:
	if _drag_placeholder == null:
		return

	if _is_over_control(_deck_drop_area, mouse_pos):
		_move_placeholder_to_grid(_deck_grid, _get_grid_insert_index(_deck_grid, mouse_pos))
	elif _is_over_control(_library_drop_area, mouse_pos):
		_move_placeholder_to_grid(_library_grid, _get_grid_insert_index(_library_grid, mouse_pos))
	elif _drag_placeholder_grid != _drag_source_parent:
		_move_placeholder_to_grid(_drag_source_parent as GridContainer, _drag_source_index)


func _move_placeholder_to_grid(grid: GridContainer, index: int) -> void:
	if grid == null or _drag_placeholder == null:
		return

	var child_count := grid.get_child_count()
	if _drag_placeholder.get_parent() == grid:
		child_count -= 1
	var clamped_index := clampi(index, 0, child_count)
	if _drag_placeholder_grid == grid and _drag_placeholder_index == clamped_index:
		return

	if _drag_placeholder.get_parent() != null:
		_drag_placeholder.reparent(grid, false)
	else:
		grid.add_child(_drag_placeholder)
	grid.move_child(_drag_placeholder, clamped_index)
	_drag_placeholder_grid = grid
	_drag_placeholder_index = clamped_index


func _get_grid_insert_index(grid: GridContainer, mouse_pos: Vector2) -> int:
	if grid == null:
		return 0

	var insert_index := 0
	for child in grid.get_children():
		if child == _drag_placeholder or not (child is Control):
			continue
		var control := child as Control
		if control is Label:
			continue
		var rect := control.get_global_rect()
		var center := rect.position + rect.size * 0.5
		if mouse_pos.y > center.y or (absf(mouse_pos.y - center.y) <= rect.size.y * 0.5 and mouse_pos.x > center.x):
			insert_index += 1
	return insert_index


func _clear_drag_placeholder() -> void:
	if _drag_placeholder != null:
		_drag_placeholder.queue_free()
	_drag_placeholder = null
	_drag_placeholder_grid = null
	_drag_placeholder_index = -1


func _clear_drag_source() -> void:
	_drag_source_parent = null
	_drag_source_index = -1


func _is_over_control(control: Control, mouse_pos: Vector2) -> bool:
	if control == null:
		return false
	return control.get_global_rect().has_point(mouse_pos)


func _is_valid_drop(data: Variant) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false

	var payload: Dictionary = data
	var skill_name := str(payload.get("skill_name", ""))
	var from := str(payload.get("from", ""))
	if skill_name.is_empty() or (from != "library" and from != "deck"):
		return false
	return true


func _try_add_to_deck(skill_name: String, insert_index: int = -1) -> void:
	if _deck.size() >= MAX_DECK_CARDS:
		_set_status("Deck is full (%d max)." % MAX_DECK_CARDS, true)
		_refresh_all()
		return

	if _get_available_count(skill_name) <= 0:
		_set_status("No more copies of %s." % skill_name, true)
		_refresh_all()
		return

	var clamped_index := clampi(insert_index, 0, _deck.size()) if insert_index >= 0 else _deck.size()
	_deck.insert(clamped_index, skill_name)
	if not _save_deck_to_user():
		_deck.remove_at(clamped_index)
		_refresh_all()
		return
	_set_status("Added %s." % skill_name, false)
	_refresh_all()


func _try_remove_from_deck(skill_name: String, source_index: int = -1) -> void:
	var index := source_index
	if index < 0 or index >= _deck.size() or _deck[index] != skill_name:
		index = _deck.rfind(skill_name)
	if index < 0:
		_refresh_all()
		return

	_deck.remove_at(index)
	if not _save_deck_to_user():
		_deck.insert(index, skill_name)
		_refresh_all()
		return
	_set_status("Removed %s." % skill_name, false)
	_refresh_all()


func _try_reorder_deck(skill_name: String, source_index: int, insert_index: int) -> void:
	var old_index := source_index
	if old_index < 0 or old_index >= _deck.size() or _deck[old_index] != skill_name:
		old_index = _deck.rfind(skill_name)
	if old_index < 0:
		_refresh_all()
		return

	var clamped_index := clampi(insert_index, 0, _deck.size())
	_deck.remove_at(old_index)
	if old_index < clamped_index:
		clamped_index -= 1
	clamped_index = clampi(clamped_index, 0, _deck.size())
	_deck.insert(clamped_index, skill_name)
	if not _save_deck_to_user():
		_deck.remove_at(clamped_index)
		_deck.insert(old_index, skill_name)
		_refresh_all()
		return
	_set_status("Moved %s." % skill_name, false)
	_refresh_all()


func _on_back_pressed() -> void:
	closed.emit()
	queue_free()


func _on_reset_pressed() -> void:
	_deck = _load_deck_from_path(RES_DECKS_PATH)
	if _deck.size() > MAX_DECK_CARDS:
		_deck = _deck.slice(0, MAX_DECK_CARDS)
	if not _save_deck_to_user():
		return
	_set_status("Deck reset.", false)
	_refresh_all()


func _set_status(message: String, is_error: bool) -> void:
	if _status_label == null:
		return
	_status_label.text = message
	_status_label.add_theme_color_override("font_color", COLOR_RED if is_error else COLOR_MUTED_TEXT)


func _load_deck() -> void:
	if FileAccess.file_exists(USER_DECKS_PATH):
		_deck = _load_deck_from_path(USER_DECKS_PATH)
	else:
		_deck = _load_deck_from_path(RES_DECKS_PATH)

	if _deck.size() > MAX_DECK_CARDS:
		_deck = _deck.slice(0, MAX_DECK_CARDS)


func _load_collection() -> void:
	var source_path := USER_COLLECTION_PATH if FileAccess.file_exists(USER_COLLECTION_PATH) else RES_COLLECTION_PATH
	_collection_counts = _load_collection_from_path(source_path)

	if _collection_counts.is_empty():
		for skill_name in SKILL_CARD_DATABASE.get_all_skill_names():
			_collection_counts[skill_name] = 1


func _load_deck_from_path(path: String) -> Array[String]:
	if not FileAccess.file_exists(path):
		return []

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return []

	var raw_deck = parsed.get(DECK_ID, [])
	if not (raw_deck is Array):
		return []

	var deck: Array[String] = []
	for skill_name in raw_deck:
		deck.append(str(skill_name))
	return deck


func _load_collection_from_path(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not (parsed is Dictionary):
		return {}

	var raw = parsed.get(DECK_ID, {})
	if not (raw is Dictionary):
		return {}

	var counts: Dictionary = {}
	for key in raw.keys():
		counts[str(key)] = maxi(0, int(raw[key]))
	return counts


func _save_deck_to_user() -> bool:
	var saved: Dictionary = {}
	if FileAccess.file_exists(USER_DECKS_PATH):
		var parsed = JSON.parse_string(FileAccess.get_file_as_string(USER_DECKS_PATH))
		if parsed is Dictionary:
			saved = parsed

	saved[DECK_ID] = _deck.duplicate()

	var file := FileAccess.open(USER_DECKS_PATH, FileAccess.WRITE)
	if file == null:
		_set_status("Could not write deck file.", true)
		return false
	file.store_string(JSON.stringify(saved, "\t"))
	file.close()
	deck_changed.emit()
	return true


func _create_panel_style(bg: Color, border: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _style_button(button: Button, is_primary: bool = false) -> void:
	if button == null:
		return

	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_font_size_override("font_size", 14)
	button.add_theme_stylebox_override("normal", _create_button_style(is_primary, false, false))
	button.add_theme_stylebox_override("hover", _create_button_style(is_primary, true, false))
	button.add_theme_stylebox_override("pressed", _create_button_style(is_primary, false, true))
	button.add_theme_stylebox_override("disabled", _create_button_style(is_primary, false, false, true))


func _create_button_style(
	is_primary: bool,
	is_hovered: bool,
	is_pressed: bool,
	is_disabled: bool = false
) -> StyleBoxFlat:
	var bg := Color(0.11, 0.075, 0.045, 0.96)
	var border := Color(0.50, 0.32, 0.14, 0.95)
	if is_primary:
		bg = Color(0.34, 0.095, 0.055, 0.98)
		border = COLOR_GOLD
	if is_hovered:
		bg = bg.lightened(0.08)
		border = COLOR_GOLD_BRIGHT
	if is_pressed:
		bg = bg.darkened(0.12)
	if is_disabled:
		bg = Color(0.075, 0.065, 0.055, 0.72)
		border = Color(0.25, 0.21, 0.16, 0.8)

	var style := _create_panel_style(bg, border, 2, 5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style


func _style_line_edit(edit: LineEdit) -> void:
	if edit == null:
		return

	edit.add_theme_color_override("font_color", COLOR_TEXT)
	edit.add_theme_color_override("caret_color", COLOR_GOLD_BRIGHT)
	edit.add_theme_font_size_override("font_size", 14)
	edit.add_theme_stylebox_override("normal", _create_input_style(false))
	edit.add_theme_stylebox_override("focus", _create_input_style(true))


func _create_input_style(is_focused: bool) -> StyleBoxFlat:
	var style := _create_panel_style(
		Color(0.035, 0.027, 0.021, 0.96),
		COLOR_GOLD if is_focused else Color(0.37, 0.25, 0.13, 0.95),
		1,
		4
	)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style
