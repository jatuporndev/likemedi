extends Control

const INTRO_BACKGROUND_PATH := "res://assets/menu/click_to_begin_background.png"

const COLOR_INK := Color(0.045, 0.032, 0.024, 1.0)
const COLOR_PANEL := Color(0.075, 0.055, 0.038, 0.96)
const COLOR_PANEL_SOFT := Color(0.12, 0.085, 0.052, 0.88)
const COLOR_GOLD := Color(0.82, 0.55, 0.22, 1.0)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.78, 0.34, 1.0)
const COLOR_TEXT := Color(0.94, 0.86, 0.68, 1.0)
const COLOR_MUTED_TEXT := Color(0.67, 0.56, 0.38, 1.0)
const COLOR_RED := Color(0.55, 0.14, 0.09, 1.0)
const COLOR_FOREST := Color(0.08, 0.14, 0.08, 1.0)
const COLOR_STONE := Color(0.19, 0.18, 0.16, 1.0)

var _name_edit: LineEdit
var _eos_code_edit: LineEdit
var _world_name_edit: LineEdit
var _private_world_check: CheckButton
var _world_visibility_label: Label
var _world_visibility_hint: Label
var _status_label: Label
var _world_list: VBoxContainer
var _player_name_label: Label
var _intro_layer: Control
var _menu_background: Control
var _menu_panel: PanelContainer
var _player_name := "Player"
var _menu_visible := false


func _ready() -> void:
	NetworkManager.connection_failed.connect(_show_error)
	NetworkManager.world_registry_failed.connect(_show_error)
	NetworkManager.firebase_auth_changed.connect(_on_firebase_auth_changed)
	NetworkManager.firebase_auth_failed.connect(_show_error)
	_apply_firebase_player_name()
	_build_intro()


func _input(event: InputEvent) -> void:
	if _menu_visible:
		return

	if event is InputEventMouseButton and event.pressed:
		_show_main_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventKey and event.pressed and not event.echo:
		_show_main_menu()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch and event.pressed:
		_show_main_menu()
		get_viewport().set_input_as_handled()


func _build_intro() -> void:
	_intro_layer = Control.new()
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_intro_layer)

	_add_intro_background()

	var veil := ColorRect.new()
	veil.color = Color(0.015, 0.011, 0.008, 0.24)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(veil)

	var title_stack := VBoxContainer.new()
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.anchor_left = 0.0
	title_stack.anchor_top = 0.0
	title_stack.anchor_right = 1.0
	title_stack.anchor_bottom = 0.0
	title_stack.offset_top = 78
	title_stack.offset_bottom = 230
	title_stack.add_theme_constant_override("separation", 8)
	_intro_layer.add_child(title_stack)

	var title := _create_title_label("LIKE MEDIEVAL", 58)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.02, 0.012, 0.006, 0.96))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title_stack.add_child(title)

	var subtitle := _create_label("cards, steel, and old forest roads", 18, COLOR_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_stack.add_child(subtitle)

	var prompt := Label.new()
	prompt.text = "CLICK TO ENTER THE KEEP"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 34)
	prompt.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	prompt.add_theme_color_override("font_shadow_color", Color(0.02, 0.012, 0.006, 0.95))
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	prompt.anchor_left = 0.0
	prompt.anchor_top = 1.0
	prompt.anchor_right = 1.0
	prompt.anchor_bottom = 1.0
	prompt.offset_top = -110
	prompt.offset_bottom = -50
	_intro_layer.add_child(prompt)

	var blink := create_tween()
	blink.set_loops()
	blink.tween_property(prompt, "modulate:a", 0.2, 0.55)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.55)


func _add_intro_background() -> void:
	if ResourceLoader.exists(INTRO_BACKGROUND_PATH):
		var background := TextureRect.new()
		background.texture = load(INTRO_BACKGROUND_PATH)
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		background.set_anchors_preset(Control.PRESET_FULL_RECT)
		_intro_layer.add_child(background)
		return

	var fallback := ColorRect.new()
	fallback.color = Color(0.035, 0.055, 0.036)
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(fallback)

	_add_menu_backdrop(_intro_layer)


func _show_main_menu() -> void:
	_menu_visible = true
	if _intro_layer != null:
		_intro_layer.queue_free()
		_intro_layer = null
	_ensure_menu_background()
	_build_main_menu()


func _ensure_menu_background() -> void:
	if _menu_background != null:
		return

	_menu_background = Control.new()
	_menu_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_menu_background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_menu_background)
	_add_menu_backdrop(_menu_background)


