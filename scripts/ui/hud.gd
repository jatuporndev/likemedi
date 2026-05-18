extends CanvasLayer

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const SKILL_DECK := preload("res://scripts/game/skill_deck.gd")
const SKILL_STAMINA := preload("res://scripts/game/skill_stamina.gd")
const SKILL_CARD_VIEW := preload("res://scripts/ui/skill_card_view.gd")

var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _host_label: Label
var _player_name_label: Label
var _fps_label: Label
var _stamina_value_label: Label
var _stamina_bar: ProgressBar
var _draw_deck_label: Label
var _discard_deck_label: Label
var _end_hand_button: Button
var _dragged_skill_card: PanelContainer
var _release_hint: Label
var _drag_line: Line2D
var _drag_arrow_head: Polygon2D
var _skill_preview_rects: Array[Polygon2D] = []
var _skill_preview_border: Line2D
var _skill_preview_label: Label
var _heal_cursor_ring: Line2D
var _heal_target_floor_root: Node2D
var _heal_target_fill: Polygon2D
var _heal_target_ring: Line2D
var _heal_target_inner_ring: Line2D
var _heal_target_rune_ring: Line2D
var _heal_target_marks: Array[Line2D] = []
var _room_code := ""
var _is_dragging_skill_card := false
var _dragged_skill := ""
var _skill_deck := SKILL_DECK.new()
var _skill_stamina := SKILL_STAMINA.new()
var _hand_cards: Array[PanelContainer] = []

const CARD_SIZE := Vector2(108.0, 148.0)
const CARD_BOTTOM_MARGIN := 18.0
const CARD_HAND_STEP := 70.0
const CARD_HAND_RISE := 7.0
const CARD_HOVER_LIFT := 18.0
const CARD_HOVER_SCALE := 1.06
const CARD_AIM_HAND_DIP := 76.0
const CARD_AIM_SELECTED_DIP := 22.0
const CARD_AIM_HAND_SPREAD_SCALE := 0.86
const CARD_AIM_HAND_SCALE := 0.94
const CARD_LAYOUT_TWEEN_SECONDS := 0.16
const DECK_SHUFFLE_SECONDS := 2.0
const DRAW_AFTER_SHUFFLE_DELAY := DECK_SHUFFLE_SECONDS * 0.5
const HAND_REFILL_START_DELAY := 0.25
const CARD_DRAW_DELAY := 0.18
const SKILL_PREVIEW_WIDTH := 44.0
const SKILL_PREVIEW_START_OFFSET := Vector2(0.0, 36.0)
const SKILL_PREVIEW_FORWARD_OFFSET := 30.0
const SKILL_PREVIEW_OPACITY_STEPS := [0.08, 0.14, 0.22, 0.34, 0.48, 0.64, 0.78, 0.90, 1.0, 1.0]
const SKILL_PREVIEW_HIT_PADDING := 20.0
const SKILL_PREVIEW_TARGET_RADIUS := 34.0
const STRIKE_SKILL_NAME := "strike"
const STRIKE_PREVIEW_SEGMENTS := 28
const STRIKE_PREVIEW_FORWARD_OFFSET := 28.0
const HEAL_CURSOR_RADIUS := 34.0
const HEAL_CURSOR_SEGMENTS := 40
const HEAL_TARGET_FLOOR_OFFSET := Vector2(0.0, 46.0)
const HEAL_TARGET_FLOOR_RADIUS := 34.0
const HEAL_TARGET_FLOOR_Y_SCALE := 0.52
const HEAL_TARGET_FLOOR_SEGMENTS := 48
const HEAL_TARGET_MARK_COUNT := 12
const PLAYER_TARGET_BODY_RECT := Vector2(76.0, 116.0)

var _hovered_skill_card: PanelContainer
var _is_dealing_hand := false
var _hovered_heal_target_peer_id := -1


func _ready() -> void:
	NetworkManager.chat_message_received.connect(_on_chat_message)
	_build_ui()


func _process(delta: float) -> void:
	if _player_name_label != null:
		_player_name_label.text = _get_local_player_name()
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
	var stamina_changed := _skill_stamina.recharge(delta)
	if stamina_changed or _skill_stamina.current < SKILL_STAMINA.MAX_STAMINA:
		_update_stamina_ui()
	if _is_dragging_skill_card:
		_update_skill_card_drag()
	elif not _hand_cards.is_empty():
		_reset_skill_card_positions()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if _chat_input != null and _chat_input.has_focus():
			_chat_input.release_focus()
			get_viewport().set_input_as_handled()
		else:
			NetworkManager.leave_game()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ENTER:
		if _chat_input != null and not _chat_input.has_focus():
			_chat_input.grab_focus()
			get_viewport().set_input_as_handled()


