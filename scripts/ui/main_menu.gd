extends Control

var _name_edit: LineEdit
var _ip_edit: LineEdit
var _status_label: Label
var _transport_select: OptionButton


func _ready() -> void:
	NetworkManager.connection_failed.connect(_show_error)
	_build_ui()


func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.08, 0.09, 0.08)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(420, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -210
	panel.offset_top = -230
	panel.offset_right = 210
	panel.offset_bottom = 230
	add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 12)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "Like Medieval"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	layout.add_child(title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Character name"
	_name_edit.text = "Player"
	layout.add_child(_name_edit)

	_transport_select = OptionButton.new()
	_transport_select.add_item("Direct IP / LAN", 0)
	_transport_select.add_item("EOS P2P", 1)
	_transport_select.item_selected.connect(_on_transport_selected)
	_transport_select.select(1 if NetworkManager.get_transport_mode() == "eos" else 0)
	layout.add_child(_transport_select)

	var host_button := Button.new()
	host_button.text = "Host Game"
	host_button.pressed.connect(_on_host_pressed)
	layout.add_child(host_button)

	_ip_edit = LineEdit.new()
	_ip_edit.placeholder_text = "Room code or host IP"
	_ip_edit.text = "127.0.0.1"
	layout.add_child(_ip_edit)
	_apply_transport_input_hint()

	var join_button := Button.new()
	join_button.text = "Join Game"
	join_button.pressed.connect(_on_join_pressed)
	layout.add_child(join_button)

	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.disabled = true
	layout.add_child(settings_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(NetworkManager.quit_game)
	layout.add_child(quit_button)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.text = NetworkManager.last_error
	layout.add_child(_status_label)


func _on_host_pressed() -> void:
	_status_label.text = "Starting host..."
	NetworkManager.host_game(_name_edit.text.strip_edges())


func _on_join_pressed() -> void:
	_status_label.text = "Connecting..."
	NetworkManager.join_game(_ip_edit.text, _name_edit.text.strip_edges())


func _show_error(message: String) -> void:
	_status_label.text = message


func _on_transport_selected(index: int) -> void:
	if index == 1:
		NetworkManager.set_transport_mode("eos")
	else:
		NetworkManager.set_transport_mode("enet")
	_apply_transport_input_hint()


func _apply_transport_input_hint() -> void:
	if NetworkManager.get_transport_mode() == "eos":
		_ip_edit.text = ""
		_ip_edit.placeholder_text = "EOS room code"
	else:
		_ip_edit.text = "127.0.0.1"
		_ip_edit.placeholder_text = "Host IP address"