func _clear_menu_panel() -> void:
	if _menu_panel != null:
		_menu_panel.queue_free()
		_menu_panel = null


func _build_main_menu() -> void:
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(430, 430), Vector2(-215, -215), Vector2(215, 215))
	var layout := _create_panel_layout(panel, 18)

	var menu_column := VBoxContainer.new()
	menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_column.add_theme_constant_override("separation", 12)
	layout.add_child(menu_column)

	var title := _create_title_label("Like Medieval", 32)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	menu_column.add_child(title)

	var subtitle := _create_label("Choose your path.", 13, COLOR_MUTED_TEXT)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(subtitle)

	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 8)
	menu_column.add_child(player_row)

	_player_name_label = _create_label("Playing as %s" % _player_name, 14, COLOR_TEXT)
	_player_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_player_name_label.clip_text = true
	_player_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	player_row.add_child(_player_name_label)

	var rename_button := Button.new()
	rename_button.text = "Rename"
	rename_button.custom_minimum_size = Vector2(92, 34)
	rename_button.pressed.connect(_build_rename_player_menu)
	_style_button(rename_button)
	player_row.add_child(rename_button)

	var start_button := Button.new()
	start_button.text = "Solo Expedition"
	start_button.custom_minimum_size = Vector2(0, 42)
	start_button.pressed.connect(_on_lan_start_pressed)
	_style_button(start_button, true)
	menu_column.add_child(start_button)

	var p2p_button := Button.new()
	p2p_button.text = "World Ledger"
	p2p_button.custom_minimum_size = Vector2(0, 38)
	p2p_button.pressed.connect(_build_p2p_menu)
	_style_button(p2p_button)
	menu_column.add_child(p2p_button)

	var settings_button := Button.new()
	settings_button.text = "Settings"
	settings_button.disabled = true
	_style_button(settings_button)
	menu_column.add_child(settings_button)

	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(NetworkManager.quit_game)
	_style_button(quit_button)
	menu_column.add_child(quit_button)

	_status_label = _create_status_label()
	layout.add_child(_status_label)

	_play_menu_intro_animation()


func _build_rename_player_menu() -> void:
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(430, 330), Vector2(-215, -165), Vector2(215, 165))
	var layout := _create_panel_layout(panel, 14)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_build_main_menu)
	_style_button(back_button)
	header.add_child(back_button)

	var title := _create_title_label("Rename Player", 26)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var player_id: String = NetworkManager.get_firebase_player_id()
	var id_text: String = "Player ID: %s" % player_id if not player_id.is_empty() else "Player ID: signing in..."
	var id_label := _create_label(id_text, 11, COLOR_MUTED_TEXT)
	id_label.clip_text = true
	id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(id_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Player name"
	_name_edit.text = _player_name
	_name_edit.text_submitted.connect(_on_rename_player_submitted)
	_style_line_edit(_name_edit)
	layout.add_child(_name_edit)

	var save_button := Button.new()
	save_button.text = "Save Name"
	save_button.custom_minimum_size = Vector2(0, 42)
	save_button.pressed.connect(_on_save_player_name_pressed)
	_style_button(save_button, true)
	layout.add_child(save_button)

	_status_label = _create_status_label()
	layout.add_child(_status_label)

	_play_menu_intro_animation()


func _build_p2p_menu() -> void:
	_remember_player_name()
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(1160, 620), Vector2(-580, -310), Vector2(580, 310))
	var root := _create_panel_layout(panel, 12)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var back_button := Button.new()
	back_button.text = "Back"
	back_button.pressed.connect(_build_main_menu)
	_style_button(back_button)
	header.add_child(back_button)

	var title := _create_title_label("World Ledger", 28)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "Refresh"
	refresh_button.pressed.connect(_refresh_world_list)
	_style_button(refresh_button)
	header.add_child(refresh_button)

	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	var create_panel := PanelContainer.new()
	create_panel.custom_minimum_size = Vector2(320, 0)
	create_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL_SOFT, COLOR_GOLD, 2, 7))
	columns.add_child(create_panel)

	var create_layout := _create_panel_layout(create_panel, 10)

	var create_title := _create_title_label("Raise A Banner", 20)
	create_title.add_theme_color_override("font_color", COLOR_TEXT)
	create_layout.add_child(create_title)

	_world_name_edit = LineEdit.new()
	_world_name_edit.placeholder_text = "World name"
	_world_name_edit.text = "New World"
	_style_line_edit(_world_name_edit)
	create_layout.add_child(_world_name_edit)

	create_layout.add_child(_create_world_visibility_control())

	var create_button := Button.new()
	create_button.text = "Create World"
	create_button.pressed.connect(_on_create_p2p_world_pressed)
	_style_button(create_button, true)
	create_layout.add_child(create_button)

	var separator := HSeparator.new()
	create_layout.add_child(separator)

	var code_title := _create_title_label("Join By Seal Code", 18)
	code_title.add_theme_color_override("font_color", COLOR_TEXT)
	create_layout.add_child(code_title)

	_eos_code_edit = LineEdit.new()
	_eos_code_edit.placeholder_text = "EOS room code"
	_style_line_edit(_eos_code_edit)
	create_layout.add_child(_eos_code_edit)

	var join_code_button := Button.new()
	join_code_button.text = "Join Code"
	join_code_button.pressed.connect(_on_join_eos_code_pressed)
	_style_button(join_code_button)
	create_layout.add_child(join_code_button)

	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(720, 0)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL_SOFT, COLOR_GOLD, 2, 7))
	columns.add_child(list_panel)

	var list_margin := MarginContainer.new()
	list_margin.add_theme_constant_override("margin_left", 12)
	list_margin.add_theme_constant_override("margin_top", 12)
	list_margin.add_theme_constant_override("margin_right", 12)
	list_margin.add_theme_constant_override("margin_bottom", 12)
	list_panel.add_child(list_margin)

	var list_layout := VBoxContainer.new()
	list_layout.add_theme_constant_override("separation", 8)
	list_margin.add_child(list_layout)

	var list_title := _create_title_label("Open Realms", 20)
	list_title.add_theme_color_override("font_color", COLOR_TEXT)
	list_layout.add_child(list_title)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_layout.add_child(scroll)

	_world_list = VBoxContainer.new()
	_world_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_world_list)

	_status_label = _create_status_label()
	root.add_child(_status_label)

	_play_menu_intro_animation()
	_refresh_world_list()


