extends CanvasLayer

const SKILL_CARD_DATABASE := preload("res://scripts/game/skill_card_database.gd")
const SKILL_DECK := preload("res://scripts/game/skill_deck.gd")
const SKILL_STAMINA := preload("res://scripts/game/skill_stamina.gd")
const PLAYER_TARGET_PREVIEW := preload("res://scripts/ui/player_target_preview.gd")
const SKILL_CARD_SCENE := preload("res://scenes/ui/skill_card_view.tscn")
const MINIMAP := preload("res://scripts/ui/minimap.gd")
const DECK_BUILDER_SCENE := preload("res://scenes/ui/deck_builder.tscn")

var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _host_label: Label
var _player_name_label: Label
var _fps_label: Label
var _health_value_label: Label
var _health_bar: ProgressBar
var _stamina_value_label: Label
var _stamina_bar: ProgressBar
var _hand_stamina_badge: PanelContainer
var _hand_stamina_label: Label
var _hand_stamina_badge_style: StyleBoxFlat
var _hand_stamina_shake_tween: Tween
var _draw_deck_label: Label
var _discard_deck_label: Label
var _end_hand_button: Control
var _buff_status_panel: PanelContainer
var _buff_status_icon: Label
var _buff_status_tooltip: PanelContainer
var _buff_status_tooltip_label: Label
var _debuff_status_panel: PanelContainer
var _debuff_status_icon: Label
var _debuff_status_tooltip: PanelContainer
var _debuff_status_tooltip_label: Label
var _pause_overlay: Control
var _deck_builder_overlay: Control
var _deck_builder_button: Button
var _deck_builder_dirty := false
var _minimap_panel: PanelContainer
var _dragged_skill_card: PanelContainer
var _release_hint: Label
var _card_status_label: Label
var _drag_line: Line2D
var _drag_arrow_head: Polygon2D
var _skill_preview_rects: Array[Polygon2D] = []
var _skill_preview_border: Line2D
var _skill_preview_centerline: Line2D
var _skill_preview_rune_marks: Array[Line2D] = []
var _skill_preview_label: Label
var _player_target_preview
var _room_code := ""
var _is_dragging_skill_card := false
var _dragged_skill := ""
var _skill_deck := SKILL_DECK.new()
var _skill_stamina := SKILL_STAMINA.new()
var _hand_cards: Array[PanelContainer] = []

const CARD_SIZE := Vector2(124.0, 174.0)
const CARD_SCREEN_SCALE := 0.76
const CARD_BOTTOM_MARGIN := 12.0
const CARD_SIDE_MARGIN := 40.0
const CARD_HAND_STEP := 64.0
const CARD_HAND_RISE := 6.0
const CARD_HOVER_LIFT := 16.0
const CARD_HOVER_SCALE := 0.86
const CARD_AIM_HAND_DIP := 76.0
const CARD_AIM_SELECTED_DIP := 22.0
const CARD_AIM_HAND_SPREAD_SCALE := 0.86
const CARD_AIM_HAND_SCALE := 0.69
const CARD_LAYOUT_TWEEN_SECONDS := 0.16
const HAND_STAMINA_BADGE_SIZE := 34.0
const HAND_STAMINA_BADGE_GAP := 24.0
const HAND_STAMINA_SHAKE_SECONDS := 0.045
const HAND_STAMINA_SHAKE_ROTATION := 10.0
const HAND_STAMINA_ERROR_SECONDS := 0.5
const DECK_SHUFFLE_SECONDS := 2.0
const DRAW_AFTER_SHUFFLE_DELAY := DECK_SHUFFLE_SECONDS * 0.5
const HAND_REFILL_START_DELAY := 0.25
const CARD_DRAW_DELAY := 0.18
const END_HAND_STAMINA_COST := 1
const END_HAND_BUTTON_HOVER_SCALE := Vector2(1.07, 1.07)
const END_HAND_BUTTON_PRESSED_SCALE := Vector2(0.94, 0.94)
const END_HAND_BUTTON_ANIMATION_SECONDS := 0.10
const SKILL_PREVIEW_WIDTH := 44.0
const SKILL_PREVIEW_START_OFFSET := Vector2(0.0, 36.0)
const SKILL_PREVIEW_FORWARD_OFFSET := 30.0
const SKILL_PREVIEW_OPACITY_STEPS := [0.10, 0.16, 0.24, 0.34, 0.46, 0.60, 0.74, 0.86, 0.96, 1.0]
const SKILL_PREVIEW_HIT_PADDING := 20.0
const SKILL_PREVIEW_TARGET_RADIUS := 34.0
const SKILL_PREVIEW_RUNE_MARK_COUNT := 8
const SKILL_PREVIEW_VALID_FILL := Color(0.92, 0.32, 0.08, 0.24)
const SKILL_PREVIEW_VALID_BORDER := Color(1.0, 0.70, 0.24, 0.46)
const SKILL_PREVIEW_VALID_GLYPH := Color(1.0, 0.88, 0.52, 0.62)
const SKILL_PREVIEW_INVALID_FILL := Color(0.28, 0.26, 0.24, 0.18)
const SKILL_PREVIEW_INVALID_BORDER := Color(0.62, 0.56, 0.48, 0.30)
const SKILL_PREVIEW_INVALID_GLYPH := Color(0.72, 0.66, 0.56, 0.34)
const STRIKE_SKILL_NAME := "strike"
const STRIKE_PREVIEW_SEGMENTS := 28
const STRIKE_PREVIEW_FORWARD_OFFSET := 28.0
const PLAYER_TARGET_BODY_RECT := Vector2(76.0, 116.0)
const FAST_BOI_BUFF_WARNING_SECONDS := 10.0
const WAIT_BOI_DEBUFF_WARNING_SECONDS := 2.0
const BUFF_STATUS_TOOLTIP_OFFSET := Vector2(14.0, 14.0)

var _hovered_skill_card: PanelContainer
var _is_dealing_hand := false
var _hovered_heal_target_peer_id := -1
var _hovered_skill_target_in_range := true
var _is_hovering_buff_status := false
var _is_hovering_debuff_status := false


func _ready() -> void:
	NetworkManager.chat_message_received.connect(_on_chat_message)
	_build_ui()


func _process(delta: float) -> void:
	_update_player_status_ui()
	_update_buff_status_ui()
	_update_debuff_status_ui()
	_update_end_hand_button()
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
			_toggle_pause_menu()
			get_viewport().set_input_as_handled()
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
	if NetworkManager.is_host():
		_room_code = NetworkManager.get_host_info()

	_fps_label = Label.new()
	_fps_label.anchor_left = 1.0
	_fps_label.anchor_top = 0.0
	_fps_label.anchor_right = 1.0
	_fps_label.anchor_bottom = 0.0
	_fps_label.offset_left = -78.0
	_fps_label.offset_top = 12.0
	_fps_label.offset_right = -12.0
	_fps_label.offset_bottom = 30.0
	_fps_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_fps_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_fps_label.text = "FPS 0"
	_fps_label.add_theme_color_override("font_color", Color(0.75, 0.96, 0.72))
	_fps_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.9))
	_fps_label.add_theme_constant_override("shadow_offset_x", 1)
	_fps_label.add_theme_constant_override("shadow_offset_y", 1)
	_fps_label.add_theme_font_size_override("font_size", 10)
	add_child(_fps_label)

	_build_minimap_ui()
	_build_player_status_card()
	_build_deck_builder_button()
	_build_buff_status_ui()
	_build_debuff_status_ui()

	var chat_panel := PanelContainer.new()
	chat_panel.anchor_left = 0.0
	chat_panel.anchor_top = 1.0
	chat_panel.anchor_right = 0.0
	chat_panel.anchor_bottom = 1.0
	chat_panel.offset_left = 12
	chat_panel.offset_top = -142
	chat_panel.offset_right = 224
	chat_panel.offset_bottom = -12
	chat_panel.add_theme_stylebox_override("panel", _create_chat_panel_style())
	add_child(chat_panel)

	var chat_margin := MarginContainer.new()
	chat_margin.add_theme_constant_override("margin_left", 7)
	chat_margin.add_theme_constant_override("margin_right", 7)
	chat_margin.add_theme_constant_override("margin_top", 7)
	chat_margin.add_theme_constant_override("margin_bottom", 7)
	chat_panel.add_child(chat_margin)

	var chat_layout := VBoxContainer.new()
	chat_layout.add_theme_constant_override("separation", 5)
	chat_margin.add_child(chat_layout)

	_chat_log = RichTextLabel.new()
	_chat_log.custom_minimum_size = Vector2(0, 76)
	_chat_log.fit_content = false
	_chat_log.scroll_following = true
	_chat_log.add_theme_stylebox_override("normal", _create_chat_log_style())
	_chat_log.add_theme_color_override("default_color", Color(0.94, 0.88, 0.74))
	_chat_log.add_theme_font_size_override("normal_font_size", 10)
	_chat_log.add_theme_font_size_override("bold_font_size", 10)
	chat_layout.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Chat"
	_chat_input.add_theme_stylebox_override("normal", _create_chat_input_style(false))
	_chat_input.add_theme_stylebox_override("focus", _create_chat_input_style(true))
	_chat_input.add_theme_color_override("font_color", Color(0.96, 0.90, 0.76))
	_chat_input.add_theme_color_override("font_placeholder_color", Color(0.62, 0.52, 0.38))
	_chat_input.add_theme_color_override("caret_color", Color(1.0, 0.82, 0.42))
	_chat_input.add_theme_font_size_override("font_size", 10)
	_chat_input.text_submitted.connect(_submit_chat)
	chat_layout.add_child(_chat_input)

	_build_deck_ui()
	_build_skill_card_ui()
	_build_pause_menu()


