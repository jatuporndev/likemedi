extends Control

const INTRO_BACKGROUND_PATH := "res://assets/menu/click_to_begin_background.png"

# -- Parchment & ink palette --
const COLOR_INK := Color(0.045, 0.032, 0.024, 1.0)
const COLOR_PARCHMENT := Color(0.76, 0.68, 0.55, 0.97)
const COLOR_PARCHMENT_DARK := Color(0.58, 0.50, 0.38, 0.94)
const COLOR_PANEL := Color(0.10, 0.075, 0.050, 0.96)
const COLOR_PANEL_SOFT := Color(0.14, 0.10, 0.065, 0.90)
const COLOR_GOLD := Color(0.82, 0.55, 0.22, 1.0)
const COLOR_GOLD_BRIGHT := Color(1.0, 0.78, 0.34, 1.0)
const COLOR_TEXT := Color(0.94, 0.86, 0.68, 1.0)
const COLOR_MUTED_TEXT := Color(0.60, 0.50, 0.34, 1.0)
const COLOR_RED := Color(0.62, 0.12, 0.08, 1.0)
const COLOR_RED_DEEP := Color(0.42, 0.08, 0.05, 1.0)
const COLOR_FOREST := Color(0.06, 0.11, 0.06, 1.0)
const COLOR_STONE := Color(0.16, 0.15, 0.13, 1.0)
const COLOR_STONE_LIGHT := Color(0.22, 0.20, 0.17, 1.0)
const COLOR_NIGHT_SKY := Color(0.025, 0.03, 0.055, 1.0)
const COLOR_TORCH := Color(1.0, 0.62, 0.18, 1.0)

# -- Ornamental characters --
const ORNAMENT_DIVIDER := "~ ◆ ~"
const ORNAMENT_BULLET := "◈"

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
var _torch_tweens: Array[Tween] = []
var _ember_container: Control


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


# ============================================================
#  INTRO SCREEN
# ============================================================

func _build_intro() -> void:
	_intro_layer = Control.new()
	_intro_layer.mouse_filter = Control.MOUSE_FILTER_PASS
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_intro_layer)

	_add_intro_background()

	# Dark atmospheric veil
	var veil := ColorRect.new()
	veil.color = Color(0.01, 0.008, 0.015, 0.30)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(veil)

	# Title block at top
	var title_stack := VBoxContainer.new()
	title_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_stack.anchor_left = 0.0
	title_stack.anchor_top = 0.0
	title_stack.anchor_right = 1.0
	title_stack.anchor_bottom = 0.0
	title_stack.offset_top = 60
	title_stack.offset_bottom = 260
	title_stack.add_theme_constant_override("separation", 6)
	_intro_layer.add_child(title_stack)

	# Ornamental top flourish
	var top_flourish := _create_label("━━━━━  ✦  ━━━━━", 16, COLOR_GOLD)
	top_flourish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_stack.add_child(top_flourish)

	# Main title
	var title := _create_title_label("LIKE MEDIEVAL", 62)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.98))
	title.add_theme_constant_override("shadow_offset_x", 3)
	title.add_theme_constant_override("shadow_offset_y", 5)
	title.add_theme_constant_override("line_spacing", -4)
	title_stack.add_child(title)

	# Subtitle
	var subtitle := _create_label("Cards, Steel, and Old Forest Roads", 17, COLOR_PARCHMENT_DARK)
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
	subtitle.add_theme_constant_override("shadow_offset_x", 1)
	subtitle.add_theme_constant_override("shadow_offset_y", 2)
	title_stack.add_child(subtitle)

	# Bottom flourish
	var bottom_flourish := _create_label("━━━━━  ✦  ━━━━━", 16, COLOR_GOLD)
	bottom_flourish.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_stack.add_child(bottom_flourish)

	# Call to action at bottom
	var prompt_container := VBoxContainer.new()
	prompt_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_container.anchor_left = 0.0
	prompt_container.anchor_top = 1.0
	prompt_container.anchor_right = 1.0
	prompt_container.anchor_bottom = 1.0
	prompt_container.offset_top = -140
	prompt_container.offset_bottom = -40
	prompt_container.add_theme_constant_override("separation", 8)
	_intro_layer.add_child(prompt_container)

	var prompt := Label.new()
	prompt.text = "CLICK TO ENTER THE KEEP"
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 30)
	prompt.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	prompt.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	prompt_container.add_child(prompt)

	var prompt_ornament := _create_label("⚔", 22, COLOR_GOLD)
	prompt_ornament.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_container.add_child(prompt_ornament)

	# Blinking prompt
	var blink := create_tween()
	blink.set_loops()
	blink.tween_property(prompt, "modulate:a", 0.15, 0.7).set_trans(Tween.TRANS_SINE)
	blink.tween_property(prompt, "modulate:a", 1.0, 0.7).set_trans(Tween.TRANS_SINE)

	# Blinking ornament (offset timing)
	var ornament_blink := create_tween()
	ornament_blink.set_loops()
	ornament_blink.tween_property(prompt_ornament, "modulate:a", 0.3, 0.9).set_trans(Tween.TRANS_SINE)
	ornament_blink.tween_property(prompt_ornament, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)


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
	fallback.color = COLOR_NIGHT_SKY
	fallback.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fallback.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_layer.add_child(fallback)

	_add_menu_backdrop(_intro_layer)