func _input(event: InputEvent) -> void:
	if not _is_dragging_skill_card:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_finish_skill_card_drag(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
		_cancel_skill_card_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion:
		_update_skill_card_drag()
		get_viewport().set_input_as_handled()


func _build_ui() -> void:
	var top_bar := PanelContainer.new()
	top_bar.anchor_right = 1.0
	top_bar.offset_left = 12
	top_bar.offset_top = 12
	top_bar.offset_right = -12
	top_bar.offset_bottom = 58
	add_child(top_bar)

	var top_margin := MarginContainer.new()
	top_margin.add_theme_constant_override("margin_left", 12)
	top_margin.add_theme_constant_override("margin_right", 12)
	top_margin.add_theme_constant_override("margin_top", 8)
	top_margin.add_theme_constant_override("margin_bottom", 8)
	top_bar.add_child(top_margin)

	var top_layout := HBoxContainer.new()
	top_margin.add_child(top_layout)

	_player_name_label = Label.new()
	_player_name_label.custom_minimum_size = Vector2(150, 0)
	_player_name_label.text = _get_local_player_name()
	top_layout.add_child(_player_name_label)

	_host_label = Label.new()
	_host_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if NetworkManager.is_host():
		_room_code = NetworkManager.get_host_info()
		_host_label.text = "Room %s (%s)" % [
			_room_code,
			NetworkManager.get_transport_mode().to_upper(),
		]
	else:
		_host_label.text = "Connected to host (%s)" % NetworkManager.get_transport_mode().to_upper()
	top_layout.add_child(_host_label)

	_fps_label = Label.new()
	_fps_label.custom_minimum_size = Vector2(72, 0)
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.text = "FPS 0"
	_fps_label.add_theme_color_override("font_color", Color(0.75, 0.96, 0.72))
	top_layout.add_child(_fps_label)

	if NetworkManager.is_host():
		var copy_button := Button.new()
		copy_button.text = "Copy Code"
		copy_button.pressed.connect(_copy_room_code)
		top_layout.add_child(copy_button)

	var leave_button := Button.new()
	leave_button.text = "Leave"
	leave_button.pressed.connect(Callable(NetworkManager, "leave_game"))
	top_layout.add_child(leave_button)

	var chat_panel := PanelContainer.new()
	chat_panel.anchor_left = 0.0
	chat_panel.anchor_top = 1.0
	chat_panel.anchor_right = 0.0
	chat_panel.anchor_bottom = 1.0
	chat_panel.offset_left = 12
	chat_panel.offset_top = -188
	chat_panel.offset_right = 292
	chat_panel.offset_bottom = -12
	add_child(chat_panel)

	var chat_margin := MarginContainer.new()
	chat_margin.add_theme_constant_override("margin_left", 10)
	chat_margin.add_theme_constant_override("margin_right", 10)
	chat_margin.add_theme_constant_override("margin_top", 10)
	chat_margin.add_theme_constant_override("margin_bottom", 10)
	chat_panel.add_child(chat_margin)

	var chat_layout := VBoxContainer.new()
	chat_layout.add_theme_constant_override("separation", 8)
	chat_margin.add_child(chat_layout)

	_chat_log = RichTextLabel.new()
	_chat_log.custom_minimum_size = Vector2(0, 104)
	_chat_log.fit_content = false
	_chat_log.scroll_following = true
	chat_layout.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Chat"
	_chat_input.text_submitted.connect(_submit_chat)
	chat_layout.add_child(_chat_input)

	_build_deck_ui()
	_build_skill_card_ui()


func _submit_chat(message: String) -> void:
	NetworkManager.submit_chat_message(message)
	_chat_input.clear()
	_chat_input.release_focus()


func _on_chat_message(sender_id: int, message: String) -> void:
	var sender_name := str(NetworkManager.player_names.get(sender_id, "Player %d" % sender_id))
	_chat_log.append_text("[b]%s:[/b] %s\n" % [sender_name, message])


func _copy_room_code() -> void:
	DisplayServer.clipboard_set(_room_code)
	_host_label.text = "Room %s copied (%s)" % [
		_room_code,
		NetworkManager.get_transport_mode().to_upper(),
	]


func _get_local_player_name() -> String:
	var local_peer_id := multiplayer.get_unique_id()
	if NetworkManager.player_names.has(local_peer_id):
		return str(NetworkManager.player_names[local_peer_id])
	return str(NetworkManager.player_names.get(0, "Player"))


func _build_deck_ui() -> void:
	var deck_panel := PanelContainer.new()
	deck_panel.anchor_left = 1.0
	deck_panel.anchor_top = 1.0
	deck_panel.anchor_right = 1.0
	deck_panel.anchor_bottom = 1.0
	deck_panel.offset_left = -342
	deck_panel.offset_top = -126
	deck_panel.offset_right = -12
	deck_panel.offset_bottom = -12
	add_child(deck_panel)

	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 10)
	deck_margin.add_theme_constant_override("margin_right", 10)
	deck_margin.add_theme_constant_override("margin_top", 10)
	deck_margin.add_theme_constant_override("margin_bottom", 10)
	deck_panel.add_child(deck_margin)

	var deck_layout := VBoxContainer.new()
	deck_layout.add_theme_constant_override("separation", 8)
	deck_margin.add_child(deck_layout)

	var stacks := HBoxContainer.new()
	stacks.add_theme_constant_override("separation", 10)
	deck_layout.add_child(stacks)

	var stamina_panel := _create_stamina_panel()
	stacks.add_child(stamina_panel)

	_draw_deck_label = _create_deck_stack_label("Draw Pile", 0)
	stacks.add_child(_draw_deck_label)

	_discard_deck_label = _create_deck_stack_label("Discard", 0)
	stacks.add_child(_discard_deck_label)

	_end_hand_button = Button.new()
	_end_hand_button.text = "End Hand"
	_end_hand_button.custom_minimum_size = Vector2(0.0, 30.0)
	_end_hand_button.focus_mode = Control.FOCUS_NONE
	_end_hand_button.pressed.connect(_on_end_hand_pressed)
	deck_layout.add_child(_end_hand_button)