func _build_deck_builder_button() -> void:
	_deck_builder_button = Button.new()
	_deck_builder_button.text = "Deck"
	_deck_builder_button.tooltip_text = "Open Deck Builder"
	_deck_builder_button.focus_mode = Control.FOCUS_NONE
	_deck_builder_button.anchor_left = 0.0
	_deck_builder_button.anchor_top = 0.0
	_deck_builder_button.anchor_right = 0.0
	_deck_builder_button.anchor_bottom = 0.0
	_deck_builder_button.offset_left = 12.0
	_deck_builder_button.offset_top = 112.0
	_deck_builder_button.offset_right = 92.0
	_deck_builder_button.offset_bottom = 148.0
	_deck_builder_button.pressed.connect(_toggle_deck_builder)
	_deck_builder_button.add_theme_font_size_override("font_size", 13)
	_deck_builder_button.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	_deck_builder_button.add_theme_stylebox_override(
		"normal",
		_create_pause_button_style(Color(0.18, 0.12, 0.07, 0.98), Color(0.54, 0.36, 0.16))
	)
	_deck_builder_button.add_theme_stylebox_override(
		"hover",
		_create_pause_button_style(Color(0.24, 0.16, 0.08, 0.98), Color(0.90, 0.67, 0.30))
	)
	_deck_builder_button.add_theme_stylebox_override(
		"pressed",
		_create_pause_button_style(Color(0.12, 0.09, 0.07, 0.98), Color(0.74, 0.50, 0.22))
	)
	add_child(_deck_builder_button)


func _build_minimap_ui() -> void:
	_minimap_panel = PanelContainer.new()
	_minimap_panel.anchor_left = 1.0
	_minimap_panel.anchor_top = 0.0
	_minimap_panel.anchor_right = 1.0
	_minimap_panel.anchor_bottom = 0.0
	_minimap_panel.offset_left = -172.0
	_minimap_panel.offset_top = 38.0
	_minimap_panel.offset_right = -12.0
	_minimap_panel.offset_bottom = 198.0
	_minimap_panel.add_theme_stylebox_override("panel", _create_status_panel_style())
	add_child(_minimap_panel)

	var minimap := MINIMAP.new()
	minimap.world_path = NodePath("../../..")
	minimap.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap.offset_left = 0.0
	minimap.offset_top = 0.0
	minimap.offset_right = 0.0
	minimap.offset_bottom = 0.0
	_minimap_panel.add_child(minimap)


func _submit_chat(message: String) -> void:
	NetworkManager.submit_chat_message(message)
	_chat_input.clear()
	_chat_input.release_focus()


func _on_chat_message(sender_id: int, message: String) -> void:
	var sender_name := str(NetworkManager.player_names.get(sender_id, "Player %d" % sender_id))
	_chat_log.append_text("[b]%s:[/b] %s\n" % [sender_name, message])


func _copy_room_code() -> void:
	if _room_code.is_empty():
		_room_code = NetworkManager.get_host_info()

	DisplayServer.clipboard_set(_room_code)
	if _host_label != null:
		_host_label.text = "Room %s copied" % _room_code


func _create_chat_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.055, 0.04, 0.92)
	panel_style.border_color = Color(0.68, 0.44, 0.18, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	return panel_style


func _create_chat_log_style() -> StyleBoxFlat:
	var log_style := StyleBoxFlat.new()
	log_style.bg_color = Color(0.035, 0.028, 0.022, 0.70)
	log_style.border_color = Color(0.32, 0.22, 0.12, 0.82)
	log_style.border_width_left = 1
	log_style.border_width_top = 1
	log_style.border_width_right = 1
	log_style.border_width_bottom = 1
	log_style.corner_radius_top_left = 4
	log_style.corner_radius_top_right = 4
	log_style.corner_radius_bottom_left = 4
	log_style.corner_radius_bottom_right = 4
	log_style.content_margin_left = 5
	log_style.content_margin_right = 5
	log_style.content_margin_top = 4
	log_style.content_margin_bottom = 4
	return log_style


func _create_chat_input_style(is_focused: bool) -> StyleBoxFlat:
	var input_style := StyleBoxFlat.new()
	input_style.bg_color = Color(0.10, 0.075, 0.055, 0.98)
	input_style.border_color = Color(0.90, 0.67, 0.30, 0.95) if is_focused else Color(0.54, 0.36, 0.16, 0.95)
	input_style.border_width_left = 1
	input_style.border_width_top = 1
	input_style.border_width_right = 1
	input_style.border_width_bottom = 1
	input_style.corner_radius_top_left = 4
	input_style.corner_radius_top_right = 4
	input_style.corner_radius_bottom_left = 4
	input_style.corner_radius_bottom_right = 4
	input_style.content_margin_left = 6
	input_style.content_margin_right = 6
	input_style.content_margin_top = 3
	input_style.content_margin_bottom = 3
	return input_style


func _build_player_status_card() -> void:
	var status_panel := PanelContainer.new()
	status_panel.anchor_left = 0.0
	status_panel.anchor_top = 0.0
	status_panel.anchor_right = 0.0
	status_panel.anchor_bottom = 0.0
	status_panel.offset_left = 12.0
	status_panel.offset_top = 12.0
	status_panel.offset_right = 230.0
	status_panel.offset_bottom = 104.0
	status_panel.add_theme_stylebox_override("panel", _create_status_panel_style())
	add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(status_margin)

	var status_layout := VBoxContainer.new()
	status_layout.add_theme_constant_override("separation", 7)
	status_margin.add_child(status_layout)

	_player_name_label = Label.new()
	_player_name_label.text = _get_local_player_name()
	_player_name_label.clip_text = true
	_player_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_player_name_label.add_theme_font_size_override("font_size", 15)
	_player_name_label.add_theme_color_override("font_color", Color.WHITE)
	status_layout.add_child(_player_name_label)

	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 7)
	status_layout.add_child(health_row)

	var health_label := Label.new()
	health_label.custom_minimum_size = Vector2(28.0, 0.0)
	health_label.text = "HP"
	health_label.add_theme_font_size_override("font_size", 11)
	health_label.add_theme_color_override("font_color", Color.WHITE)
	health_row.add_child(health_label)

	_health_bar = _create_status_progress_bar(
		Color(0.12, 0.04, 0.035, 1.0),
		Color(0.74, 0.16, 0.10, 1.0),
		10.0
	)
	_health_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	health_row.add_child(_health_bar)

	_health_value_label = Label.new()
	_health_value_label.custom_minimum_size = Vector2(46.0, 0.0)
	_health_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_health_value_label.add_theme_font_size_override("font_size", 11)
	_health_value_label.add_theme_color_override("font_color", Color.WHITE)
	health_row.add_child(_health_value_label)

	var stamina_row := HBoxContainer.new()
	stamina_row.add_theme_constant_override("separation", 7)
	status_layout.add_child(stamina_row)

	var stamina_label := Label.new()
	stamina_label.custom_minimum_size = Vector2(28.0, 0.0)
	stamina_label.text = "SP"
	stamina_label.add_theme_font_size_override("font_size", 11)
	stamina_label.add_theme_color_override("font_color", Color.WHITE)
	stamina_row.add_child(stamina_label)

	_stamina_bar = _create_status_progress_bar(
		Color(0.05, 0.10, 0.13, 1.0),
		Color(0.21, 0.66, 0.86, 1.0),
		10.0
	)
	_stamina_bar.max_value = SKILL_STAMINA.MAX_STAMINA
	_stamina_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stamina_row.add_child(_stamina_bar)

	_stamina_value_label = Label.new()
	_stamina_value_label.custom_minimum_size = Vector2(46.0, 0.0)
	_stamina_value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_stamina_value_label.add_theme_font_size_override("font_size", 11)
	_stamina_value_label.add_theme_color_override("font_color", Color.WHITE)
	stamina_row.add_child(_stamina_value_label)

	_update_player_status_ui()
	_update_stamina_ui()