# ============================================================
#  MENU TRANSITIONS
# ============================================================

func _show_main_menu() -> void:
	_menu_visible = true
	if _intro_layer != null:
		_intro_layer.queue_free()
		_intro_layer = null
	_kill_torch_tweens()
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


# ============================================================
#  MAIN MENU
# ============================================================

func _build_main_menu() -> void:
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(440, 470), Vector2(-220, -235), Vector2(220, 235))
	var layout := _create_panel_layout(panel, 14)

	var menu_column := VBoxContainer.new()
	menu_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_column.add_theme_constant_override("separation", 10)
	layout.add_child(menu_column)

	# Ornamental header with crest
	var crest := _create_label("⚜", 28, COLOR_GOLD_BRIGHT)
	crest.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_column.add_child(crest)

	var title := _create_title_label("Like Medieval", 30)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	menu_column.add_child(title)

	# Divider
	menu_column.add_child(_create_ornamental_divider())

	# Player info row
	var player_row := HBoxContainer.new()
	player_row.add_theme_constant_override("separation", 8)
	menu_column.add_child(player_row)

	var shield_icon := _create_label("🛡", 14, COLOR_GOLD)
	shield_icon.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	player_row.add_child(shield_icon)

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

	# Main action buttons
	var start_button := Button.new()
	start_button.text = "⚔  Solo Expedition"
	start_button.custom_minimum_size = Vector2(0, 46)
	start_button.pressed.connect(_on_lan_start_pressed)
	_style_button(start_button, true)
	menu_column.add_child(start_button)

	var p2p_button := Button.new()
	p2p_button.text = "📜  World Ledger"
	p2p_button.custom_minimum_size = Vector2(0, 40)
	p2p_button.pressed.connect(_build_p2p_menu)
	_style_button(p2p_button)
	menu_column.add_child(p2p_button)

	var settings_button := Button.new()
	settings_button.text = "⚙  Settings"
	settings_button.disabled = true
	_style_button(settings_button)
	menu_column.add_child(settings_button)

	# Divider before quit
	menu_column.add_child(_create_ornamental_divider())

	var quit_button := Button.new()
	quit_button.text = "Leave the Keep"
	quit_button.pressed.connect(NetworkManager.quit_game)
	_style_button(quit_button)
	menu_column.add_child(quit_button)

	_status_label = _create_status_label()
	layout.add_child(_status_label)

	_play_menu_intro_animation()


# ============================================================
#  RENAME PLAYER MENU
# ============================================================

func _build_rename_player_menu() -> void:
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(430, 350), Vector2(-215, -175), Vector2(215, 175))
	var layout := _create_panel_layout(panel, 14)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	layout.add_child(header)

	var back_button := Button.new()
	back_button.text = "← Back"
	back_button.pressed.connect(_build_main_menu)
	_style_button(back_button)
	header.add_child(back_button)

	var title := _create_title_label("Rename Thy Champion", 24)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	layout.add_child(_create_ornamental_divider())

	var player_id: String = NetworkManager.get_firebase_player_id()
	var id_text: String = "Seal: %s" % player_id if not player_id.is_empty() else "Seal: awaiting the scribe..."
	var id_label := _create_label(id_text, 11, COLOR_MUTED_TEXT)
	id_label.clip_text = true
	id_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	layout.add_child(id_label)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Thy name, adventurer"
	_name_edit.text = _player_name
	_name_edit.text_submitted.connect(_on_rename_player_submitted)
	_style_line_edit(_name_edit)
	layout.add_child(_name_edit)

	var save_button := Button.new()
	save_button.text = "Inscribe Name"
	save_button.custom_minimum_size = Vector2(0, 42)
	save_button.pressed.connect(_on_save_player_name_pressed)
	_style_button(save_button, true)
	layout.add_child(save_button)

	_status_label = _create_status_label()
	layout.add_child(_status_label)

	_play_menu_intro_animation()