func _create_center_panel(min_size: Vector2, top_left: Vector2, bottom_right: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	_menu_panel = panel
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _create_panel_style(COLOR_PANEL, COLOR_GOLD, 3, 8))
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = top_left.x
	panel.offset_top = top_left.y
	panel.offset_right = bottom_right.x
	panel.offset_bottom = bottom_right.y
	panel.modulate.a = 0.0
	panel.scale = Vector2(1.08, 1.08)
	add_child(panel)
	return panel


func _create_panel_layout(panel: PanelContainer, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", separation)
	margin.add_child(layout)
	return layout


func _create_title_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	return label


func _create_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.02, 0.015, 0.01, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	return label


func _create_status_label() -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = NetworkManager.last_error
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	return label


func _play_menu_intro_animation() -> void:
	await get_tree().process_frame
	if _menu_panel == null:
		return

	_menu_panel.pivot_offset = _menu_panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_panel, "scale", Vector2.ONE, 0.35)
	tween.tween_property(_menu_panel, "modulate:a", 1.0, 0.25)


func _on_lan_start_pressed() -> void:
	_status_label.text = "Starting game..."
	NetworkManager.set_transport_mode("enet")
	NetworkManager.host_game(_get_player_name())


func _on_create_p2p_world_pressed() -> void:
	_status_label.text = "Creating EOS world..."
	NetworkManager.set_transport_mode("eos")
	NetworkManager.host_game(
		_get_player_name(),
		_world_name_edit.text.strip_edges(),
		not _private_world_check.button_pressed
	)


func _on_join_eos_code_pressed() -> void:
	_status_label.text = "Joining EOS world..."
	NetworkManager.set_transport_mode("eos")
	NetworkManager.join_game(_eos_code_edit.text, _get_player_name())


func _refresh_world_list() -> void:
	if _world_list == null:
		return

	for child in _world_list.get_children():
		child.queue_free()

	var loading := Label.new()
	loading.text = "Sending riders for the realm list..."
	loading.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	_world_list.add_child(loading)

	var worlds := await NetworkManager.fetch_public_worlds()
	if _world_list == null:
		return

	for child in _world_list.get_children():
		child.queue_free()

	var visible_worlds: Array[Dictionary] = []
	for world in worlds:
		if _get_world_player_count(world) > 0:
			visible_worlds.append(world)

	if visible_worlds.is_empty():
		var empty := Label.new()
		empty.text = "No open realms found."
		empty.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
		_world_list.add_child(empty)
		return

	for world in visible_worlds:
		_world_list.add_child(_create_world_row(world))