func _create_status_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.07, 0.055, 0.04, 0.96)
	panel_style.border_color = Color(0.68, 0.44, 0.18, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	return panel_style


func _create_status_progress_bar(background_color: Color, fill_color: Color, height: float) -> ProgressBar:
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


func _update_player_status_ui() -> void:
	if _player_name_label != null:
		_player_name_label.text = _get_local_player_name()
	if _health_bar == null or _health_value_label == null:
		return

	var player := _get_local_player_node()
	var max_health := 100
	var current_health := max_health
	if player != null:
		var health_value = player.get("_health")
		var max_health_value = player.get("_max_health")
		if health_value is int or health_value is float:
			current_health = int(health_value)
		if max_health_value is int or max_health_value is float:
			max_health = maxi(int(max_health_value), 1)

	_health_bar.max_value = float(max_health)
	_health_bar.value = clampf(float(current_health), 0.0, float(max_health))
	_health_value_label.text = "%d/%d" % [current_health, max_health]


func _build_buff_status_ui() -> void:
	_buff_status_panel = PanelContainer.new()
	_buff_status_panel.visible = false
	_buff_status_panel.anchor_left = 1.0
	_buff_status_panel.anchor_top = 0.5
	_buff_status_panel.anchor_right = 1.0
	_buff_status_panel.anchor_bottom = 0.5
	_buff_status_panel.offset_left = -48.0
	_buff_status_panel.offset_top = -16.0
	_buff_status_panel.offset_right = -16.0
	_buff_status_panel.offset_bottom = 16.0
	_buff_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_buff_status_panel.z_index = 55
	_buff_status_panel.add_theme_stylebox_override("panel", _create_buff_status_panel_style())
	_buff_status_panel.mouse_entered.connect(_on_buff_status_mouse_entered)
	_buff_status_panel.mouse_exited.connect(_on_buff_status_mouse_exited)
	add_child(_buff_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	_buff_status_panel.add_child(margin)

	_buff_status_icon = Label.new()
	_buff_status_icon.text = ">>"
	_buff_status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_status_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_buff_status_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_buff_status_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_buff_status_icon.add_theme_font_size_override("font_size", 13)
	_buff_status_icon.add_theme_color_override("font_color", Color(0.66, 0.92, 1.0))
	margin.add_child(_buff_status_icon)

	_buff_status_tooltip = PanelContainer.new()
	_buff_status_tooltip.visible = false
	_buff_status_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_buff_status_tooltip.z_index = 70
	_buff_status_tooltip.add_theme_stylebox_override("panel", _create_buff_status_tooltip_style())
	add_child(_buff_status_tooltip)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 6)
	tooltip_margin.add_theme_constant_override("margin_right", 6)
	tooltip_margin.add_theme_constant_override("margin_top", 3)
	tooltip_margin.add_theme_constant_override("margin_bottom", 3)
	_buff_status_tooltip.add_child(tooltip_margin)

	_buff_status_tooltip_label = Label.new()
	_buff_status_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_buff_status_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_buff_status_tooltip_label.add_theme_font_size_override("font_size", 10)
	_buff_status_tooltip_label.add_theme_color_override("font_color", Color(0.88, 0.98, 1.0))
	tooltip_margin.add_child(_buff_status_tooltip_label)


func _create_buff_status_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.035, 0.11, 0.16, 0.92)
	panel_style.border_color = Color(0.30, 0.74, 0.92, 0.86)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	return panel_style


func _create_buff_status_tooltip_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.025, 0.055, 0.07, 0.94)
	panel_style.border_color = Color(0.30, 0.74, 0.92, 0.76)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	return panel_style


func _update_buff_status_ui() -> void:
	if _buff_status_panel == null:
		return

	var remaining_time := _get_fast_boi_remaining_time()
	var is_active := remaining_time > 0.0
	_buff_status_panel.visible = is_active
	if not is_active:
		_is_hovering_buff_status = false
		if _buff_status_tooltip != null:
			_buff_status_tooltip.visible = false
		return

	_update_buff_status_tooltip(remaining_time)
	var panel_alpha := 1.0
	if remaining_time < FAST_BOI_BUFF_WARNING_SECONDS:
		panel_alpha = 0.28 if int(Time.get_ticks_msec() / 250) % 2 == 0 else 1.0
	_buff_status_panel.modulate = Color(1.0, 1.0, 1.0, panel_alpha)
	_buff_status_icon.modulate = Color.WHITE


func _update_buff_status_tooltip(remaining_time: float) -> void:
	if _buff_status_tooltip == null or _buff_status_tooltip_label == null:
		return

	_buff_status_tooltip.visible = _is_hovering_buff_status
	if not _is_hovering_buff_status:
		return

	_buff_status_tooltip_label.text = _format_buff_time(remaining_time)
	_buff_status_tooltip.reset_size()
	var tooltip_size := _buff_status_tooltip.size
	var viewport_size := get_viewport().get_visible_rect().size
	var target_position := get_viewport().get_mouse_position() + BUFF_STATUS_TOOLTIP_OFFSET
	target_position.x = minf(target_position.x, viewport_size.x - tooltip_size.x - 4.0)
	target_position.y = minf(target_position.y, viewport_size.y - tooltip_size.y - 4.0)
	target_position.x = maxf(target_position.x, 4.0)
	target_position.y = maxf(target_position.y, 4.0)
	_buff_status_tooltip.position = target_position


func _get_fast_boi_remaining_time() -> float:
	var player := _get_local_player_node()
	if player == null:
		return 0.0

	var remaining_time = player.get("_fast_boi_time")
	if remaining_time is int or remaining_time is float:
		return maxf(float(remaining_time), 0.0)
	return 0.0


func _format_buff_time(seconds: float) -> String:
	var whole_seconds := ceili(maxf(seconds, 0.0))
	var minutes := int(whole_seconds / 60)
	var remaining_seconds := whole_seconds % 60
	return "%d:%02d" % [minutes, remaining_seconds]


func _on_buff_status_mouse_entered() -> void:
	_is_hovering_buff_status = true


func _on_buff_status_mouse_exited() -> void:
	_is_hovering_buff_status = false


func _build_debuff_status_ui() -> void:
	_debuff_status_panel = PanelContainer.new()
	_debuff_status_panel.visible = false
	_debuff_status_panel.anchor_left = 1.0
	_debuff_status_panel.anchor_top = 0.5
	_debuff_status_panel.anchor_right = 1.0
	_debuff_status_panel.anchor_bottom = 0.5
	_debuff_status_panel.offset_left = -48.0
	_debuff_status_panel.offset_top = 22.0
	_debuff_status_panel.offset_right = -16.0
	_debuff_status_panel.offset_bottom = 54.0
	_debuff_status_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_debuff_status_panel.z_index = 55
	_debuff_status_panel.add_theme_stylebox_override("panel", _create_debuff_status_panel_style())
	_debuff_status_panel.mouse_entered.connect(_on_debuff_status_mouse_entered)
	_debuff_status_panel.mouse_exited.connect(_on_debuff_status_mouse_exited)
	add_child(_debuff_status_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 4)
	margin.add_theme_constant_override("margin_right", 4)
	margin.add_theme_constant_override("margin_top", 3)
	margin.add_theme_constant_override("margin_bottom", 3)
	_debuff_status_panel.add_child(margin)

	_debuff_status_icon = Label.new()
	_debuff_status_icon.text = "<<"
	_debuff_status_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debuff_status_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_debuff_status_icon.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_debuff_status_icon.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_debuff_status_icon.add_theme_font_size_override("font_size", 13)
	_debuff_status_icon.add_theme_color_override("font_color", Color(0.90, 0.72, 1.0))
	margin.add_child(_debuff_status_icon)

	_debuff_status_tooltip = PanelContainer.new()
	_debuff_status_tooltip.visible = false
	_debuff_status_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_debuff_status_tooltip.z_index = 70
	_debuff_status_tooltip.add_theme_stylebox_override("panel", _create_debuff_status_tooltip_style())
	add_child(_debuff_status_tooltip)

	var tooltip_margin := MarginContainer.new()
	tooltip_margin.add_theme_constant_override("margin_left", 6)
	tooltip_margin.add_theme_constant_override("margin_right", 6)
	tooltip_margin.add_theme_constant_override("margin_top", 3)
	tooltip_margin.add_theme_constant_override("margin_bottom", 3)
	_debuff_status_tooltip.add_child(tooltip_margin)

	_debuff_status_tooltip_label = Label.new()
	_debuff_status_tooltip_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_debuff_status_tooltip_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_debuff_status_tooltip_label.add_theme_font_size_override("font_size", 10)
	_debuff_status_tooltip_label.add_theme_color_override("font_color", Color(0.96, 0.90, 1.0))
	tooltip_margin.add_child(_debuff_status_tooltip_label)


func _create_debuff_status_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.035, 0.16, 0.92)
	panel_style.border_color = Color(0.70, 0.34, 0.92, 0.86)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 5
	panel_style.corner_radius_top_right = 5
	panel_style.corner_radius_bottom_left = 5
	panel_style.corner_radius_bottom_right = 5
	return panel_style


func _create_debuff_status_tooltip_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.055, 0.025, 0.07, 0.94)
	panel_style.border_color = Color(0.70, 0.34, 0.92, 0.76)
	panel_style.border_width_left = 1
	panel_style.border_width_top = 1
	panel_style.border_width_right = 1
	panel_style.border_width_bottom = 1
	panel_style.corner_radius_top_left = 4
	panel_style.corner_radius_top_right = 4
	panel_style.corner_radius_bottom_left = 4
	panel_style.corner_radius_bottom_right = 4
	return panel_style