func _create_deck_stack_label(title: String, count: int) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(94.0, 54.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "%s\n%d" % [title, count]
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	var stack_style := StyleBoxFlat.new()
	stack_style.bg_color = Color(0.12, 0.09, 0.07, 0.96)
	stack_style.border_color = Color(0.74, 0.50, 0.22)
	stack_style.border_width_left = 2
	stack_style.border_width_top = 2
	stack_style.border_width_right = 2
	stack_style.border_width_bottom = 2
	stack_style.corner_radius_top_left = 6
	stack_style.corner_radius_top_right = 6
	stack_style.corner_radius_bottom_left = 6
	stack_style.corner_radius_bottom_right = 6
	label.add_theme_stylebox_override("normal", stack_style)
	return label


func _create_stamina_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(116.0, 54.0)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.09, 0.11, 0.14, 0.96)
	panel_style.border_color = Color(0.36, 0.74, 0.92)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 6
	panel_style.corner_radius_top_right = 6
	panel_style.corner_radius_bottom_left = 6
	panel_style.corner_radius_bottom_right = 6
	panel.add_theme_stylebox_override("panel", panel_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 8)
	margin.add_theme_constant_override("margin_right", 8)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 4)
	margin.add_child(layout)

	var header := HBoxContainer.new()
	layout.add_child(header)

	var title := Label.new()
	title.text = "Stamina"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	header.add_child(title)

	_stamina_value_label = Label.new()
	_stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamina_value_label.add_theme_font_size_override("font_size", 12)
	_stamina_value_label.add_theme_color_override("font_color", Color(0.78, 0.94, 1.0))
	header.add_child(_stamina_value_label)

	_stamina_bar = _create_stamina_progress_bar(
		Color(0.07, 0.10, 0.13, 1.0),
		Color(0.21, 0.66, 0.86, 1.0),
		8.0
	)
	_stamina_bar.max_value = SKILL_STAMINA.MAX_STAMINA
	layout.add_child(_stamina_bar)
	return panel


func _create_stamina_progress_bar(background_color: Color, fill_color: Color, height: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0.0, height)
	bar.show_percentage = false
	var background_style := StyleBoxFlat.new()
	background_style.bg_color = background_color
	background_style.corner_radius_top_left = 2
	background_style.corner_radius_top_right = 2
	background_style.corner_radius_bottom_left = 2
	background_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("background", background_style)

	var fill_style := StyleBoxFlat.new()
	fill_style.bg_color = fill_color
	fill_style.corner_radius_top_left = 2
	fill_style.corner_radius_top_right = 2
	fill_style.corner_radius_bottom_left = 2
	fill_style.corner_radius_bottom_right = 2
	bar.add_theme_stylebox_override("fill", fill_style)
	return bar


func _update_stamina_ui() -> void:
	if _stamina_bar == null or _stamina_value_label == null:
		return

	_stamina_value_label.text = "%d / %d" % [
		_skill_stamina.current,
		SKILL_STAMINA.MAX_STAMINA,
	]
	var stamina_bar_value := _get_stamina_bar_value()
	_stamina_bar.value = stamina_bar_value
	_update_local_player_stamina_bar(stamina_bar_value)


func _get_stamina_bar_value() -> float:
	var recharge_fraction := _skill_stamina.recharge_progress_seconds() / SKILL_STAMINA.RECHARGE_SECONDS
	if _skill_stamina.current >= SKILL_STAMINA.MAX_STAMINA:
		recharge_fraction = 0.0
	return minf(
		float(_skill_stamina.current) + recharge_fraction,
		float(SKILL_STAMINA.MAX_STAMINA)
	)


func _build_skill_card_ui() -> void:
	_skill_preview_rects.clear()
	for opacity in SKILL_PREVIEW_OPACITY_STEPS:
		var preview_rect := Polygon2D.new()
		preview_rect.visible = false
		preview_rect.z_index = 28
		preview_rect.color = Color(0.42, 0.78, 0.92, float(opacity) * 0.22)
		_skill_preview_rects.append(preview_rect)
		add_child(preview_rect)

	_skill_preview_border = Line2D.new()
	_skill_preview_border.visible = false
	_skill_preview_border.z_index = 29
	_skill_preview_border.width = 2.0
	_skill_preview_border.default_color = Color(0.60, 0.92, 1.0, 0.76)
	add_child(_skill_preview_border)

	_skill_preview_label = Label.new()
	_skill_preview_label.visible = false
	_skill_preview_label.z_index = 30
	_skill_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_preview_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	_skill_preview_label.add_theme_font_size_override("font_size", 14)
	add_child(_skill_preview_label)

	_heal_cursor_ring = Line2D.new()
	_heal_cursor_ring.visible = false
	_heal_cursor_ring.z_index = 30
	_heal_cursor_ring.width = 2.0
	_heal_cursor_ring.default_color = Color(0.58, 0.96, 0.68, 0.58)
	add_child(_heal_cursor_ring)

	_heal_target_floor_root = Node2D.new()
	_heal_target_floor_root.z_index = 0
	_heal_target_floor_root.y_sort_enabled = false
	var heal_target_parent := _get_heal_target_floor_parent()
	if heal_target_parent != null:
		heal_target_parent.add_child(_heal_target_floor_root)
		heal_target_parent.move_child(_heal_target_floor_root, 0)
	else:
		add_child(_heal_target_floor_root)

	_heal_target_fill = Polygon2D.new()
	_heal_target_fill.visible = false
	_heal_target_fill.color = Color(0.12, 0.94, 0.42, 0.20)
	_heal_target_floor_root.add_child(_heal_target_fill)

	_heal_target_ring = Line2D.new()
	_heal_target_ring.visible = false
	_heal_target_ring.width = 3.0
	_heal_target_ring.default_color = Color(0.52, 1.0, 0.66, 0.92)
	_heal_target_floor_root.add_child(_heal_target_ring)

	_heal_target_inner_ring = Line2D.new()
	_heal_target_inner_ring.visible = false
	_heal_target_inner_ring.width = 1.5
	_heal_target_inner_ring.default_color = Color(0.76, 1.0, 0.80, 0.62)
	_heal_target_floor_root.add_child(_heal_target_inner_ring)

	_heal_target_rune_ring = Line2D.new()
	_heal_target_rune_ring.visible = false
	_heal_target_rune_ring.width = 1.0
	_heal_target_rune_ring.default_color = Color(0.40, 1.0, 0.62, 0.56)
	_heal_target_floor_root.add_child(_heal_target_rune_ring)

	_heal_target_marks.clear()
	for _index in range(HEAL_TARGET_MARK_COUNT):
		var mark := Line2D.new()
		mark.visible = false
		mark.width = 2.0
		mark.default_color = Color(0.84, 1.0, 0.82, 0.72)
		_heal_target_marks.append(mark)
		_heal_target_floor_root.add_child(mark)

	_drag_line = Line2D.new()
	_drag_line.visible = false
	_drag_line.z_index = 35
	_drag_line.width = 2.0
	_drag_line.default_color = Color(0.60, 0.92, 1.0, 0.65)
	add_child(_drag_line)

	_drag_arrow_head = Polygon2D.new()
	_drag_arrow_head.visible = false
	_drag_arrow_head.z_index = 36
	_drag_arrow_head.color = Color(0.62, 0.90, 0.84, 0.82)
	add_child(_drag_arrow_head)

	_release_hint = Label.new()
	_release_hint.anchor_left = 0.5
	_release_hint.anchor_top = 1.0
	_release_hint.anchor_right = 0.5
	_release_hint.anchor_bottom = 1.0
	_release_hint.offset_left = -92.0
	_release_hint.offset_top = -238.0
	_release_hint.offset_right = 92.0
	_release_hint.offset_bottom = -214.0
	_release_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_release_hint.text = "Release to use"
	_release_hint.visible = false
	_release_hint.add_theme_color_override("font_color", Color(0.95, 0.85, 0.56))
	add_child(_release_hint)

	_skill_deck.setup_default_deck()
	_hand_cards = []
	_draw_full_hand()
	_reset_skill_card_positions()
	_update_stamina_ui()
	_update_deck_ui()