# ============================================================
#  P2P / WORLD LEDGER MENU
# ============================================================

func _build_p2p_menu() -> void:
	_remember_player_name()
	_clear_menu_panel()

	var panel := _create_center_panel(Vector2(1160, 620), Vector2(-580, -310), Vector2(580, 310))
	var root := _create_panel_layout(panel, 12)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	root.add_child(header)

	var back_button := Button.new()
	back_button.text = "← Back"
	back_button.pressed.connect(_build_main_menu)
	_style_button(back_button)
	header.add_child(back_button)

	var title := _create_title_label("📜  World Ledger", 26)
	title.add_theme_color_override("font_color", COLOR_GOLD_BRIGHT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)

	var refresh_button := Button.new()
	refresh_button.text = "↻ Refresh"
	refresh_button.pressed.connect(_refresh_world_list)
	_style_button(refresh_button)
	header.add_child(refresh_button)

	root.add_child(_create_ornamental_divider())

	# Two-column layout
	var columns := HBoxContainer.new()
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation", 16)
	root.add_child(columns)

	# Left column - Create / Join
	var create_panel := PanelContainer.new()
	create_panel.custom_minimum_size = Vector2(320, 0)
	create_panel.add_theme_stylebox_override("panel", _create_medieval_subpanel_style())
	columns.add_child(create_panel)

	var create_layout := _create_panel_layout(create_panel, 10)

	var create_title := _create_label("⚑  Raise A Banner", 18, COLOR_GOLD_BRIGHT)
	create_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_layout.add_child(create_title)

	create_layout.add_child(_create_thin_divider())

	_world_name_edit = LineEdit.new()
	_world_name_edit.placeholder_text = "Name thy realm"
	_world_name_edit.text = "New World"
	_style_line_edit(_world_name_edit)
	create_layout.add_child(_world_name_edit)

	create_layout.add_child(_create_world_visibility_control())

	var create_button := Button.new()
	create_button.text = "Raise the Banner"
	create_button.pressed.connect(_on_create_p2p_world_pressed)
	_style_button(create_button, true)
	create_layout.add_child(create_button)

	create_layout.add_child(_create_thin_divider())

	var code_title := _create_label("🔑  Join By Seal Code", 16, COLOR_GOLD_BRIGHT)
	code_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	create_layout.add_child(code_title)

	_eos_code_edit = LineEdit.new()
	_eos_code_edit.placeholder_text = "Enter the seal code"
	_style_line_edit(_eos_code_edit)
	create_layout.add_child(_eos_code_edit)

	var join_code_button := Button.new()
	join_code_button.text = "Break the Seal"
	join_code_button.pressed.connect(_on_join_eos_code_pressed)
	_style_button(join_code_button)
	create_layout.add_child(join_code_button)

	# Right column - World list
	var list_panel := PanelContainer.new()
	list_panel.custom_minimum_size = Vector2(720, 0)
	list_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list_panel.add_theme_stylebox_override("panel", _create_medieval_subpanel_style())
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

	var list_title := _create_label("🏰  Open Realms", 18, COLOR_GOLD_BRIGHT)
	list_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	list_layout.add_child(list_title)

	list_layout.add_child(_create_thin_divider())

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


# ============================================================
#  PANEL / LAYOUT HELPERS
# ============================================================

func _create_center_panel(min_size: Vector2, top_left: Vector2, bottom_right: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	_menu_panel = panel
	panel.custom_minimum_size = min_size
	panel.add_theme_stylebox_override("panel", _create_medieval_panel_style())
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = top_left.x
	panel.offset_top = top_left.y
	panel.offset_right = bottom_right.x
	panel.offset_bottom = bottom_right.y
	panel.modulate.a = 0.0
	panel.scale = Vector2(1.06, 1.06)
	add_child(panel)
	return panel


func _create_panel_layout(panel: PanelContainer, separation: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 24)
	panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", separation)
	margin.add_child(layout)
	return layout


func _create_ornamental_divider() -> Control:
	var divider := Label.new()
	divider.text = "━━━━━  ◆  ━━━━━"
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider.add_theme_font_size_override("font_size", 11)
	divider.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.5))
	return divider