func _update_debuff_status_ui() -> void:
	if _debuff_status_panel == null:
		return

	var remaining_time := _get_wait_boi_remaining_time()
	var is_active := remaining_time > 0.0
	_debuff_status_panel.visible = is_active
	if not is_active:
		_is_hovering_debuff_status = false
		if _debuff_status_tooltip != null:
			_debuff_status_tooltip.visible = false
		return

	_update_debuff_status_tooltip(remaining_time)
	var panel_alpha := 1.0
	if remaining_time < WAIT_BOI_DEBUFF_WARNING_SECONDS:
		panel_alpha = 0.28 if int(Time.get_ticks_msec() / 250) % 2 == 0 else 1.0
	_debuff_status_panel.modulate = Color(1.0, 1.0, 1.0, panel_alpha)
	_debuff_status_icon.modulate = Color.WHITE


func _update_debuff_status_tooltip(remaining_time: float) -> void:
	if _debuff_status_tooltip == null or _debuff_status_tooltip_label == null:
		return

	_debuff_status_tooltip.visible = _is_hovering_debuff_status
	if not _is_hovering_debuff_status:
		return

	_debuff_status_tooltip_label.text = _format_buff_time(remaining_time)
	_debuff_status_tooltip.reset_size()
	var tooltip_size := _debuff_status_tooltip.size
	var viewport_size := get_viewport().get_visible_rect().size
	var target_position := get_viewport().get_mouse_position() + BUFF_STATUS_TOOLTIP_OFFSET
	target_position.x = minf(target_position.x, viewport_size.x - tooltip_size.x - 4.0)
	target_position.y = minf(target_position.y, viewport_size.y - tooltip_size.y - 4.0)
	target_position.x = maxf(target_position.x, 4.0)
	target_position.y = maxf(target_position.y, 4.0)
	_debuff_status_tooltip.position = target_position


func _get_wait_boi_remaining_time() -> float:
	var player := _get_local_player_node()
	if player == null:
		return 0.0

	var remaining_time = player.get("_wait_boi_time")
	if remaining_time is int or remaining_time is float:
		return maxf(float(remaining_time), 0.0)
	return 0.0


func _on_debuff_status_mouse_entered() -> void:
	_is_hovering_debuff_status = true


func _on_debuff_status_mouse_exited() -> void:
	_is_hovering_debuff_status = false


func _build_pause_menu() -> void:
	_pause_overlay = Control.new()
	_pause_overlay.visible = false
	_pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_pause_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.z_index = 100
	add_child(_pause_overlay)

	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.015, 0.01, 0.58)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_overlay.add_child(shade)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(220.0, 0.0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -110.0
	panel.offset_top = -148.0
	panel.offset_right = 110.0
	panel.offset_bottom = 148.0
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.add_theme_stylebox_override("panel", _create_pause_panel_style())
	_pause_overlay.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 16)
	margin.add_theme_constant_override("margin_bottom", 16)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Paused"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_color_override("font_color", Color(1.0, 0.86, 0.52))
	title.add_theme_font_size_override("font_size", 20)
	layout.add_child(title)

	_host_label = Label.new()
	_host_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_host_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_host_label.add_theme_color_override("font_color", Color(0.92, 0.80, 0.58))
	_host_label.add_theme_font_size_override("font_size", 10)
	if NetworkManager.is_host():
		if _room_code.is_empty():
			_room_code = NetworkManager.get_host_info()
		_host_label.text = "Room %s" % _room_code
	else:
		_host_label.text = "Connected"
	layout.add_child(_host_label)

	if NetworkManager.is_host():
		var copy_button := _create_pause_button("Copy Code")
		copy_button.pressed.connect(_copy_room_code)
		layout.add_child(copy_button)

	var resume_button := _create_pause_button("Resume")
	resume_button.pressed.connect(_hide_pause_menu)
	layout.add_child(resume_button)

	var deck_button := _create_pause_button("Deck Builder")
	deck_button.pressed.connect(_on_deck_builder_pressed)
	layout.add_child(deck_button)

	var settings_button := _create_pause_button("Settings")
	layout.add_child(settings_button)

	var leave_button := _create_pause_button("Leave")
	leave_button.pressed.connect(Callable(NetworkManager, "leave_game"))
	layout.add_child(leave_button)


func _create_pause_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.075, 0.055, 0.97)
	panel_style.border_color = Color(0.90, 0.67, 0.30)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	return panel_style


func _create_pause_button(text: String) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(0.0, 30.0)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 13)
	button.add_theme_color_override("font_color", Color(0.95, 0.86, 0.62))
	button.add_theme_stylebox_override(
		"normal",
		_create_pause_button_style(Color(0.18, 0.12, 0.07, 0.98), Color(0.54, 0.36, 0.16))
	)
	button.add_theme_stylebox_override(
		"hover",
		_create_pause_button_style(Color(0.24, 0.16, 0.08, 0.98), Color(0.90, 0.67, 0.30))
	)
	button.add_theme_stylebox_override(
		"pressed",
		_create_pause_button_style(Color(0.12, 0.09, 0.07, 0.98), Color(0.74, 0.50, 0.22))
	)
	return button


func _create_pause_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = bg_color
	button_style.border_color = border_color
	button_style.border_width_left = 1
	button_style.border_width_top = 1
	button_style.border_width_right = 1
	button_style.border_width_bottom = 1
	button_style.corner_radius_top_left = 5
	button_style.corner_radius_top_right = 5
	button_style.corner_radius_bottom_left = 5
	button_style.corner_radius_bottom_right = 5
	return button_style


func _toggle_pause_menu() -> void:
	if _pause_overlay == null:
		return
	if _pause_overlay.visible:
		_hide_pause_menu()
	else:
		_show_pause_menu()


func _show_pause_menu() -> void:
	if _pause_overlay == null:
		return
	if _is_dragging_skill_card:
		_cancel_skill_card_drag()
	_pause_overlay.visible = true


func _hide_pause_menu() -> void:
	if _pause_overlay == null:
		return
	_pause_overlay.visible = false


func _on_deck_builder_pressed() -> void:
	_hide_pause_menu()
	_show_deck_builder()


func _toggle_deck_builder() -> void:
	if _deck_builder_overlay != null:
		_hide_deck_builder()
	else:
		_show_deck_builder()


func _show_deck_builder() -> void:
	if _deck_builder_overlay != null:
		_deck_builder_overlay.visible = true
		return

	_deck_builder_overlay = Control.new()
	_deck_builder_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_deck_builder_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_deck_builder_overlay.z_index = 120
	add_child(_deck_builder_overlay)

	var view := DECK_BUILDER_SCENE.instantiate()
	if view != null:
		_deck_builder_overlay.add_child(view)
		if view.has_signal("closed"):
			view.connect("closed", Callable(self, "_hide_deck_builder"))
		if view.has_signal("deck_changed"):
			view.connect("deck_changed", Callable(self, "_on_deck_builder_changed"))


func _hide_deck_builder() -> void:
	if _deck_builder_overlay == null:
		return
	_deck_builder_overlay.queue_free()
	_deck_builder_overlay = null
	if _deck_builder_dirty:
		_deck_builder_dirty = false
		_reload_skill_deck_from_saved_deck()


func _on_deck_builder_changed() -> void:
	_deck_builder_dirty = true


func _reload_skill_deck_from_saved_deck() -> void:
	if _is_dragging_skill_card:
		_cancel_skill_card_drag()

	for card in _hand_cards:
		if is_instance_valid(card):
			card.queue_free()
	_hand_cards.clear()
	_hovered_skill_card = null
	_skill_deck.setup_default_deck()
	_draw_full_hand()
	_reset_skill_card_positions()
	_update_deck_ui()


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
	deck_panel.offset_left = -244
	deck_panel.offset_top = -76
	deck_panel.offset_right = -16
	deck_panel.offset_bottom = -12
	deck_panel.add_theme_stylebox_override("panel", _create_deck_panel_style())
	add_child(deck_panel)

	var deck_margin := MarginContainer.new()
	deck_margin.add_theme_constant_override("margin_left", 8)
	deck_margin.add_theme_constant_override("margin_right", 8)
	deck_margin.add_theme_constant_override("margin_top", 8)
	deck_margin.add_theme_constant_override("margin_bottom", 8)
	deck_panel.add_child(deck_margin)

	var deck_layout := HBoxContainer.new()
	deck_layout.add_theme_constant_override("separation", 6)
	deck_margin.add_child(deck_layout)

	_end_hand_button = _create_end_hand_button()
	deck_layout.add_child(_end_hand_button)

	var stacks := HBoxContainer.new()
	stacks.add_theme_constant_override("separation", 5)
	deck_layout.add_child(stacks)

	_draw_deck_label = _create_deck_stack_label("Draw Pile", 0, false)
	stacks.add_child(_draw_deck_label)

	_discard_deck_label = _create_deck_stack_label("Discard", 0, true)
	stacks.add_child(_discard_deck_label)

	_update_end_hand_button()


func _create_deck_panel_style() -> StyleBoxFlat:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.08, 0.065, 0.05, 0.96)
	panel_style.border_color = Color(0.58, 0.38, 0.16, 0.95)
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 7
	panel_style.corner_radius_top_right = 7
	panel_style.corner_radius_bottom_left = 7
	panel_style.corner_radius_bottom_right = 7
	return panel_style