func _draw_full_hand() -> void:
	while _skill_deck.can_add_to_hand():
		var hand_size_before := _hand_cards.size()
		_draw_card()
		if _hand_cards.size() == hand_size_before:
			return


func _draw_card() -> void:
	if not _skill_deck.can_add_to_hand():
		return
	if _skill_deck.is_waiting_to_draw_after_shuffle:
		_update_deck_ui()
		return
	if _skill_deck.should_shuffle_before_draw():
		_start_deck_shuffle()
	if _skill_deck.draw_pile_count() == 0:
		_update_deck_ui()
		return

	var skill_name := _skill_deck.draw_card()
	if skill_name.is_empty():
		_update_deck_ui()
		return

	var definition := SKILL_CARD_DATABASE.get_definition(skill_name)
	var art_color: Color = definition["art_color"]
	var card := _create_skill_card(
		skill_name,
		str(definition["title"]),
		str(int(definition["cost"])),
		str(definition["description"]),
		art_color
	)
	card.set_meta("stamina_cost", int(definition["cost"]))
	card.set_meta("skill_type", str(definition["type"]))
	card.set_meta("damage", int(definition["damage"]))
	card.set_meta("heal", int(definition["heal"]))
	card.set_meta("range", float(definition["range"]))
	_hand_cards.append(card)
	_reset_skill_card_positions()
	_update_deck_ui()


func _start_deck_shuffle() -> void:
	if not _skill_deck.should_shuffle_before_draw():
		return

	_skill_deck.start_shuffle()
	_update_deck_ui()
	get_tree().create_timer(DECK_SHUFFLE_SECONDS).timeout.connect(_finish_deck_shuffle)


func _finish_deck_shuffle() -> void:
	_skill_deck.finish_shuffle()
	_update_deck_ui()
	get_tree().create_timer(DRAW_AFTER_SHUFFLE_DELAY).timeout.connect(_finish_draw_after_shuffle)


func _finish_draw_after_shuffle() -> void:
	_skill_deck.finish_draw_after_shuffle()
	_update_deck_ui()
	_request_full_hand_draw()


func _discard_card(card: PanelContainer) -> void:
	var skill_name := str(card.get_meta("skill_name", ""))
	_hand_cards.erase(card)
	_skill_deck.discard_card(skill_name)
	card.queue_free()
	_update_deck_ui()


func _discard_hand() -> void:
	if _hand_cards.is_empty():
		return

	if _is_dragging_skill_card:
		_is_dragging_skill_card = false
		_dragged_skill_card = null
		_dragged_skill = ""
		_hovered_heal_target_peer_id = -1
		_release_hint.visible = false
		_drag_line.visible = false
		_drag_arrow_head.visible = false
		_set_skill_preview_visible(false)

	var cards_to_discard := _hand_cards.duplicate()
	for card in cards_to_discard:
		_discard_card(card)

	_request_full_hand_draw()


func _on_end_hand_pressed() -> void:
	_discard_hand()


func _update_deck_ui() -> void:
	if _draw_deck_label != null:
		if _skill_deck.is_shuffling:
			_draw_deck_label.text = "Draw Pile\nShuffling"
		elif _skill_deck.is_waiting_to_draw_after_shuffle:
			_draw_deck_label.text = "Draw Pile\nMoving"
		else:
			_draw_deck_label.text = "Draw Pile\n%d cards" % _skill_deck.draw_pile_count()
	if _discard_deck_label != null:
		_discard_deck_label.text = "Discard\n%d cards" % _skill_deck.discard_pile_count()
	if _end_hand_button != null:
		_end_hand_button.disabled = _hand_cards.is_empty() or _is_dealing_hand


func _create_skill_card(
	skill_name: String,
	title: String,
	cost_text: String,
	description_text: String,
	art_color: Color
) -> PanelContainer:
	var card := SKILL_CARD_VIEW.create(skill_name, title, cost_text, description_text, art_color)
	card.gui_input.connect(_on_skill_card_gui_input.bind(card))
	card.mouse_entered.connect(_on_skill_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_skill_card_mouse_exited.bind(card))
	add_child(card)
	return card


func _on_skill_card_gui_input(event: InputEvent, card: PanelContainer) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_begin_skill_card_drag(get_viewport().get_mouse_position(), card)
		else:
			_finish_skill_card_drag(get_viewport().get_mouse_position())
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and event.pressed and _is_dragging_skill_card:
		_cancel_skill_card_drag()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _is_dragging_skill_card:
		_update_skill_card_drag()
		get_viewport().set_input_as_handled()


