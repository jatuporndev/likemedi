extends CanvasLayer

var _chat_log: RichTextLabel
var _chat_input: LineEdit
var _host_label: Label
var _room_code := ""


func _ready() -> void:
	NetworkManager.chat_message_received.connect(_on_chat_message)
	_build_ui()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		NetworkManager.leave_game()


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
	chat_panel.offset_top = -238
	chat_panel.offset_right = 372
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
	_chat_log.custom_minimum_size = Vector2(0, 150)
	_chat_log.fit_content = false
	_chat_log.scroll_following = true
	chat_layout.add_child(_chat_log)

	_chat_input = LineEdit.new()
	_chat_input.placeholder_text = "Chat"
	_chat_input.text_submitted.connect(_submit_chat)
	chat_layout.add_child(_chat_input)

	var status_panel := PanelContainer.new()
	status_panel.anchor_left = 1.0
	status_panel.anchor_top = 1.0
	status_panel.anchor_right = 1.0
	status_panel.anchor_bottom = 1.0
	status_panel.offset_left = -232
	status_panel.offset_top = -112
	status_panel.offset_right = -12
	status_panel.offset_bottom = -12
	add_child(status_panel)

	var status_margin := MarginContainer.new()
	status_margin.add_theme_constant_override("margin_left", 12)
	status_margin.add_theme_constant_override("margin_right", 12)
	status_margin.add_theme_constant_override("margin_top", 10)
	status_margin.add_theme_constant_override("margin_bottom", 10)
	status_panel.add_child(status_margin)

	var status_text := Label.new()
	status_text.text = "HP 100 / 100\nAttack: Right click\nMove: WASD or arrows"
	status_margin.add_child(status_text)


func _submit_chat(message: String) -> void:
	NetworkManager.submit_chat_message(message)
	_chat_input.clear()


func _on_chat_message(sender_id: int, message: String) -> void:
	var sender_name := str(NetworkManager.player_names.get(sender_id, "Player %d" % sender_id))
	_chat_log.append_text("[b]%s:[/b] %s\n" % [sender_name, message])


func _copy_room_code() -> void:
	DisplayServer.clipboard_set(_room_code)
	_host_label.text = "Room %s copied (%s)" % [
		_room_code,
		NetworkManager.get_transport_mode().to_upper(),
	]