func _create_end_hand_button() -> Control:
	var button := Control.new()
	button.custom_minimum_size = Vector2(78.0, 42.0)
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pivot_offset = button.custom_minimum_size * 0.5
	button.set_meta("disabled", false)
	button.set_meta("hovered", false)
	button.set_meta("pressed", false)

	var background := PanelContainer.new()
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.add_theme_stylebox_override(
		"panel",
		_create_end_hand_button_style(Color(0.56, 0.19, 0.08), Color(1.0, 0.70, 0.25))
	)
	button.set_meta("background_panel", background)
	button.add_child(background)

	button.gui_input.connect(_on_end_hand_gui_input.bind(button))
	button.mouse_entered.connect(_set_end_hand_button_hovered.bind(button, true))
	button.mouse_exited.connect(_set_end_hand_button_hovered.bind(button, false))

	var cost_badge := PanelContainer.new()
	cost_badge.anchor_left = 0.0
	cost_badge.anchor_top = 0.0
	cost_badge.anchor_right = 0.0
	cost_badge.anchor_bottom = 0.0
	cost_badge.offset_left = 4.0
	cost_badge.offset_top = 4.0
	cost_badge.offset_right = 24.0
	cost_badge.offset_bottom = 24.0
	cost_badge.custom_minimum_size = Vector2(20.0, 20.0)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.add_theme_stylebox_override("panel", _create_end_hand_cost_badge_style())
	button.add_child(cost_badge)

	var cost_label := Label.new()
	cost_label.custom_minimum_size = Vector2(20.0, 20.0)
	cost_label.text = str(END_HAND_STAMINA_COST)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	cost_label.add_theme_font_size_override("font_size", 12)
	cost_badge.add_child(cost_label)

	var text_label := Label.new()
	text_label.anchor_right = 1.0
	text_label.anchor_bottom = 1.0
	text_label.offset_left = 19.0
	text_label.offset_right = -5.0
	text_label.text = "End\nHand"
	text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.62))
	text_label.add_theme_font_size_override("font_size", 10)
	button.add_child(text_label)
	return button


func _create_end_hand_button_style(bg_color: Color, border_color: Color) -> StyleBoxFlat:
	var button_style := StyleBoxFlat.new()
	button_style.bg_color = bg_color
	button_style.border_color = border_color
	button_style.border_width_left = 2
	button_style.border_width_top = 2
	button_style.border_width_right = 2
	button_style.border_width_bottom = 2
	button_style.corner_radius_top_left = 7
	button_style.corner_radius_top_right = 7
	button_style.corner_radius_bottom_left = 7
	button_style.corner_radius_bottom_right = 7
	button_style.content_margin_left = 6
	button_style.content_margin_right = 6
	button_style.content_margin_top = 6
	button_style.content_margin_bottom = 6
	return button_style


func _create_end_hand_cost_badge_style() -> StyleBoxFlat:
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Color(0.16, 0.35, 0.42, 1.0)
	badge_style.border_color = Color(0.72, 0.92, 1.0, 1.0)
	badge_style.border_width_left = 1
	badge_style.border_width_top = 1
	badge_style.border_width_right = 1
	badge_style.border_width_bottom = 1
	badge_style.corner_radius_top_left = 10
	badge_style.corner_radius_top_right = 10
	badge_style.corner_radius_bottom_left = 10
	badge_style.corner_radius_bottom_right = 10
	return badge_style


func _on_end_hand_gui_input(event: InputEvent, button: Control) -> void:
	if button == null or bool(button.get_meta("disabled", false)) or _is_local_player_dead():
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_set_end_hand_button_pressed(button, true)
		else:
			_set_end_hand_button_pressed(button, false)
			_on_end_hand_pressed()


func _set_end_hand_button_hovered(button: Control, is_hovered: bool) -> void:
	if button == null or bool(button.get_meta("disabled", false)):
		return
	button.set_meta("hovered", is_hovered)
	if not is_hovered:
		button.set_meta("pressed", false)
	_set_end_hand_button_style(button, is_hovered, bool(button.get_meta("pressed", false)))
	_animate_end_hand_button(button)


func _set_end_hand_button_pressed(button: Control, is_pressed: bool) -> void:
	if button == null or bool(button.get_meta("disabled", false)):
		return
	button.set_meta("pressed", is_pressed)
	_set_end_hand_button_style(button, bool(button.get_meta("hovered", false)), is_pressed)
	_animate_end_hand_button(button)


func _set_end_hand_button_style(button: Control, is_hovered: bool, is_pressed: bool) -> void:
	var bg_color := Color(0.56, 0.19, 0.08)
	var border_color := Color(1.0, 0.70, 0.25)
	if is_pressed:
		bg_color = Color(0.42, 0.13, 0.06)
		border_color = Color(0.95, 0.56, 0.20)
	elif is_hovered:
		bg_color = Color(0.70, 0.25, 0.10)
		border_color = Color(1.0, 0.82, 0.42)
	var background = button.get_meta("background_panel") if button.has_meta("background_panel") else null
	if background is PanelContainer:
		background.add_theme_stylebox_override("panel", _create_end_hand_button_style(bg_color, border_color))


func _animate_end_hand_button(button: Control) -> void:
	var previous_tween = button.get_meta("animation_tween") if button.has_meta("animation_tween") else null
	if previous_tween is Tween:
		previous_tween.kill()

	var target_scale := Vector2.ONE
	if bool(button.get_meta("pressed", false)):
		target_scale = END_HAND_BUTTON_PRESSED_SCALE
	elif bool(button.get_meta("hovered", false)):
		target_scale = END_HAND_BUTTON_HOVER_SCALE

	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", target_scale, END_HAND_BUTTON_ANIMATION_SECONDS)
	button.set_meta("animation_tween", tween)