func _begin_skill_card_drag(mouse_position: Vector2, card: PanelContainer) -> void:
	_is_dragging_skill_card = true
	_dragged_skill_card = card
	_dragged_skill = str(card.get_meta("skill_name", ""))
	_hovered_skill_card = null
	_dragged_skill_card.rotation_degrees = 0.0
	_dragged_skill_card.scale = Vector2.ONE
	_dragged_skill_card.z_index = 60
	_release_hint.visible = false
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	_hovered_heal_target_peer_id = -1
	_reset_skill_card_positions()
	_update_skill_card_drag_at(mouse_position)


func _finish_skill_card_drag(_mouse_position: Vector2) -> void:
	if not _is_dragging_skill_card:
		return

	_is_dragging_skill_card = false
	var was_used := false
	var stamina_cost := _get_card_stamina_cost(_dragged_skill_card)
	if _skill_stamina.can_spend(stamina_cost):
		if _is_heal_card(_dragged_skill_card) and _hovered_heal_target_peer_id < 0:
			_release_hint.text = "Select target"
		else:
			was_used = _request_local_skill(_dragged_skill, _hovered_heal_target_peer_id)
		if was_used:
			_skill_stamina.spend(stamina_cost)
			_update_stamina_ui()
	else:
		_release_hint.text = "Need %d stamina" % stamina_cost

	_release_hint.visible = false
	_release_hint.text = "Release to use"
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	_set_skill_preview_visible(false)
	var used_card := _dragged_skill_card
	_dragged_skill_card = null
	_dragged_skill = ""
	_hovered_heal_target_peer_id = -1
	if was_used and used_card != null:
		_discard_card(used_card)
	if _hand_cards.is_empty():
		_request_full_hand_draw()
	_reset_skill_card_positions()


func _cancel_skill_card_drag() -> void:
	if not _is_dragging_skill_card:
		return

	_is_dragging_skill_card = false
	_dragged_skill_card = null
	_dragged_skill = ""
	_hovered_heal_target_peer_id = -1
	_release_hint.visible = false
	_release_hint.text = "Release to use"
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	_set_skill_preview_visible(false)
	_reset_skill_card_positions()


func _request_full_hand_draw() -> void:
	if _is_dealing_hand:
		return

	_is_dealing_hand = true
	_update_deck_ui()
	get_tree().create_timer(HAND_REFILL_START_DELAY).timeout.connect(_deal_next_hand_card)


func _deal_next_hand_card() -> void:
	if not _skill_deck.can_add_to_hand():
		_is_dealing_hand = false
		_update_deck_ui()
		return
	if _skill_deck.is_shuffling or _skill_deck.is_waiting_to_draw_after_shuffle:
		_is_dealing_hand = false
		_update_deck_ui()
		return

	var hand_size_before := _hand_cards.size()
	_draw_card()
	if _hand_cards.size() == hand_size_before:
		_is_dealing_hand = false
		_update_deck_ui()
		return

	get_tree().create_timer(CARD_DRAW_DELAY).timeout.connect(_deal_next_hand_card)


func _update_skill_card_drag() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	_update_skill_card_drag_at(mouse_position)


func _update_skill_card_drag_at(mouse_position: Vector2) -> void:
	_release_hint.visible = true

	var active_card := _dragged_skill_card
	if active_card == null and not _hand_cards.is_empty():
		active_card = _hand_cards[0]
	if active_card == null:
		_set_skill_preview_visible(false)
		_drag_arrow_head.visible = false
		return
	_update_skill_preview(active_card, mouse_position)
	var stamina_cost := _get_card_stamina_cost(active_card)
	if _skill_stamina.can_spend(stamina_cost):
		_release_hint.text = "Release to use"
	else:
		_release_hint.text = "Need %d stamina" % stamina_cost
	_drag_line.visible = false
	_drag_arrow_head.visible = false


func _update_skill_preview(card: PanelContainer, mouse_position: Vector2) -> Vector2:
	var player := _get_local_player_node()
	if player == null:
		_set_skill_preview_visible(false)
		return Vector2.INF

	var attack_range := float(card.get_meta("range", 0.0))
	var heal := int(card.get_meta("heal", 0))
	if str(card.get_meta("skill_type", "attack")) == "heal":
		return _update_heal_target_preview(mouse_position, heal)
	if attack_range <= 0.0:
		_set_skill_preview_visible(false)
		return Vector2.INF

	if str(card.get_meta("skill_name", "")) == STRIKE_SKILL_NAME:
		return _update_strike_preview(card, mouse_position, attack_range, player)

	var player_transform := player.get_global_transform_with_canvas()
	var player_center := player_transform.origin
	var preview_start := player_transform * SKILL_PREVIEW_START_OFFSET
	var max_screen_range := player_center.distance_to(player_transform * Vector2(attack_range, 0.0))
	var to_mouse := mouse_position - preview_start
	var direction := to_mouse.normalized()
	if to_mouse.length_squared() < 1.0:
		direction = Vector2.RIGHT
	preview_start += direction * SKILL_PREVIEW_FORWARD_OFFSET
	var center := preview_start + direction * maxf(max_screen_range - SKILL_PREVIEW_FORWARD_OFFSET, 0.0)
	center = _clamp_skillshot_to_first_target(preview_start, center, direction)
	var can_spend := _skill_stamina.can_spend(_get_card_stamina_cost(card))
	var fill_color := Color(0.42, 0.78, 0.92, 1.0)
	var border_color := Color(0.60, 0.92, 1.0, 0.42)
	if not can_spend:
		fill_color = Color(0.42, 0.42, 0.42, 0.55)
		border_color = Color(0.62, 0.62, 0.62, 0.36)

	var forward := direction
	var side := Vector2(-forward.y, forward.x) * (SKILL_PREVIEW_WIDTH * 0.5)
	var segment_count := _skill_preview_rects.size()
	for index in range(segment_count):
		var start_fraction := float(index) / float(segment_count)
		var end_fraction := float(index + 1) / float(segment_count)
		var segment_start := preview_start.lerp(center, start_fraction)
		var segment_end := preview_start.lerp(center, end_fraction)
		var segment_color := fill_color
		segment_color.a *= float(SKILL_PREVIEW_OPACITY_STEPS[index])
		_skill_preview_rects[index].color = segment_color
		_skill_preview_rects[index].polygon = PackedVector2Array([
			segment_start - side,
			segment_end - side,
			segment_end + side,
			segment_start + side,
		])
		_skill_preview_rects[index].visible = true
	var border_points := PackedVector2Array([
		preview_start - side,
		center - side,
		center + side,
		preview_start + side,
		preview_start - side,
	])

	_skill_preview_border.default_color = border_color
	_skill_preview_border.points = border_points
	_set_skill_preview_visible(true)
	_skill_preview_label.visible = false
	_heal_cursor_ring.visible = false
	_set_heal_target_floor_visible(false)
	return center