func _create_thin_divider() -> Control:
	var divider := Label.new()
	divider.text = "─────────────"
	divider.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	divider.add_theme_font_size_override("font_size", 10)
	divider.add_theme_color_override("font_color", Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.3))
	return divider


# ============================================================
#  LABELS
# ============================================================

func _create_title_label(text: String, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.95))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 3)
	return label


func _create_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.85))
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


# ============================================================
#  MEDIEVAL PANEL STYLES
# ============================================================

func _create_medieval_panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.065, 0.048, 0.032, 0.97)
	# Thick outer gold border
	style.border_color = COLOR_GOLD
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	# Rounded stone-arch corners
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	# Inner shadow
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.45)
	style.shadow_size = 12
	style.shadow_offset = Vector2(0, 4)
	return style


func _create_medieval_subpanel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.06, 0.04, 0.92)
	style.border_color = Color(COLOR_GOLD.r, COLOR_GOLD.g, COLOR_GOLD.b, 0.6)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.3)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2)
	return style


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


# ============================================================
#  BUTTON & INPUT STYLES
# ============================================================

func _style_button(button: Button, is_primary: bool = false) -> void:
	button.add_theme_stylebox_override("normal", _create_button_style(is_primary, false, false))
	button.add_theme_stylebox_override("hover", _create_button_style(is_primary, true, false))
	button.add_theme_stylebox_override("pressed", _create_button_style(is_primary, true, true))
	button.add_theme_stylebox_override("disabled", _create_button_style(false, false, false, true))
	button.add_theme_color_override("font_color", COLOR_TEXT)
	button.add_theme_color_override("font_hover_color", COLOR_GOLD_BRIGHT)
	button.add_theme_color_override("font_pressed_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.38, 0.32, 0.24, 1.0))
	button.add_theme_font_size_override("font_size", 15)


func _create_button_style(
	is_primary: bool,
	is_hovered: bool,
	is_pressed: bool,
	is_disabled: bool = false
) -> StyleBoxFlat:
	var bg := Color(0.10, 0.07, 0.04, 0.96)
	var border := Color(0.48, 0.30, 0.12, 0.95)
	if is_primary:
		bg = Color(0.38, 0.09, 0.04, 0.98)
		border = COLOR_GOLD
	if is_hovered:
		bg = bg.lightened(0.10)
		border = COLOR_GOLD_BRIGHT
	if is_pressed:
		bg = bg.darkened(0.15)
	if is_disabled:
		bg = Color(0.065, 0.055, 0.045, 0.72)
		border = Color(0.22, 0.18, 0.14, 0.8)

	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	if not is_disabled and not is_pressed:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.25)
		style.shadow_size = 3
		style.shadow_offset = Vector2(0, 2)
	return style


func _style_line_edit(line_edit: LineEdit) -> void:
	line_edit.add_theme_stylebox_override("normal", _create_input_style(false))
	line_edit.add_theme_stylebox_override("focus", _create_input_style(true))
	line_edit.add_theme_color_override("font_color", COLOR_TEXT)
	line_edit.add_theme_color_override("font_placeholder_color", COLOR_MUTED_TEXT)
	line_edit.add_theme_color_override("caret_color", COLOR_GOLD_BRIGHT)
	line_edit.add_theme_font_size_override("font_size", 14)


func _create_input_style(is_focused: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.022, 0.016, 0.96)
	style.border_color = COLOR_GOLD if is_focused else Color(0.35, 0.22, 0.10, 0.95)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 2
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


# ============================================================
#  BACKDROP - MEDIEVAL NIGHT SCENE
# ============================================================

