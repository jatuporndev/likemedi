extends RefCounted


static func create(
	skill_name: String,
	title: String,
	cost_text: String,
	description_text: String,
	art_color: Color
) -> PanelContainer:
	var card := PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	card.set_meta("skill_name", skill_name)

	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.10, 0.075, 0.055, 0.98)
	card_style.border_color = Color(0.90, 0.67, 0.30)
	card_style.border_width_left = 2
	card_style.border_width_top = 2
	card_style.border_width_right = 2
	card_style.border_width_bottom = 2
	card_style.corner_radius_top_left = 7
	card_style.corner_radius_top_right = 7
	card_style.corner_radius_bottom_left = 7
	card_style.corner_radius_bottom_right = 7
	card.add_theme_stylebox_override("panel", card_style)

	var margin := MarginContainer.new()
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", 7)
	margin.add_theme_constant_override("margin_right", 7)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_bottom", 7)
	card.add_child(margin)

	var layout := VBoxContainer.new()
	layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_theme_constant_override("separation", 5)
	margin.add_child(layout)

	var header := _create_panel(Color(0.18, 0.12, 0.07, 1.0), Color(0.54, 0.36, 0.16), 4)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(header)

	var header_margin := MarginContainer.new()
	header_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_margin.add_theme_constant_override("margin_left", 4)
	header_margin.add_theme_constant_override("margin_right", 4)
	header_margin.add_theme_constant_override("margin_top", 3)
	header_margin.add_theme_constant_override("margin_bottom", 3)
	header.add_child(header_margin)

	var header_row := HBoxContainer.new()
	header_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header_row.add_theme_constant_override("separation", 4)
	header_margin.add_child(header_row)

	var cost_badge := _create_panel(Color(0.16, 0.35, 0.42, 1.0), Color(0.72, 0.92, 1.0), 11)
	cost_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost_badge.custom_minimum_size = Vector2(22.0, 22.0)
	header_row.add_child(cost_badge)

	var cost := Label.new()
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.text = cost_text
	cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost.add_theme_font_size_override("font_size", 14)
	cost.add_theme_color_override("font_color", Color(0.82, 0.96, 1.0))
	cost_badge.add_child(cost)

	var card_title := Label.new()
	card_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card_title.text = title
	card_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	card_title.add_theme_font_size_override("font_size", 13)
	card_title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.55))
	header_row.add_child(card_title)

	var art_frame := _create_panel(art_color.darkened(0.38), Color(0.74, 0.50, 0.22), 4)
	art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_frame.custom_minimum_size = Vector2(0.0, 58.0)
	layout.add_child(art_frame)

	var art_margin := MarginContainer.new()
	art_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_margin.add_theme_constant_override("margin_left", 5)
	art_margin.add_theme_constant_override("margin_right", 5)
	art_margin.add_theme_constant_override("margin_top", 5)
	art_margin.add_theme_constant_override("margin_bottom", 5)
	art_frame.add_child(art_margin)

	var art := ColorRect.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(0.0, 48.0)
	art.color = art_color
	art_margin.add_child(art)

	var description_frame := _create_panel(Color(0.92, 0.78, 0.52, 1.0), Color(0.44, 0.27, 0.10), 4)
	description_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layout.add_child(description_frame)

	var description_margin := MarginContainer.new()
	description_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description_margin.add_theme_constant_override("margin_left", 4)
	description_margin.add_theme_constant_override("margin_right", 4)
	description_margin.add_theme_constant_override("margin_top", 3)
	description_margin.add_theme_constant_override("margin_bottom", 3)
	description_frame.add_child(description_margin)

	var description := Label.new()
	description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	description.text = description_text
	description.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	description.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_font_size_override("font_size", 10)
	description.add_theme_color_override("font_color", Color(0.12, 0.07, 0.03))
	description_margin.add_child(description)
	return card


static func _create_panel(bg_color: Color, border_color: Color, corner_radius: int) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = corner_radius
	style.corner_radius_top_right = corner_radius
	style.corner_radius_bottom_left = corner_radius
	style.corner_radius_bottom_right = corner_radius
	panel.add_theme_stylebox_override("panel", style)
	return panel