func _update_strike_preview(
	card: PanelContainer,
	mouse_position: Vector2,
	attack_range: float,
	player: Node2D
) -> Vector2:
	var player_transform := player.get_global_transform_with_canvas()
	var player_center := player_transform.origin
	var to_mouse := mouse_position - player_center
	var direction := to_mouse.normalized()
	if to_mouse.length_squared() < 1.0:
		direction = Vector2.RIGHT

	var center := player_center + direction * STRIKE_PREVIEW_FORWARD_OFFSET
	var screen_range := player_center.distance_to(player_transform * Vector2(attack_range, 0.0))
	var aim_angle := direction.angle()
	var start_angle := aim_angle - PI * 0.5
	var end_angle := aim_angle + PI * 0.5

	var fan_points := PackedVector2Array([center])
	for index in range(STRIKE_PREVIEW_SEGMENTS + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(STRIKE_PREVIEW_SEGMENTS))
		fan_points.append(center + Vector2(cos(angle), sin(angle)) * screen_range)

	var can_spend := _skill_stamina.can_spend(_get_card_stamina_cost(card))
	var fill_color := Color(0.42, 0.78, 0.92, 0.34)
	var border_color := Color(0.60, 0.92, 1.0, 0.76)
	if not can_spend:
		fill_color = Color(0.42, 0.42, 0.42, 0.22)
		border_color = Color(0.62, 0.62, 0.62, 0.46)

	for index in range(_skill_preview_rects.size()):
		_skill_preview_rects[index].visible = index == 0
		if index == 0:
			_skill_preview_rects[index].color = fill_color
			_skill_preview_rects[index].polygon = fan_points

	var border_points := PackedVector2Array([center])
	for index in range(STRIKE_PREVIEW_SEGMENTS + 1):
		var angle := lerpf(start_angle, end_angle, float(index) / float(STRIKE_PREVIEW_SEGMENTS))
		border_points.append(center + Vector2(cos(angle), sin(angle)) * screen_range)
	border_points.append(center)

	_skill_preview_border.default_color = border_color
	_skill_preview_border.points = border_points
	_skill_preview_border.visible = true
	_skill_preview_label.visible = false
	_heal_cursor_ring.visible = false
	_set_heal_target_floor_visible(false)
	return center + direction * screen_range


func _clamp_skillshot_to_first_target(start: Vector2, end: Vector2, direction: Vector2) -> Vector2:
	var closest_distance := start.distance_to(end)
	var closest_hit := end

	for target in _get_skillshot_screen_targets():
		var target_center: Vector2 = target
		var to_target := target_center - start
		var forward_distance := to_target.dot(direction)
		if forward_distance <= 0.0 or forward_distance >= closest_distance:
			continue

		var closest_point := start + direction * forward_distance
		var side_distance := closest_point.distance_to(target_center)
		if side_distance > SKILL_PREVIEW_TARGET_RADIUS:
			continue

		closest_distance = maxf(forward_distance - SKILL_PREVIEW_HIT_PADDING, 0.0)
		closest_hit = start + direction * closest_distance

	return closest_hit


func _set_skill_preview_visible(is_visible: bool) -> void:
	for preview_rect in _skill_preview_rects:
		preview_rect.visible = is_visible
	if _skill_preview_border != null:
		_skill_preview_border.visible = is_visible
	if _skill_preview_label != null:
		_skill_preview_label.visible = is_visible
	if not is_visible:
		if _heal_cursor_ring != null:
			_heal_cursor_ring.visible = false
		_set_heal_target_floor_visible(false)


func _update_heal_target_preview(mouse_position: Vector2, _heal: int) -> Vector2:
	for preview_rect in _skill_preview_rects:
		preview_rect.visible = false
	_skill_preview_border.visible = false
	_skill_preview_label.visible = false
	_update_ring_points(_heal_cursor_ring, mouse_position, HEAL_CURSOR_RADIUS, HEAL_CURSOR_SEGMENTS)
	_heal_cursor_ring.visible = true

	var target := _find_player_at_screen_position(mouse_position)
	if target == null:
		_hovered_heal_target_peer_id = -1
		_set_heal_target_floor_visible(false)
		return mouse_position

	var peer_id = target.get("peer_id")
	_hovered_heal_target_peer_id = int(peer_id) if peer_id is int or peer_id is float else -1
	var center := _get_player_floor_target_world_center(target)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.07
	_update_heal_target_floor_circle(center, pulse)
	return _get_player_floor_target_center(target)