func _add_menu_backdrop(parent: Control) -> void:
	# Night sky gradient
	var sky := ColorRect.new()
	sky.color = COLOR_NIGHT_SKY
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sky.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(sky)

	# Stars
	_add_stars(parent)

	# Moon
	_add_moon(parent)

	# Landscape layers
	var forest := Control.new()
	forest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	forest.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(forest)

	# Far mountain range
	_add_mountain_range(forest, Color(0.035, 0.04, 0.065, 1.0), 0.50, 80.0)
	# Mid hills with trees
	_add_hill(forest, Color(0.04, 0.075, 0.04, 1.0), 0.60, 100.0)
	_add_hill(forest, Color(0.03, 0.058, 0.032, 1.0), 0.70, 130.0)

	# Castle silhouette
	_add_keep_silhouette(forest)

	# Mist layer
	_add_mist_layer(forest)

	# Ground
	_add_ground_band(forest)

	# Torches flanking the castle
	_add_torch(forest, Vector2(855, 350))
	_add_torch(forest, Vector2(1145, 350))


func _add_stars(parent: Control) -> void:
	var star_positions := [
		Vector2(80, 45), Vector2(210, 90), Vector2(350, 30), Vector2(480, 110),
		Vector2(600, 55), Vector2(730, 25), Vector2(850, 80), Vector2(990, 40),
		Vector2(1120, 95), Vector2(1200, 50), Vector2(150, 150), Vector2(420, 170),
		Vector2(680, 140), Vector2(920, 160), Vector2(1080, 130), Vector2(55, 200),
		Vector2(300, 65), Vector2(540, 190), Vector2(780, 200), Vector2(1250, 175),
	]
	for pos in star_positions:
		var star := ColorRect.new()
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var brightness := randf_range(0.4, 0.9)
		star.color = Color(brightness, brightness, brightness * 0.85, brightness)
		var star_size := randf_range(1.0, 2.5)
		star.size = Vector2(star_size, star_size)
		star.position = pos
		parent.add_child(star)

		# Twinkle
		var twinkle := parent.create_tween()
		twinkle.set_loops()
		var delay := randf_range(0.0, 3.0)
		twinkle.tween_interval(delay)
		twinkle.tween_property(star, "modulate:a", randf_range(0.2, 0.5), randf_range(1.0, 2.5)).set_trans(Tween.TRANS_SINE)
		twinkle.tween_property(star, "modulate:a", 1.0, randf_range(1.0, 2.5)).set_trans(Tween.TRANS_SINE)


func _add_moon(parent: Control) -> void:
	# Main moon glow
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color(0.85, 0.82, 0.65, 0.06)
	glow.size = Vector2(180, 180)
	glow.position = Vector2(110, 30)
	parent.add_child(glow)

	# Moon body
	var moon := Polygon2D.new()
	moon.color = Color(0.88, 0.85, 0.72, 0.92)
	var points: Array[Vector2] = []
	for i in range(32):
		var angle := i * TAU / 32.0
		points.append(Vector2(cos(angle) * 32, sin(angle) * 32))
	moon.polygon = PackedVector2Array(points)
	moon.position = Vector2(200, 120)
	parent.add_child(moon)

	# Crescent shadow
	var shadow := Polygon2D.new()
	shadow.color = Color(COLOR_NIGHT_SKY.r, COLOR_NIGHT_SKY.g, COLOR_NIGHT_SKY.b, 0.92)
	var shadow_points: Array[Vector2] = []
	for i in range(32):
		var angle := i * TAU / 32.0
		shadow_points.append(Vector2(cos(angle) * 30 + 14, sin(angle) * 32))
	shadow.polygon = PackedVector2Array(shadow_points)
	shadow.position = Vector2(200, 120)
	parent.add_child(shadow)