func _create_deck_stack_label(title: String, count: int, is_discard: bool) -> Label:
	var label := Label.new()
	label.custom_minimum_size = Vector2(56.0, 28.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = "%s\n%d" % [title, count]
	label.add_theme_font_size_override("font_size", 8)
	label.add_theme_color_override(
		"font_color",
		Color(0.95, 0.86, 0.62) if not is_discard else Color(0.72, 0.76, 0.82)
	)
	var stack_style := StyleBoxFlat.new()
	stack_style.bg_color = Color(0.16, 0.11, 0.06, 0.98) if not is_discard else Color(0.09, 0.10, 0.12, 0.98)
	stack_style.border_color = Color(0.86, 0.56, 0.20) if not is_discard else Color(0.44, 0.50, 0.58)
	stack_style.border_width_left = 2
	stack_style.border_width_top = 2
	stack_style.border_width_right = 2
	stack_style.border_width_bottom = 2
	stack_style.corner_radius_top_left = 4
	stack_style.corner_radius_top_right = 4
	stack_style.corner_radius_bottom_left = 4
	stack_style.corner_radius_bottom_right = 4
	stack_style.shadow_color = Color(0.02, 0.015, 0.01, 0.55)
	stack_style.shadow_size = 2
	stack_style.shadow_offset = Vector2(2.0, 2.0)
	label.add_theme_stylebox_override("normal", stack_style)
	return label


func _update_stamina_ui() -> void:
	if _stamina_bar == null or _stamina_value_label == null:
		return

	_stamina_value_label.text = "%d / %d" % [
		_skill_stamina.current,
		SKILL_STAMINA.MAX_STAMINA,
	]
	var stamina_bar_value := _get_stamina_bar_value()
	_stamina_bar.value = stamina_bar_value
	_update_hand_stamina_badge()
	_update_local_player_stamina_bar(stamina_bar_value)
	_update_end_hand_button()


func _get_stamina_bar_value() -> float:
	var recharge_fraction := _skill_stamina.recharge_progress_seconds() / SKILL_STAMINA.RECHARGE_SECONDS
	if _skill_stamina.current >= SKILL_STAMINA.MAX_STAMINA:
		recharge_fraction = 0.0
	return minf(
		float(_skill_stamina.current) + recharge_fraction,
		float(SKILL_STAMINA.MAX_STAMINA)
	)


func _create_hand_stamina_badge_style() -> StyleBoxFlat:
	var badge_style := StyleBoxFlat.new()
	_apply_hand_stamina_badge_colors(badge_style, false)
	badge_style.border_width_left = 2
	badge_style.border_width_top = 2
	badge_style.border_width_right = 2
	badge_style.border_width_bottom = 2
	badge_style.corner_radius_top_left = int(HAND_STAMINA_BADGE_SIZE * 0.5)
	badge_style.corner_radius_top_right = int(HAND_STAMINA_BADGE_SIZE * 0.5)
	badge_style.corner_radius_bottom_left = int(HAND_STAMINA_BADGE_SIZE * 0.5)
	badge_style.corner_radius_bottom_right = int(HAND_STAMINA_BADGE_SIZE * 0.5)
	badge_style.shadow_color = Color(0.02, 0.04, 0.05, 0.58)
	badge_style.shadow_size = 3
	badge_style.shadow_offset = Vector2(2.0, 3.0)
	return badge_style


func _apply_hand_stamina_badge_colors(badge_style: StyleBoxFlat, is_error: bool) -> void:
	if badge_style == null:
		return

	if is_error:
		badge_style.bg_color = Color(0.48, 0.06, 0.04, 0.98)
		badge_style.border_color = Color(1.0, 0.30, 0.22, 1.0)
	else:
		badge_style.bg_color = Color(0.08, 0.21, 0.26, 0.96)
		badge_style.border_color = Color(0.70, 0.92, 1.0, 0.96)


func _update_hand_stamina_badge() -> void:
	if _hand_stamina_badge == null or _hand_stamina_label == null:
		return

	_hand_stamina_label.text = "%d/%d" % [
		_skill_stamina.current,
		SKILL_STAMINA.MAX_STAMINA,
	]
	_hand_stamina_badge.visible = not _hand_cards.is_empty() or _is_dealing_hand
	if not _hand_stamina_badge.visible:
		return

	var hand_count := maxi(_hand_cards.size(), 1)
	var hand_step := _get_skill_card_hand_step(hand_count)
	var hand_center := (float(hand_count) - 1.0) * 0.5
	var left_card_center_offset := -hand_center * hand_step
	var target_scale := CARD_AIM_HAND_SCALE if _is_dragging_skill_card else CARD_SCREEN_SCALE
	var scaled_visual_height := CARD_SIZE.y * 0.5 * (1.0 + target_scale)
	var viewport_width := get_viewport().get_visible_rect().size.x
	var min_target_x := -viewport_width * 0.5 + CARD_SIDE_MARGIN
	var max_target_x := viewport_width * 0.5 - CARD_SIZE.x - CARD_SIDE_MARGIN
	var left_card_x := clampf(left_card_center_offset - CARD_SIZE.x * 0.5, min_target_x, max_target_x)
	var visual_left := left_card_x + CARD_SIZE.x * 0.5 * (1.0 - target_scale)
	var badge_x := visual_left - HAND_STAMINA_BADGE_SIZE - HAND_STAMINA_BADGE_GAP
	var badge_y := -scaled_visual_height - CARD_BOTTOM_MARGIN + (CARD_SIZE.y * target_scale - HAND_STAMINA_BADGE_SIZE) * 0.5

	_hand_stamina_badge.anchor_left = 0.5
	_hand_stamina_badge.anchor_top = 1.0
	_hand_stamina_badge.anchor_right = 0.5
	_hand_stamina_badge.anchor_bottom = 1.0
	_hand_stamina_badge.offset_left = badge_x
	_hand_stamina_badge.offset_top = badge_y
	_hand_stamina_badge.offset_right = badge_x + HAND_STAMINA_BADGE_SIZE
	_hand_stamina_badge.offset_bottom = badge_y + HAND_STAMINA_BADGE_SIZE


func _shake_hand_stamina_badge() -> void:
	if _hand_stamina_badge == null or not _hand_stamina_badge.visible:
		return
	if _hand_stamina_shake_tween != null and _hand_stamina_shake_tween.is_valid():
		_hand_stamina_shake_tween.kill()

	_apply_hand_stamina_badge_colors(_hand_stamina_badge_style, true)
	_hand_stamina_label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.82))
	_hand_stamina_badge.rotation_degrees = 0.0
	_hand_stamina_badge.scale = Vector2.ONE
	_hand_stamina_shake_tween = create_tween()
	_hand_stamina_shake_tween.set_trans(Tween.TRANS_SINE)
	_hand_stamina_shake_tween.set_ease(Tween.EASE_IN_OUT)
	_hand_stamina_shake_tween.tween_property(
		_hand_stamina_badge,
		"rotation_degrees",
		-HAND_STAMINA_SHAKE_ROTATION,
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.parallel().tween_property(
		_hand_stamina_badge,
		"scale",
		Vector2(1.12, 0.90),
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.tween_property(
		_hand_stamina_badge,
		"rotation_degrees",
		HAND_STAMINA_SHAKE_ROTATION,
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.parallel().tween_property(
		_hand_stamina_badge,
		"scale",
		Vector2(0.94, 1.08),
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.tween_property(
		_hand_stamina_badge,
		"rotation_degrees",
		0.0,
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.parallel().tween_property(
		_hand_stamina_badge,
		"scale",
		Vector2.ONE,
		HAND_STAMINA_SHAKE_SECONDS
	)
	_hand_stamina_shake_tween.tween_interval(
		maxf(HAND_STAMINA_ERROR_SECONDS - HAND_STAMINA_SHAKE_SECONDS * 3.0, 0.0)
	)
	_hand_stamina_shake_tween.tween_callback(_clear_hand_stamina_badge_error)


func _clear_hand_stamina_badge_error() -> void:
	_apply_hand_stamina_badge_colors(_hand_stamina_badge_style, false)
	if _hand_stamina_label != null:
		_hand_stamina_label.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0))


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
	_skill_preview_border.default_color = SKILL_PREVIEW_VALID_BORDER
	add_child(_skill_preview_border)

	_skill_preview_centerline = Line2D.new()
	_skill_preview_centerline.visible = false
	_skill_preview_centerline.z_index = 30
	_skill_preview_centerline.width = 1.4
	_skill_preview_centerline.default_color = SKILL_PREVIEW_VALID_GLYPH
	add_child(_skill_preview_centerline)

	_skill_preview_rune_marks.clear()
	for _index in range(SKILL_PREVIEW_RUNE_MARK_COUNT):
		var mark := Line2D.new()
		mark.visible = false
		mark.z_index = 30
		mark.width = 2.0
		mark.default_color = SKILL_PREVIEW_VALID_GLYPH
		_skill_preview_rune_marks.append(mark)
		add_child(mark)

	_skill_preview_label = Label.new()
	_skill_preview_label.visible = false
	_skill_preview_label.z_index = 30
	_skill_preview_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_skill_preview_label.add_theme_color_override("font_color", Color(1.0, 0.86, 0.58))
	_skill_preview_label.add_theme_font_size_override("font_size", 14)
	add_child(_skill_preview_label)

	_player_target_preview = PLAYER_TARGET_PREVIEW.new()
	_player_target_preview.setup(self, _get_player_target_floor_parent())

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

	_hand_stamina_badge = PanelContainer.new()
	_hand_stamina_badge.custom_minimum_size = Vector2(HAND_STAMINA_BADGE_SIZE, HAND_STAMINA_BADGE_SIZE)
	_hand_stamina_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_stamina_badge.pivot_offset = Vector2(HAND_STAMINA_BADGE_SIZE, HAND_STAMINA_BADGE_SIZE) * 0.5
	_hand_stamina_badge.z_index = 46
	_hand_stamina_badge.visible = false
	_hand_stamina_badge_style = _create_hand_stamina_badge_style()
	_hand_stamina_badge.add_theme_stylebox_override("panel", _hand_stamina_badge_style)
	add_child(_hand_stamina_badge)

	_hand_stamina_label = Label.new()
	_hand_stamina_label.custom_minimum_size = Vector2(HAND_STAMINA_BADGE_SIZE, HAND_STAMINA_BADGE_SIZE)
	_hand_stamina_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hand_stamina_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_hand_stamina_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hand_stamina_label.add_theme_color_override("font_color", Color(0.86, 0.97, 1.0))
	_hand_stamina_label.add_theme_color_override("font_shadow_color", Color(0.02, 0.04, 0.05, 0.85))
	_hand_stamina_label.add_theme_constant_override("shadow_offset_x", 1)
	_hand_stamina_label.add_theme_constant_override("shadow_offset_y", 1)
	_hand_stamina_label.add_theme_font_size_override("font_size", 9)
	_hand_stamina_badge.add_child(_hand_stamina_label)

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

	_card_status_label = Label.new()
	_card_status_label.anchor_left = 0.5
	_card_status_label.anchor_top = 1.0
	_card_status_label.anchor_right = 0.5
	_card_status_label.anchor_bottom = 1.0
	_card_status_label.offset_left = -150.0
	_card_status_label.offset_top = -196.0
	_card_status_label.offset_right = 150.0
	_card_status_label.offset_bottom = -172.0
	_card_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card_status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_card_status_label.visible = false
	_card_status_label.z_index = 45
	_card_status_label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.52))
	_card_status_label.add_theme_color_override("font_shadow_color", Color(0.08, 0.04, 0.02, 0.92))
	_card_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_card_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_card_status_label.add_theme_font_size_override("font_size", 14)
	add_child(_card_status_label)

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
	card.set_meta("self_target", bool(definition.get("self_target", false)))
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
	if _hand_cards.is_empty() or _is_dealing_hand or _is_local_player_dead():
		return

	if not _skill_stamina.can_spend(END_HAND_STAMINA_COST):
		if _release_hint != null:
			_release_hint.text = "Need %d stamina" % END_HAND_STAMINA_COST
			_release_hint.visible = true
		return

	if not _skill_stamina.spend(END_HAND_STAMINA_COST):
		return

	if _release_hint != null:
		_release_hint.visible = false
	_update_stamina_ui()
	_discard_hand()


func _update_deck_ui() -> void:
	if _draw_deck_label != null:
		if _skill_deck.is_shuffling:
			_draw_deck_label.text = "Draw Pile\nMix"
		elif _skill_deck.is_waiting_to_draw_after_shuffle:
			_draw_deck_label.text = "Draw Pile\n..."
		else:
			_draw_deck_label.text = "Draw Pile\n%d" % _skill_deck.draw_pile_count()
	if _discard_deck_label != null:
		_discard_deck_label.text = "Discard\n%d" % _skill_deck.discard_pile_count()
	_update_end_hand_button()
	_update_card_status_ui()


func _update_end_hand_button() -> void:
	if _end_hand_button == null:
		return

	var is_disabled := (
		_hand_cards.is_empty()
		or _is_dealing_hand
		or _is_local_player_dead()
		or not _skill_stamina.can_spend(END_HAND_STAMINA_COST)
	)
	var was_disabled := bool(_end_hand_button.get_meta("disabled", false))
	_end_hand_button.set_meta("disabled", is_disabled)
	var background = (
		_end_hand_button.get_meta("background_panel")
		if _end_hand_button.has_meta("background_panel")
		else null
	)
	if is_disabled:
		if background is PanelContainer:
			background.add_theme_stylebox_override(
				"panel",
				_create_end_hand_button_style(Color(0.16, 0.13, 0.11), Color(0.42, 0.36, 0.28))
			)
	else:
		_set_end_hand_button_style(
			_end_hand_button,
			bool(_end_hand_button.get_meta("hovered", false)),
			bool(_end_hand_button.get_meta("pressed", false))
		)
	if is_disabled and not was_disabled:
		_end_hand_button.set_meta("hovered", false)
		_end_hand_button.set_meta("pressed", false)
		_animate_end_hand_button(_end_hand_button)


func _update_card_status_ui() -> void:
	if _card_status_label == null:
		return

	var status_text := ""
	if _skill_deck.is_shuffling:
		status_text = "Shuffling deck..."
	elif _skill_deck.is_waiting_to_draw_after_shuffle:
		status_text = "Preparing cards..."
	elif _is_dealing_hand:
		status_text = "Drawing cards..."
	elif _skill_deck.draw_pile_count() == 0:
		status_text = "Deck empty"

	_card_status_label.text = status_text
	_card_status_label.visible = not status_text.is_empty()


func _create_skill_card(
	skill_name: String,
	title: String,
	cost_text: String,
	description_text: String,
	art_color: Color
) -> PanelContainer:
	var card := SKILL_CARD_SCENE.instantiate() as SkillCardView
	add_child(card)
	card.setup(skill_name, title, cost_text, description_text, art_color)
	card.gui_input.connect(_on_skill_card_gui_input.bind(card))
	card.mouse_entered.connect(_on_skill_card_mouse_entered.bind(card))
	card.mouse_exited.connect(_on_skill_card_mouse_exited.bind(card))
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
		if _requires_player_target_card(_dragged_skill_card) and _hovered_heal_target_peer_id == -1:
			_release_hint.text = "Select target"
		elif _requires_player_target_card(_dragged_skill_card) and not _hovered_skill_target_in_range:
			_release_hint.text = "Out of range"
		else:
			was_used = _request_local_skill(_dragged_skill, _hovered_heal_target_peer_id)
		if was_used:
			_skill_stamina.spend(stamina_cost)
			_update_stamina_ui()
	else:
		_release_hint.text = "Need %d stamina" % stamina_cost
		_shake_hand_stamina_badge()

	_release_hint.visible = false
	_release_hint.text = "Release to use"
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	_set_skill_preview_visible(false)
	_set_local_player_skill_aiming(false)
	var used_card := _dragged_skill_card
	_dragged_skill_card = null
	_dragged_skill = ""
	_hovered_heal_target_peer_id = -1
	_hovered_skill_target_in_range = true
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
	_hovered_skill_target_in_range = true
	_release_hint.visible = false
	_release_hint.text = "Release to use"
	_drag_line.visible = false
	_drag_arrow_head.visible = false
	_set_skill_preview_visible(false)
	_set_local_player_skill_aiming(false)
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
		_set_local_player_skill_aiming(false)
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
		_set_local_player_skill_aiming(false)
		return Vector2.INF

	var attack_range := float(card.get_meta("range", 0.0))
	var skill_type := str(card.get_meta("skill_type", "attack"))
	if _is_player_target_skill_type(skill_type) and not _is_self_target_card(card):
		_set_local_player_skill_aiming(false)
		return _update_player_target_preview(mouse_position, skill_type, attack_range)
	if attack_range <= 0.0:
		_set_skill_preview_visible(false)
		_set_local_player_skill_aiming(false)
		return Vector2.INF
	_set_local_player_skill_aiming(true)

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
	var pulse := 0.86 + sin(float(Time.get_ticks_msec()) * 0.007) * 0.14
	var fill_color := SKILL_PREVIEW_VALID_FILL
	var border_color := SKILL_PREVIEW_VALID_BORDER
	var glyph_color := SKILL_PREVIEW_VALID_GLYPH
	if not can_spend:
		fill_color = SKILL_PREVIEW_INVALID_FILL
		border_color = SKILL_PREVIEW_INVALID_BORDER
		glyph_color = SKILL_PREVIEW_INVALID_GLYPH

	var forward := direction
	var side := Vector2(-forward.y, forward.x) * (SKILL_PREVIEW_WIDTH * 0.5)
	var segment_count := _skill_preview_rects.size()
	for index in range(segment_count):
		var start_fraction := float(index) / float(segment_count)
		var end_fraction := float(index + 1) / float(segment_count)
		var segment_start := preview_start.lerp(center, start_fraction)
		var segment_end := preview_start.lerp(center, end_fraction)
		var segment_side := side
		if index == segment_count - 1:
			segment_side *= 0.34
		var segment_color := fill_color
		segment_color.a *= float(SKILL_PREVIEW_OPACITY_STEPS[index]) * pulse
		_skill_preview_rects[index].color = segment_color
		_skill_preview_rects[index].polygon = PackedVector2Array([
			segment_start - side,
			segment_end - segment_side,
			segment_end + segment_side,
			segment_start + side,
		])
		_skill_preview_rects[index].visible = true
	var border_points := PackedVector2Array([
		preview_start - side,
		center - side * 0.34,
		center,
		center + side * 0.34,
		preview_start + side,
		preview_start - side,
	])

	border_color.a *= 0.62 + pulse * 0.12
	_skill_preview_border.default_color = border_color
	_skill_preview_border.points = border_points
	_skill_preview_border.width = 2.0
	_update_skillshot_preview_glyphs(preview_start, center, forward, side, glyph_color, pulse)
	_set_skill_preview_visible(true)
	_skill_preview_label.visible = false
	_hide_player_target_preview()
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
	var pulse := 0.86 + sin(float(Time.get_ticks_msec()) * 0.007) * 0.14
	var fill_color := Color(
		SKILL_PREVIEW_VALID_FILL.r,
		SKILL_PREVIEW_VALID_FILL.g,
		SKILL_PREVIEW_VALID_FILL.b,
		0.30 * pulse
	)
	var border_color := SKILL_PREVIEW_VALID_BORDER
	var glyph_color := SKILL_PREVIEW_VALID_GLYPH
	if not can_spend:
		fill_color = SKILL_PREVIEW_INVALID_FILL
		border_color = SKILL_PREVIEW_INVALID_BORDER
		glyph_color = SKILL_PREVIEW_INVALID_GLYPH

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

	border_color.a *= 0.62 + pulse * 0.12
	_skill_preview_border.default_color = border_color
	_skill_preview_border.points = border_points
	_skill_preview_border.width = 2.0
	_skill_preview_border.visible = true
	_update_strike_preview_glyphs(center, screen_range, direction, start_angle, end_angle, glyph_color, pulse)
	_skill_preview_label.visible = false
	_hide_player_target_preview()
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


func _update_skillshot_preview_glyphs(
	start: Vector2,
	end: Vector2,
	forward: Vector2,
	side: Vector2,
	color: Color,
	pulse: float
) -> void:
	if _skill_preview_centerline != null:
		var line_color := color
		line_color.a *= 0.72 + pulse * 0.18
		_skill_preview_centerline.default_color = line_color
		_skill_preview_centerline.width = 1.4
		_skill_preview_centerline.points = PackedVector2Array([start, end])
		_skill_preview_centerline.visible = true

	var side_direction := side.normalized()
	var lane_length := start.distance_to(end)
	for index in range(_skill_preview_rune_marks.size()):
		var fraction := float(index + 1) / float(_skill_preview_rune_marks.size() + 1)
		var center := start.lerp(end, fraction)
		var short_side := side_direction * (SKILL_PREVIEW_WIDTH * 0.24)
		var long_side := side_direction * (SKILL_PREVIEW_WIDTH * 0.42)
		var notch := forward * minf(10.0, lane_length * 0.04)
		var mark := _skill_preview_rune_marks[index]
		var mark_color := color
		mark_color.a *= 0.54 + (0.22 * pulse)
		mark.default_color = mark_color
		mark.width = 2.0
		if index % 2 == 0:
			mark.points = PackedVector2Array([center - long_side, center - short_side + notch])
		else:
			mark.points = PackedVector2Array([center + short_side + notch, center + long_side])
		mark.visible = true


func _update_strike_preview_glyphs(
	center: Vector2,
	radius: float,
	direction: Vector2,
	start_angle: float,
	end_angle: float,
	color: Color,
	pulse: float
) -> void:
	if _skill_preview_centerline != null:
		var line_color := color
		line_color.a *= 0.66 + pulse * 0.16
		_skill_preview_centerline.default_color = line_color
		_skill_preview_centerline.width = 1.4
		_skill_preview_centerline.points = PackedVector2Array([center, center + direction * radius])
		_skill_preview_centerline.visible = true

	for index in range(_skill_preview_rune_marks.size()):
		var fraction := float(index + 1) / float(_skill_preview_rune_marks.size() + 1)
		var angle := lerpf(start_angle, end_angle, fraction)
		var radial := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-radial.y, radial.x)
		var outer := center + radial * radius
		var inner := center + radial * (radius - 16.0)
		var mark := _skill_preview_rune_marks[index]
		var mark_color := color
		mark_color.a *= 0.50 + (0.24 * pulse)
		mark.default_color = mark_color
		mark.width = 2.0
		if index % 3 == 0:
			mark.points = PackedVector2Array([inner, outer])
		else:
			mark.points = PackedVector2Array([outer - tangent * 7.0, outer + tangent * 7.0])
		mark.visible = true