func _update_heal_target_floor_circle(center: Vector2, pulse: float) -> void:
	var radius := HEAL_TARGET_FLOOR_RADIUS * pulse
	var radii := Vector2(radius, radius * HEAL_TARGET_FLOOR_Y_SCALE)
	var spin := float(Time.get_ticks_msec()) * 0.0018

	if _heal_target_fill != null:
		_heal_target_fill.color = Color(0.04, 0.86, 0.35, 0.18)
		_heal_target_fill.polygon = _make_ellipse_polygon(
			center,
			radii * 0.96,
			HEAL_TARGET_FLOOR_SEGMENTS
		)

	_heal_target_ring.default_color = Color(0.52, 1.0, 0.66, 0.78 + 0.14 * pulse)
	_update_ellipse_ring_points(_heal_target_ring, center, radii, HEAL_TARGET_FLOOR_SEGMENTS)
	_heal_target_inner_ring.default_color = Color(0.78, 1.0, 0.80, 0.54 + 0.10 * pulse)
	_update_ellipse_ring_points(
		_heal_target_inner_ring,
		center,
		radii * 0.66,
		HEAL_TARGET_FLOOR_SEGMENTS
	)
	_heal_target_rune_ring.default_color = Color(0.28, 1.0, 0.56, 0.44 + 0.10 * pulse)
	_update_rotated_ellipse_ring_points(
		_heal_target_rune_ring,
		center,
		radii * 0.82,
		HEAL_TARGET_FLOOR_SEGMENTS,
		spin
	)
	_update_heal_target_marks(center, radii, spin)
	_set_heal_target_floor_visible(true)


func _set_heal_target_floor_visible(is_visible: bool) -> void:
	if _heal_target_fill != null:
		_heal_target_fill.visible = is_visible
	if _heal_target_ring != null:
		_heal_target_ring.visible = is_visible
	if _heal_target_inner_ring != null:
		_heal_target_inner_ring.visible = is_visible
	if _heal_target_rune_ring != null:
		_heal_target_rune_ring.visible = is_visible
	for mark in _heal_target_marks:
		mark.visible = is_visible


func _update_heal_target_marks(center: Vector2, radii: Vector2, spin: float) -> void:
	for index in range(_heal_target_marks.size()):
		var angle := spin + TAU * float(index) / float(_heal_target_marks.size())
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * radii * 0.74
		var outer := center + direction * radii * 0.98
		_heal_target_marks[index].points = PackedVector2Array([inner, outer])


func _make_ellipse_polygon(center: Vector2, radii: Vector2, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array([center])
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _update_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_ring_points(ring: Line2D, center: Vector2, radius: float, segment_count: int) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2.RIGHT.rotated(angle) * radius)
	ring.points = points


func _update_rotated_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int,
	rotation: float
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := rotation + TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_drag_arrow_head(start_position: Vector2, end_position: Vector2) -> void:
	var direction := end_position - start_position
	if direction.length_squared() < 1.0:
		_drag_arrow_head.visible = false
		return

	_drag_arrow_head.visible = true
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var arrow_length := 14.0
	var arrow_width := 9.0
	_drag_arrow_head.polygon = PackedVector2Array([
		end_position,
		end_position - forward * arrow_length + side * arrow_width,
		end_position - forward * arrow_length - side * arrow_width,
	])


func _reset_skill_card_positions() -> void:
	var hand_count := _hand_cards.size()
	for index in range(hand_count):
		var card := _hand_cards[index]

		var card_index := float(index)
		var hand_center := (float(hand_count) - 1.0) * 0.5
		var center_offset: float = (card_index - hand_center) * CARD_HAND_STEP
		var distance_from_center: float = absf(card_index - hand_center)
		var rise: float = -CARD_HAND_RISE * (1.0 - minf(distance_from_center, 1.0))
		var rotation: float = clampf(center_offset / CARD_HAND_STEP, -2.0, 2.0) * 4.0
		if _is_dragging_skill_card:
			if card == _dragged_skill_card:
				rise += CARD_AIM_SELECTED_DIP
				rotation = 0.0
			else:
				center_offset *= CARD_AIM_HAND_SPREAD_SCALE
				rise += CARD_AIM_HAND_DIP
				rotation *= 0.55
		var z_order := 60 if card == _dragged_skill_card else 40 + index
		_reset_skill_card_position(card, center_offset, rise, rotation, z_order)


func _reset_skill_card_position(
	card: PanelContainer,
	offset_x: float,
	offset_y: float,
	rotation: float,
	z_order: int
) -> void:
	if card == null:
		return

	if card == _hovered_skill_card and not _is_dragging_skill_card:
		offset_y -= CARD_HOVER_LIFT
		z_order += 20

	var target_scale := Vector2.ONE
	if card == _hovered_skill_card and not _is_dragging_skill_card:
		target_scale = Vector2(CARD_HOVER_SCALE, CARD_HOVER_SCALE)
	elif _is_dragging_skill_card and card != _dragged_skill_card:
		target_scale = Vector2(CARD_AIM_HAND_SCALE, CARD_AIM_HAND_SCALE)

	card.anchor_left = 0.5
	card.anchor_top = 1.0
	card.anchor_right = 0.5
	card.anchor_bottom = 1.0
	card.pivot_offset = CARD_SIZE * 0.5
	card.z_index = z_order
	var target_position := Vector2(offset_x, -CARD_SIZE.y - CARD_BOTTOM_MARGIN + offset_y)
	_animate_skill_card_to(card, target_position, rotation, target_scale)


func _on_skill_card_mouse_entered(card: PanelContainer) -> void:
	if _is_dragging_skill_card:
		return

	_hovered_skill_card = card
	_reset_skill_card_positions()


func _on_skill_card_mouse_exited(card: PanelContainer) -> void:
	if _hovered_skill_card != card:
		return

	_hovered_skill_card = null
	_reset_skill_card_positions()