func _add_mountain_range(parent: Control, color: Color, y_fraction: float, height: float) -> void:
	var mountain := Polygon2D.new()
	mountain.color = color
	mountain.polygon = PackedVector2Array([
		Vector2(-80, 720),
		Vector2(-80, 720 * y_fraction + height * 0.3),
		Vector2(100, 720 * y_fraction - height * 0.6),
		Vector2(200, 720 * y_fraction - height * 0.2),
		Vector2(350, 720 * y_fraction - height * 0.9),
		Vector2(500, 720 * y_fraction - height * 0.1),
		Vector2(650, 720 * y_fraction - height * 0.7),
		Vector2(800, 720 * y_fraction + height * 0.1),
		Vector2(950, 720 * y_fraction - height * 0.5),
		Vector2(1100, 720 * y_fraction - height * 0.3),
		Vector2(1200, 720 * y_fraction - height * 0.8),
		Vector2(1360, 720 * y_fraction - height * 0.1),
		Vector2(1360, 720),
	])
	parent.add_child(mountain)


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
	var keep_color := Color(0.08, 0.075, 0.065, 1.0)
	var tower_color := Color(0.07, 0.065, 0.055, 1.0)

	# Main keep body
	_add_rect(parent, Rect2(860, 236, 280, 260), keep_color)

	# Left tower
	_add_rect(parent, Rect2(806, 258, 82, 238), tower_color)
	_add_rect(parent, Rect2(800, 248, 14, 30), tower_color)  # left battlement
	_add_rect(parent, Rect2(824, 248, 14, 30), tower_color)
	_add_rect(parent, Rect2(850, 248, 14, 30), tower_color)
	_add_rect(parent, Rect2(874, 248, 14, 30), tower_color)

	# Right tower
	_add_rect(parent, Rect2(1112, 248, 90, 248), tower_color)
	_add_rect(parent, Rect2(1106, 238, 14, 30), tower_color)
	_add_rect(parent, Rect2(1130, 238, 14, 30), tower_color)
	_add_rect(parent, Rect2(1154, 238, 14, 30), tower_color)
	_add_rect(parent, Rect2(1178, 238, 14, 30), tower_color)

	# Central spire
	_add_rect(parent, Rect2(975, 176, 50, 60), tower_color)
	# Spire peak (triangle via polygon)
	var spire := Polygon2D.new()
	spire.color = tower_color
	spire.polygon = PackedVector2Array([
		Vector2(1000, 148),
		Vector2(975, 180),
		Vector2(1025, 180),
	])
	parent.add_child(spire)

	# Center battlements
	_add_rect(parent, Rect2(870, 218, 12, 24), keep_color)
	_add_rect(parent, Rect2(896, 218, 12, 24), keep_color)
	_add_rect(parent, Rect2(922, 218, 12, 24), keep_color)
	_add_rect(parent, Rect2(1048, 218, 12, 24), keep_color)
	_add_rect(parent, Rect2(1074, 218, 12, 24), keep_color)
	_add_rect(parent, Rect2(1100, 218, 12, 24), keep_color)

	# Gate (dark archway)
	_add_rect(parent, Rect2(968, 370, 64, 126), Color(0.02, 0.016, 0.012, 1.0))
	# Gate arch top
	var arch := Polygon2D.new()
	arch.color = Color(0.02, 0.016, 0.012, 1.0)
	var arch_points: Array[Vector2] = []
	for i in range(17):
		var angle := PI + (i * PI / 16.0)
		arch_points.append(Vector2(1000 + cos(angle) * 32, 370 + sin(angle) * 32))
	arch.polygon = PackedVector2Array(arch_points)
	parent.add_child(arch)

	# Window slits (glowing)
	var window_color := Color(0.9, 0.55, 0.15, 0.35)
	_add_rect(parent, Rect2(900, 290, 6, 18), window_color)
	_add_rect(parent, Rect2(930, 290, 6, 18), window_color)
	_add_rect(parent, Rect2(1060, 290, 6, 18), window_color)
	_add_rect(parent, Rect2(1090, 290, 6, 18), window_color)
	_add_rect(parent, Rect2(995, 200, 10, 22), window_color)


func _add_mist_layer(parent: Control) -> void:
	var mist := ColorRect.new()
	mist.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist.color = Color(0.15, 0.18, 0.22, 0.06)
	mist.anchor_left = 0.0
	mist.anchor_right = 1.0
	mist.anchor_top = 0.0
	mist.anchor_bottom = 0.0
	mist.offset_top = 380
	mist.offset_bottom = 440
	parent.add_child(mist)

	var mist2 := ColorRect.new()
	mist2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mist2.color = Color(0.12, 0.14, 0.18, 0.04)
	mist2.anchor_left = 0.0
	mist2.anchor_right = 1.0
	mist2.anchor_top = 0.0
	mist2.anchor_bottom = 0.0
	mist2.offset_top = 420
	mist2.offset_bottom = 500
	parent.add_child(mist2)