func _create_world_row(world: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 68)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_stylebox_override("panel", _create_panel_style(Color(0.055, 0.043, 0.032, 0.92), Color(0.39, 0.25, 0.11, 0.95), 1, 5))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 3)
	layout.add_child(details)

	var world_name := Label.new()
	world_name.text = _get_world_name(world)
	world_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	world_name.clip_text = true
	world_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	world_name.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	world_name.add_theme_font_size_override("font_size", 16)
	world_name.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	details.add_child(world_name)

	var meta := Label.new()
	meta.text = "%s - %s" % [_format_player_count(world), _format_updated_at(world)]
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	details.add_child(meta)

	var join_button := Button.new()
	join_button.text = "Join"
	join_button.custom_minimum_size = Vector2(76, 34)
	join_button.pressed.connect(_join_world.bind(world))
	_style_button(join_button, true)
	layout.add_child(join_button)

	return row


func _create_world_visibility_control() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 82)
	panel.add_theme_stylebox_override(
		"panel",
		_create_panel_style(Color(0.045, 0.035, 0.026, 0.86), Color(0.38, 0.25, 0.12, 0.95), 1, 5)
	)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	layout.add_child(row)

	_world_visibility_label = _create_label("", 13, COLOR_TEXT)
	_world_visibility_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_world_visibility_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_world_visibility_label)

	_private_world_check = CheckButton.new()
	_private_world_check.text = "Private"
	_private_world_check.focus_mode = Control.FOCUS_NONE
	_private_world_check.add_theme_color_override("font_color", COLOR_TEXT)
	_private_world_check.add_theme_color_override("font_hover_color", COLOR_GOLD_BRIGHT)
	_private_world_check.toggled.connect(_on_private_world_toggled)
	row.add_child(_private_world_check)

	_world_visibility_hint = _create_label("", 11, COLOR_MUTED_TEXT)
	_world_visibility_hint.clip_text = true
	_world_visibility_hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(_world_visibility_hint)

	_update_world_visibility_copy()
	return panel


func _add_menu_backdrop(parent: Control) -> void:
	var sky := ColorRect.new()
	sky.color = Color(0.055, 0.073, 0.052, 1.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(sky)

	var forest := Control.new()
	forest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forest.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(forest)

	_add_hill(forest, Color(0.055, 0.105, 0.055, 1.0), 0.62, 110.0)
	_add_hill(forest, Color(0.037, 0.073, 0.04, 1.0), 0.73, 145.0)
	_add_keep_silhouette(forest)
	_add_ground_band(forest)


func _add_hill(parent: Control, color: Color, y_fraction: float, height: float) -> void:
	var hill := Polygon2D.new()
	hill.color = color
	hill.polygon = PackedVector2Array([
		Vector2(-80, 720),
		Vector2(-80, 720 * y_fraction),
		Vector2(170, 720 * y_fraction - height * 0.35),
		Vector2(410, 720 * y_fraction + height * 0.08),
		Vector2(700, 720 * y_fraction - height * 0.55),
		Vector2(1010, 720 * y_fraction + height * 0.04),
		Vector2(1360, 720 * y_fraction - height * 0.22),
		Vector2(1360, 720),
	])
	parent.add_child(hill)


func _add_keep_silhouette(parent: Control) -> void:
	var keep_color := Color(0.12, 0.115, 0.095, 1.0)
	_add_rect(parent, Rect2(860, 226, 280, 260), keep_color)
	_add_rect(parent, Rect2(812, 278, 76, 208), keep_color)
	_add_rect(parent, Rect2(1112, 268, 84, 218), keep_color)
	_add_rect(parent, Rect2(846, 206, 34, 36), keep_color)
	_add_rect(parent, Rect2(928, 190, 42, 50), keep_color)
	_add_rect(parent, Rect2(1042, 194, 42, 46), keep_color)
	_add_rect(parent, Rect2(1144, 198, 34, 42), keep_color)
	_add_rect(parent, Rect2(977, 352, 48, 134), Color(0.04, 0.032, 0.024, 1.0))


func _add_ground_band(parent: Control) -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.055, 0.042, 0.029, 1.0)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.anchor_left = 0.0
	ground.anchor_top = 1.0
	ground.anchor_right = 1.0
	ground.anchor_bottom = 1.0
	ground.offset_top = -170
	parent.add_child(ground)


func _add_rect(parent: Control, rect: Rect2, color: Color) -> void:
	var block := ColorRect.new()
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.position = rect.position
	block.size = rect.size
	parent.add_child(block)


func _style_button(button: Button, is_primary: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(is_primary, false, false))
	button.add_theme_stylebox_override("hover", _create_button_style(is_primary, true, false))
	button.add_theme_stylebox_override("pressed", _create_button_style(is_primary, true, true))
	button.add_theme_stylebox_override("disabled", _create_button_style(false, false, false, true))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD_BRIGHT)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.42, 0.36, 0.28, 1.0))
	button.add_theme_font_size_override("font_size", 15)