func _set_skill_preview_visible(is_visible: bool) -> void:
	for preview_rect in _skill_preview_rects:
		preview_rect.visible = is_visible
	if _skill_preview_border != null:
		_skill_preview_border.visible = is_visible
	if _skill_preview_centerline != null:
		_skill_preview_centerline.visible = is_visible
	for mark in _skill_preview_rune_marks:
		mark.visible = is_visible
	if _skill_preview_label != null:
		_skill_preview_label.visible = is_visible
	if not is_visible:
		_hide_player_target_preview()


func _update_player_target_preview(
	mouse_position: Vector2,
	skill_type: String,
	cast_range: float
) -> Vector2:
	for preview_rect in _skill_preview_rects:
		preview_rect.visible = false
	_skill_preview_border.visible = false
	if _skill_preview_centerline != null:
		_skill_preview_centerline.visible = false
	for mark in _skill_preview_rune_marks:
		mark.visible = false
	_skill_preview_label.visible = false
	_player_target_preview.update_cursor(mouse_position, skill_type)

	var target := _find_skill_target_at_screen_position(mouse_position, skill_type)
	if target == null:
		_hovered_heal_target_peer_id = -1
		_hovered_skill_target_in_range = true
		_player_target_preview.hide_floor()
		return mouse_position

	_hovered_heal_target_peer_id = _get_skill_target_id(target)
	_hovered_skill_target_in_range = true
	if cast_range > 0.0:
		var local_player := _get_local_player_node()
		if local_player != null:
			_hovered_skill_target_in_range = (
				local_player.global_position.distance_to(target.global_position) <= cast_range
			)
	var center := _get_player_floor_target_world_center(target)
	_player_target_preview.update_floor(center, skill_type)
	return _get_player_floor_target_center(target)