func _add_torch(parent: Control, pos: Vector2) -> void:
	# Torch post
	_add_rect(parent, Rect2(pos.x - 2, pos.y, 4, 30), Color(0.25, 0.15, 0.06, 1.0))

	# Flame glow (animated)
	var glow := ColorRect.new()
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	glow.color = Color(1.0, 0.5, 0.1, 0.08)
	glow.size = Vector2(60, 60)
	glow.position = pos - Vector2(30, 40)
	parent.add_child(glow)

	# Flame core
	var flame := ColorRect.new()
	flame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flame.color = COLOR_TORCH
	flame.size = Vector2(6, 10)
	flame.position = pos - Vector2(3, 12)
	parent.add_child(flame)

	# Flicker animation
	var tween := parent.create_tween()
	tween.set_loops()
	tween.tween_property(glow, "modulate:a", randf_range(0.4, 0.7), randf_range(0.15, 0.35)).set_trans(Tween.TRANS_SINE)
	tween.tween_property(glow, "modulate:a", 1.0, randf_range(0.15, 0.35)).set_trans(Tween.TRANS_SINE)
	_torch_tweens.append(tween)

	var flame_tween := parent.create_tween()
	flame_tween.set_loops()
	flame_tween.tween_property(flame, "modulate:a", randf_range(0.5, 0.8), randf_range(0.1, 0.25)).set_trans(Tween.TRANS_SINE)
	flame_tween.tween_property(flame, "modulate:a", 1.0, randf_range(0.1, 0.25)).set_trans(Tween.TRANS_SINE)
	_torch_tweens.append(flame_tween)


func _kill_torch_tweens() -> void:
	for tween in _torch_tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	_torch_tweens.clear()


func _add_ground_band(parent: Control) -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.04, 0.03, 0.02, 1.0)
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.anchor_left = 0.0
	ground.anchor_top = 1.0
	ground.anchor_right = 1.0
	ground.anchor_bottom = 1.0
	ground.offset_top = -170
	parent.add_child(ground)

	# Grass line
	var grass := ColorRect.new()
	grass.color = Color(0.04, 0.06, 0.03, 1.0)
	grass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grass.anchor_left = 0.0
	grass.anchor_top = 1.0
	grass.anchor_right = 1.0
	grass.anchor_bottom = 1.0
	grass.offset_top = -174
	grass.offset_bottom = -168
	parent.add_child(grass)


func _add_rect(parent: Control, rect: Rect2, color: Color) -> void:
	var block := ColorRect.new()
	block.color = color
	block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block.position = rect.position
	block.size = rect.size
	parent.add_child(block)


# ============================================================
#  ANIMATION
# ============================================================

func _play_menu_intro_animation() -> void:
	await get_tree().process_frame
	if _menu_panel == null:
		return

	_menu_panel.pivot_offset = _menu_panel.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(_menu_panel, "scale", Vector2.ONE, 0.4)
	tween.tween_property(_menu_panel, "modulate:a", 1.0, 0.3)


# ============================================================
#  WORLD LIST
# ============================================================

func _refresh_world_list() -> void:
	if _world_list == null:
		return

	for child in _world_list.get_children():
		child.queue_free()

	var loading := Label.new()
	loading.text = "Dispatching riders for the realm list..."
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
		empty.text = "No open realms found. The land lies quiet."
		empty.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
		_world_list.add_child(empty)
		return

	for world in visible_worlds:
		_world_list.add_child(_create_world_row(world))


func _create_world_row(world: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.custom_minimum_size = Vector2(0, 72)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var row_style := StyleBoxFlat.new()
	row_style.bg_color = Color(0.055, 0.043, 0.032, 0.94)
	row_style.border_color = Color(0.42, 0.28, 0.12, 0.7)
	row_style.border_width_left = 1
	row_style.border_width_top = 1
	row_style.border_width_right = 1
	row_style.border_width_bottom = 2
	row_style.corner_radius_top_left = 4
	row_style.corner_radius_top_right = 4
	row_style.corner_radius_bottom_left = 4
	row_style.corner_radius_bottom_right = 4
	row.add_theme_stylebox_override("panel", row_style)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 8)
	row.add_child(margin)

	var layout := HBoxContainer.new()
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	# Banner icon
	var banner := _create_label("⚑", 20, COLOR_GOLD)
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	layout.add_child(banner)

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
	meta.text = "%s  •  %s" % [_format_player_count(world), _format_updated_at(world)]
	meta.clip_text = true
	meta.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	meta.add_theme_font_size_override("font_size", 12)
	meta.add_theme_color_override("font_color", COLOR_MUTED_TEXT)
	details.add_child(meta)

	var join_button := Button.new()
	join_button.text = "⚔ Join"
	join_button.custom_minimum_size = Vector2(82, 36)
	join_button.pressed.connect(_join_world.bind(world))
	_style_button(join_button, true)
	layout.add_child(join_button)

	return row