func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override("normal", _create_input_style(false))
	line_edit.add_theme_stylebox_override("focus", _create_input_style(true))
	line_edit.add_theme_color_override("font_color", COLOR_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", COLOR_MUTED_TEXT)
	line_edit.add_theme_color_override("caret_color", COLOR_GOLD_BRIGHT)
	line_edit.add_theme_font_size_override("font_size", 14)


func _create_panel_style(bg_color: Color, border_color: Color, border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


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


func _join_world(world: Dictionary) -> void:
	var eos_code := _get_world_code(world)
	if eos_code.is_empty():
		_show_error("World is missing an EOS room code.")
		return

	_status_label.text = "Joining %s..." % str(world.get("world_name", "world"))
	NetworkManager.set_transport_mode("eos")
	NetworkManager.join_game(eos_code, _get_player_name())


func _get_world_code(world: Dictionary) -> String:
	for key in ["eos_room_code", "room_code", "code", "lobby_id"]:
		var value := str(world.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return ""


func _get_world_name(world: Dictionary) -> String:
	for key in ["world_name", "worldName", "name", "lobby_name", "session_name"]:
		var value := str(world.get(key, "")).strip_edges()
		if not value.is_empty():
			return value
	return "Unnamed World"


func _format_player_count(world: Dictionary) -> String:
	var player_count: int = _get_world_player_count(world)
	if player_count == 1:
		return "1 player"
	return "%d players" % player_count


func _get_world_player_count(world: Dictionary) -> int:
	return maxi(0, int(world.get("player_count", 1)))


func _format_updated_at(world: Dictionary) -> String:
	var updated_at: int = int(world.get("updated_at", 0))
	if updated_at <= 0:
		return "Updated time unknown"

	var elapsed: int = int(Time.get_unix_time_from_system()) - updated_at
	if elapsed < 45:
		return "Updated just now"
	if elapsed < 90:
		return "Updated 1 minute ago"
	if elapsed < 3600:
		return "Updated %d minutes ago" % int(elapsed / 60)
	if elapsed < 7200:
		return "Updated 1 hour ago"
	if elapsed < 86400:
		return "Updated %d hours ago" % int(elapsed / 3600)
	if elapsed < 172800:
		return "Updated yesterday"
	if elapsed < 604800:
		return "Updated %d days ago" % int(elapsed / 86400)

	var date: Dictionary = Time.get_datetime_dict_from_unix_time(updated_at)
	return "Updated %04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


func _on_private_world_toggled(_is_private: bool) -> void:
	_update_world_visibility_copy()


func _update_world_visibility_copy() -> void:
	if _world_visibility_label == null or _world_visibility_hint == null or _private_world_check == null:
		return

	if _private_world_check.button_pressed:
		_world_visibility_label.text = "Visibility: Private Realm"
		_world_visibility_hint.text = "Hidden from list. Join by code only."
	else:
		_world_visibility_label.text = "Visibility: Open Realm"
		_world_visibility_hint.text = "Shown in Open Realms for players to join."


func _show_error(message: String) -> void:
	if _status_label != null:
		_status_label.text = message


func _remember_player_name() -> void:
	if is_instance_valid(_name_edit):
		_player_name = _name_edit.text.strip_edges()
	if _player_name.is_empty():
		_player_name = "Player"


func _get_player_name() -> String:
	_remember_player_name()
	return _player_name


func _on_rename_player_submitted(_new_text: String) -> void:
	await _on_save_player_name_pressed()


func _on_save_player_name_pressed() -> void:
	_remember_player_name()
	if _status_label != null:
		_status_label.text = "Saving player name..."

	var saved: bool = await NetworkManager.save_firebase_player_name(_player_name)
	if not saved:
		if _status_label != null and _status_label.text == "Saving player name...":
			_status_label.text = "Could not save player name."
		return

	if _status_label != null:
		_status_label.text = "Player name saved."
	_build_main_menu()


func _apply_firebase_player_name() -> void:
	var saved_name: String = NetworkManager.get_firebase_player_name()
	if saved_name.is_empty():
		return

	_player_name = saved_name
	if is_instance_valid(_name_edit):
		_name_edit.text = _player_name
	if is_instance_valid(_player_name_label):
		_player_name_label.text = "Playing as %s" % _player_name


func _on_firebase_auth_changed(_player_name_from_auth: String) -> void:
	_apply_firebase_player_name()