func _hide_player_target_preview() -> void:
	if _player_target_preview != null:
		_player_target_preview.hide_all()


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
	var hand_step := _get_skill_card_hand_step(hand_count)
	for index in range(hand_count):
		var card := _hand_cards[index]

		var card_index := float(index)
		var hand_center := (float(hand_count) - 1.0) * 0.5
		var center_offset: float = (card_index - hand_center) * hand_step
		var distance_from_center: float = absf(card_index - hand_center)
		var rise: float = -CARD_HAND_RISE * (1.0 - minf(distance_from_center, 1.0))
		var rotation: float = clampf(card_index - hand_center, -2.0, 2.0) * 4.0
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
	_update_hand_stamina_badge()


func _get_skill_card_hand_step(hand_count: int) -> float:
	if hand_count <= 1:
		return 0.0

	var viewport_width := get_viewport().get_visible_rect().size.x
	var outer_card_index_offset := (float(hand_count) - 1.0) * 0.5
	var card_half_width := CARD_SIZE.x * 0.5
	var max_center_offset := maxf(viewport_width * 0.5 - card_half_width - CARD_SIDE_MARGIN, 0.0)
	return minf(CARD_HAND_STEP, max_center_offset / outer_card_index_offset)


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

	var target_scale := Vector2(CARD_SCREEN_SCALE, CARD_SCREEN_SCALE)
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
	var scaled_visual_height := CARD_SIZE.y * 0.5 * (1.0 + target_scale.y)
	var viewport_width := get_viewport().get_visible_rect().size.x
	var min_target_x := -viewport_width * 0.5 + CARD_SIDE_MARGIN
	var max_target_x := viewport_width * 0.5 - CARD_SIZE.x - CARD_SIDE_MARGIN
	var target_x := clampf(offset_x - CARD_SIZE.x * 0.5, min_target_x, max_target_x)
	var target_position := Vector2(
		target_x,
		-scaled_visual_height - CARD_BOTTOM_MARGIN + offset_y
	)
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


func _set_local_player_skill_aiming(is_active: bool) -> void:
	var player := _get_local_player_node()
	if player != null and player.has_method("set_skill_aiming_active"):
		player.call("set_skill_aiming_active", is_active)


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
		if player == null or player == _get_player_target_floor_root():
			continue
		var health = player.get("_health")
		if (health is int or health is float) and int(health) <= 0:
			continue

		var center := _get_player_floor_target_center(player)
		var ellipse_delta := screen_position - center
		var ellipse_radius_x := PLAYER_TARGET_PREVIEW.FLOOR_RADIUS
		var ellipse_radius_y := PLAYER_TARGET_PREVIEW.FLOOR_RADIUS * PLAYER_TARGET_PREVIEW.FLOOR_Y_SCALE
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


func _find_skill_target_at_screen_position(screen_position: Vector2, skill_type: String) -> Node2D:
	if skill_type != "debuff":
		return _find_player_at_screen_position(screen_position)

	var world := get_parent()
	if world == null:
		return null

	var local_player := _get_local_player_node()
	var best_target: Node2D = null
	var best_distance_squared := INF
	var target_parents: Array[Node] = []
	var players := world.get_node_or_null("Players")
	var enemies := world.get_node_or_null("Enemies")
	if players != null:
		target_parents.append(players)
	if enemies != null:
		target_parents.append(enemies)

	for parent in target_parents:
		for node in parent.get_children():
			var target := node as Node2D
			if target == null or target == local_player or target == _get_player_target_floor_root():
				continue
			if not target.is_in_group("damageable"):
				continue
			var health = target.get("_health")
			if (health is int or health is float) and int(health) <= 0:
				continue

			var center := _get_player_floor_target_center(target)
			var ellipse_delta := screen_position - center
			var ellipse_radius_x := PLAYER_TARGET_PREVIEW.FLOOR_RADIUS
			var ellipse_radius_y := PLAYER_TARGET_PREVIEW.FLOOR_RADIUS * PLAYER_TARGET_PREVIEW.FLOOR_Y_SCALE
			var ellipse_distance_squared := (
				(ellipse_delta.x * ellipse_delta.x) / (ellipse_radius_x * ellipse_radius_x)
				+ (ellipse_delta.y * ellipse_delta.y) / (ellipse_radius_y * ellipse_radius_y)
			)
			var distance_squared := center.distance_squared_to(screen_position)
			var body_center := target.get_global_transform_with_canvas().origin
			var body_rect := Rect2(body_center - PLAYER_TARGET_BODY_RECT * 0.5, PLAYER_TARGET_BODY_RECT)
			var is_over_floor_ellipse := ellipse_distance_squared <= 1.0
			if not is_over_floor_ellipse and not body_rect.has_point(screen_position):
				continue

			if distance_squared < best_distance_squared:
				best_distance_squared = distance_squared
				best_target = target

	return best_target


func _get_skill_target_id(target: Node2D) -> int:
	if target == null:
		return -1

	var parent := target.get_parent()
	if parent == null:
		return -1
	if parent.name == "Enemies":
		return -target.get_index() - 2

	var peer_id = target.get("peer_id")
	return int(peer_id) if peer_id is int or peer_id is float else -1


func _get_player_floor_target_center(player: Node2D) -> Vector2:
	return player.get_global_transform_with_canvas() * PLAYER_TARGET_PREVIEW.FLOOR_OFFSET


func _get_player_floor_target_world_center(player: Node2D) -> Vector2:
	return player.global_position + PLAYER_TARGET_PREVIEW.FLOOR_OFFSET


func _get_player_target_floor_parent() -> Node:
	var world := get_parent()
	if world == null:
		return null

	return world.get_node_or_null("Players")


func _get_player_target_floor_root() -> Node2D:
	if _player_target_preview == null:
		return null

	return _player_target_preview.get_floor_root()


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
			if player == null or player == local_player or player == _get_player_target_floor_root():
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


func _is_local_player_dead() -> bool:
	var player := _get_local_player_node()
	if player == null:
		return false

	var is_dead = player.get("_is_dead")
	if is_dead is bool:
		return is_dead

	var health = player.get("_health")
	return (health is int or health is float) and int(health) <= 0


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


func _requires_player_target_card(card: PanelContainer) -> bool:
	if card == null:
		return false

	if _is_self_target_card(card):
		return false
	return _is_player_target_skill_type(str(card.get_meta("skill_type", "attack")))


func _is_self_target_card(card: PanelContainer) -> bool:
	return card != null and bool(card.get_meta("self_target", false))


func _is_player_target_skill_type(skill_type: String) -> bool:
	return skill_type == "heal" or skill_type == "buff" or skill_type == "debuff"