func _create_world_visibility_control() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 82)

	var vis_style := StyleBoxFlat.new()
	vis_style.bg_color = Color(0.045, 0.035, 0.026, 0.88)
	vis_style.border_color = Color(0.35, 0.22, 0.10, 0.7)
	vis_style.border_width_left = 1
	vis_style.border_width_top = 1
	vis_style.border_width_right = 1
	vis_style.border_width_bottom = 1
	vis_style.corner_radius_top_left = 4
	vis_style.corner_radius_top_right = 4
	vis_style.corner_radius_bottom_left = 4
	vis_style.corner_radius_bottom_right = 4
	panel.add_theme_stylebox_override("panel", vis_style)

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


# ============================================================
#  GAME ACTIONS
# ============================================================

func _on_lan_start_pressed() -> void:
	_status_label.text = "Preparing the expedition..."
	NetworkManager.set_transport_mode("enet")
	NetworkManager.host_game(_get_player_name())


func _on_create_p2p_world_pressed() -> void:
	_status_label.text = "Raising the banner..."
	NetworkManager.set_transport_mode("eos")
	NetworkManager.host_game(
		_get_player_name(),
		_world_name_edit.text.strip_edges(),
		not _private_world_check.button_pressed
	)


func _on_join_eos_code_pressed() -> void:
	_status_label.text = "Breaking the seal..."
	NetworkManager.set_transport_mode("eos")
	NetworkManager.join_game(_eos_code_edit.text, _get_player_name())


func _on_private_world_toggled(_is_private: bool) -> void:
	_update_world_visibility_copy()


func _update_world_visibility_copy() -> void:
	if _world_visibility_label == null or _world_visibility_hint == null or _private_world_check == null:
		return

	if _private_world_check.button_pressed:
		_world_visibility_label.text = "🔒  Private Realm"
		_world_visibility_hint.text = "Hidden from the ledger. Join by seal code only."
	else:
		_world_visibility_label.text = "🏰  Open Realm"
		_world_visibility_hint.text = "Listed in Open Realms for all to see."


# ============================================================
#  WORLD HELPERS
# ============================================================

func _join_world(world: Dictionary) -> void:
	var eos_code := _get_world_code(world)
	if eos_code.is_empty():
		_show_error("This realm bears no seal code.")
		return

	_status_label.text = "Marching toward %s..." % str(world.get("world_name", "the realm"))
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
	return "Unnamed Realm"


func _format_player_count(world: Dictionary) -> String:
	var player_count: int = _get_world_player_count(world)
	if player_count == 1:
		return "1 soul"
	return "%d souls" % player_count


func _get_world_player_count(world: Dictionary) -> int:
	return maxi(0, int(world.get("player_count", 1)))


func _format_updated_at(world: Dictionary) -> String:
	var updated_at: int = int(world.get("updated_at", 0))
	if updated_at <= 0:
		return "Last seen: unknown"

	var elapsed: int = int(Time.get_unix_time_from_system()) - updated_at
	if elapsed < 45:
		return "Seen moments ago"
	if elapsed < 90:
		return "Seen 1 minute ago"
	if elapsed < 3600:
		return "Seen %d minutes ago" % int(elapsed / 60)
	if elapsed < 7200:
		return "Seen 1 hour ago"
	if elapsed < 86400:
		return "Seen %d hours ago" % int(elapsed / 3600)
	if elapsed < 172800:
		return "Seen yesterday"
	if elapsed < 604800:
		return "Seen %d days ago" % int(elapsed / 86400)

	var date: Dictionary = Time.get_datetime_dict_from_unix_time(updated_at)
	return "Seen %04d-%02d-%02d" % [date["year"], date["month"], date["day"]]


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
		_status_label.text = "The scribe inscribes thy name..."

	var saved: bool = await NetworkManager.save_firebase_player_name(_player_name)
	if not saved:
		if _status_label != null and _status_label.text == "The scribe inscribes thy name...":
			_status_label.text = "The scribe could not inscribe thy name."
		return

	if _status_label != null:
		_status_label.text = "Thy name has been inscribed."
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
