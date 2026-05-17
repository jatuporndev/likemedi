extends CanvasLayer

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const SKILL_DECK := preload("res://scripts/game/skill_deck.gd")
const SKILL_CARD_VIEW := preload("res://scripts/ui/skill_card_view.gd")

var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _host_label: Label
var _player_name_label: Label
var _fps_label: Label
var _draw_deck_label: Label
var _discard_deck_label: Label
var _dragged_skill_card: PanelContainer
var _release_hint: Label
var _drag_line: Line2D
var _drag_arrow_head: Polygon2D
var _room_code := ""
var _is_dragging_skill_card := false
var _dragged_skill := ""
var _skill_deck := SKILL_DECK.new()
var _hand_cards: Array[PanelContainer] = []

const CARD_SIZE := Vector2(108.0, 148.0)
const CARD_BOTTOM_MARGIN := 18.0
const CARD_ATTACK_RELEASE_HEIGHT := 190.0
const CARD_HAND_STEP := 70.0
const CARD_HAND_RISE := 7.0
const CARD_HOVER_LIFT := 18.0
const CARD_HOVER_SCALE := 1.06
const DECK_SHUFFLE_SECONDS := 2.0
const DRAW_AFTER_SHUFFLE_DELAY := DECK_SHUFFLE_SECONDS * 0.5
const HAND_REFILL_START_DELAY := 0.25
const CARD_DRAW_DELAY := 0.18

var _hovered_skill_card: PanelContainer
var _is_dealing_hand := false


func _ready() -> void:
	NetworkManager.chat_message_received.connect(_on_chat_message)
	_build_ui()


func _process(_delta: float) -> void:
	if _player_name_label != null:
		_player_name_label.text = _get_local_player_name()
	if _fps_label != null:
		_fps_label.text = "FPS %d" % Engine.get_frames_per_second()
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
	deck_panel.offset_left = -236
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

	_draw_deck_label = _create_deck_stack_label("Draw Pile", 0)
	stacks.add_child(_draw_deck_label)

	_discard_deck_label = _create_deck_stack_label("Discard", 0)
	stacks.add_child(_discard_deck_label)

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


func _build_skill_card_ui() -> void:
	_drag_line = Line2D.new()
	_drag_line.visible = false
	_drag_line.z_index = 35
	_drag_line.width = 3.0
	_drag_line.default_color = Color(0.95, 0.74, 0.28, 0.75)
	add_child(_drag_line)

	_drag_arrow_head = Polygon2D.new()
	_drag_arrow_head.visible = false
	_drag_arrow_head.z_index = 36
	_drag_arrow_head.color = Color(0.95, 0.74, 0.28, 0.85)
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
		str(definition["cost"]),
		str(definition["description"]),
		art_color
	)
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
	_drag_line.visible = true
	_drag_arrow_head.visible = true
	_update_skill_card_drag_at(mouse_position)


func _finish_skill_card_drag(mouse_position: Vector2) -> void:
	if not _is_dragging_skill_card:
		return

	_is_dragging_skill_card = false
	var was_used := false
	if mouse_position.y <= get_viewport().get_visible_rect().size.y - CARD_ATTACK_RELEASE_HEIGHT:
		was_used = _request_local_skill(_dragged_skill)

	_release_hint.visible = false
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	var used_card := _dragged_skill_card
	_dragged_skill_card = null
	_dragged_skill = ""
	if was_used and used_card != null:
		_discard_card(used_card)
	if _hand_cards.is_empty():
		_request_full_hand_draw()
	_reset_skill_card_positions()


func _request_full_hand_draw() -> void:
	if _is_dealing_hand:
		return

	_is_dealing_hand = true
	get_tree().create_timer(HAND_REFILL_START_DELAY).timeout.connect(_deal_next_hand_card)


func _deal_next_hand_card() -> void:
	if not _skill_deck.can_add_to_hand():
		_is_dealing_hand = false
		return
	if _skill_deck.is_shuffling or _skill_deck.is_waiting_to_draw_after_shuffle:
		_is_dealing_hand = false
		return

	var hand_size_before := _hand_cards.size()
	_draw_card()
	if _hand_cards.size() == hand_size_before:
		_is_dealing_hand = false
		return

	get_tree().create_timer(CARD_DRAW_DELAY).timeout.connect(_deal_next_hand_card)


func _update_skill_card_drag() -> void:
	var mouse_position := get_viewport().get_mouse_position()
	_update_skill_card_drag_at(mouse_position)


func _update_skill_card_drag_at(mouse_position: Vector2) -> void:
	_release_hint.visible = mouse_position.y <= get_viewport().get_visible_rect().size.y - CARD_ATTACK_RELEASE_HEIGHT

	var active_card := _dragged_skill_card
	if active_card == null and not _hand_cards.is_empty():
		active_card = _hand_cards[0]
	if active_card == null:
		return
	var card_tip := active_card.global_position + Vector2(CARD_SIZE.x * 0.5, 8.0)
	_drag_line.points = PackedVector2Array([
		card_tip,
		mouse_position,
	])
	_update_drag_arrow_head(card_tip, mouse_position)


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
		var card_index := float(index)
		var hand_center := (float(hand_count) - 1.0) * 0.5
		var center_offset: float = (card_index - hand_center) * CARD_HAND_STEP
		var distance_from_center: float = absf(card_index - hand_center)
		var rise: float = -CARD_HAND_RISE * (1.0 - minf(distance_from_center, 1.0))
		var rotation: float = clampf(center_offset / CARD_HAND_STEP, -2.0, 2.0) * 4.0
		_reset_skill_card_position(_hand_cards[index], center_offset, rise, rotation, 40 + index)


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
	var previous_position = card.get_meta("target_position", null)
	var previous_rotation = card.get_meta("target_rotation", null)
	var previous_scale = card.get_meta("target_scale", null)
	if (
		previous_position is Vector2
		and previous_rotation is float
		and previous_scale is Vector2
		and previous_position == target_position
		and is_equal_approx(previous_rotation, target_rotation)
		and previous_scale == target_scale
	):
		return

	var previous_tween = card.get_meta("hover_tween", null)
	if previous_tween is Tween:
		previous_tween.kill()

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(card, "offset_left", target_position.x, 0.12)
	tween.tween_property(card, "offset_top", target_position.y, 0.12)
	tween.tween_property(card, "offset_right", target_position.x + CARD_SIZE.x, 0.12)
	tween.tween_property(card, "offset_bottom", target_position.y + CARD_SIZE.y, 0.12)
	tween.tween_property(card, "rotation_degrees", target_rotation, 0.12)
	tween.tween_property(card, "scale", target_scale, 0.12)
	card.set_meta("target_position", target_position)
	card.set_meta("target_rotation", target_rotation)
	card.set_meta("target_scale", target_scale)
	card.set_meta("hover_tween", tween)


func _request_local_skill(skill_name: String) -> bool:
	var world := get_parent()
	if world == null:
		return false

	var game_manager := world.get_node_or_null("GameManager")
	if game_manager == null or not game_manager.has_method("request_local_skill"):
		return false

	return bool(game_manager.request_local_skill(skill_name))