func _animate_skill_card_to(
	card: PanelContainer,
	target_position: Vector2,
	target_rotation: float,
	target_scale: Vector2
) -> void:
	var previous_position = card.get_meta("target_position") if card.has_meta("target_position") else null
	var previous_rotation = card.get_meta("target_rotation") if card.has_meta("target_rotation") else null
	var previous_scale = card.get_meta("target_scale") if card.has_meta("target_scale") else null
	if (
		previous_position is Vector2
		and previous_rotation is float
		and previous_scale is Vector2
		and previous_position == target_position
		and is_equal_approx(previous_rotation, target_rotation)
		and previous_scale == target_scale
	):
		return

	var previous_tween = card.get_meta("hover_tween") if card.has_meta("hover_tween") else null
	if previous_tween is Tween:
		previous_tween.kill()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "offset_left", target_position.x, CARD_LAYOUT_TWEEN_SECONDS)
	tween.tween_property(card, "offset_top", target_position.y, CARD_LAYOUT_TWEEN_SECONDS)
	tween.tween_property(card, "offset_right", target_position.x + CARD_SIZE.x, CARD_LAYOUT_TWEEN_SECONDS)
	tween.tween_property(card, "offset_bottom", target_position.y + CARD_SIZE.y, CARD_LAYOUT_TWEEN_SECONDS)
	tween.tween_property(card, "rotation_degrees", target_rotation, CARD_LAYOUT_TWEEN_SECONDS)
	tween.tween_property(card, "scale", target_scale, CARD_LAYOUT_TWEEN_SECONDS)
	card.set_meta("target_position", target_position)
	card.set_meta("target_rotation", target_rotation)
	card.set_meta("target_scale", target_scale)
	card.set_meta("hover_tween", tween)


func _request_local_skill(skill_name: String, target_peer_id: int = -1) -> bool:
	var world := get_parent()
	if world == null:
		return false

	var game_manager := world.get_node_or_null("GameManager")
	if game_manager == null or not game_manager.has_method("request_local_skill"):
		return false

	return bool(game_manager.request_local_skill(skill_name, target_peer_id))


func _find_player_at_screen_position(screen_position: Vector2) -> Node2D:
	var world := get_parent()
	if world == null:
		return null

	var players := world.get_node_or_null("Players")
	if players == null:
		return null

	var best_target: Node2D = null
	var best_distance_squared := INF
	for node in players.get_children():
		var player := node as Node2D
		if player == null or player == _heal_target_floor_root:
			continue
		var health = player.get("_health")
		if (health is int or health is float) and int(health) <= 0:
			continue

		var center := _get_player_floor_target_center(player)
		var ellipse_delta := screen_position - center
		var ellipse_radius_x := HEAL_TARGET_FLOOR_RADIUS
		var ellipse_radius_y := HEAL_TARGET_FLOOR_RADIUS * HEAL_TARGET_FLOOR_Y_SCALE
		var ellipse_distance_squared := (
			(ellipse_delta.x * ellipse_delta.x) / (ellipse_radius_x * ellipse_radius_x)
			+ (ellipse_delta.y * ellipse_delta.y) / (ellipse_radius_y * ellipse_radius_y)
		)
		var distance_squared := center.distance_squared_to(screen_position)
		var body_center := player.get_global_transform_with_canvas().origin
		var body_rect := Rect2(body_center - PLAYER_TARGET_BODY_RECT * 0.5, PLAYER_TARGET_BODY_RECT)
		var is_over_floor_ellipse := ellipse_distance_squared <= 1.0
		if not is_over_floor_ellipse and not body_rect.has_point(screen_position):
			continue

		if distance_squared < best_distance_squared:
			best_distance_squared = distance_squared
			best_target = player

	return best_target


func _get_player_floor_target_center(player: Node2D) -> Vector2:
	return player.get_global_transform_with_canvas() * HEAL_TARGET_FLOOR_OFFSET


func _get_player_floor_target_world_center(player: Node2D) -> Vector2:
	return player.global_position + HEAL_TARGET_FLOOR_OFFSET


func _get_heal_target_floor_parent() -> Node:
	var world := get_parent()
	if world == null:
		return null

	return world.get_node_or_null("Players")


func _get_skillshot_screen_targets() -> Array[Vector2]:
	var world := get_parent()
	if world == null:
		return []

	var targets: Array[Vector2] = []
	var local_player := _get_local_player_node()
	var players := world.get_node_or_null("Players")
	if players != null:
		for node in players.get_children():
			var player := node as Node2D
			if player == null or player == local_player or player == _heal_target_floor_root:
				continue
			if not player.is_in_group("damageable"):
				continue
			var player_health_value = player.get("_health")
			if player_health_value == null:
				continue
			if int(player_health_value) <= 0:
				continue
			targets.append(player.get_global_transform_with_canvas().origin)

	var enemies := world.get_node_or_null("Enemies")
	if enemies != null:
		for node in enemies.get_children():
			var enemy := node as Node2D
			if enemy == null:
				continue
			if not enemy.is_in_group("damageable"):
				continue
			var enemy_health_value = enemy.get("_health")
			if enemy_health_value == null:
				continue
			if int(enemy_health_value) <= 0:
				continue
			targets.append(enemy.get_global_transform_with_canvas().origin)

	return targets


func _get_local_player_node() -> Node2D:
	var world := get_parent()
	if world == null:
		return null

	var players := world.get_node_or_null("Players")
	if players == null:
		return null

	return players.get_node_or_null(str(multiplayer.get_unique_id())) as Node2D


func _get_local_player_screen_position() -> Vector2:
	var player := _get_local_player_node()
	if player == null:
		return Vector2.INF

	return player.get_global_transform_with_canvas().origin


func _update_local_player_stamina_bar(current_value: float) -> void:
	var world := get_parent()
	if world == null:
		return

	var game_manager := world.get_node_or_null("GameManager")
	if game_manager == null or not game_manager.has_method("set_local_stamina_bar"):
		return

	game_manager.set_local_stamina_bar(current_value, float(SKILL_STAMINA.MAX_STAMINA))


func _get_card_stamina_cost(card: PanelContainer) -> int:
	if card == null:
		return 0

	return int(card.get_meta("stamina_cost", 0))


func _is_heal_card(card: PanelContainer) -> bool:
	if card == null:
		return false

	return str(card.get_meta("skill_type", "attack")) == "heal"
