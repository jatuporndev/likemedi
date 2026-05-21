extends PanelContainer
class_name SkillCardView

const CARD_VIEW_SIZE := Vector2(124.0, 174.0)

@onready var _cost_label: Label = $CostBadgeRoot/CostBadge/CostLabel
@onready var _title_label: Label = %TitleLabel
@onready var _art_frame: PanelContainer = %ArtFrame
@onready var _art_color_rect: ColorRect = %ArtColorRect
@onready var _description_label: Label = %DescriptionLabel


func setup(
	skill_name: String,
	title: String,
	cost_text: String,
	description_text: String,
	art_color: Color
) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = CARD_VIEW_SIZE
	set_meta("skill_name", skill_name)

	_cost_label.text = cost_text
	_title_label.text = title
	_title_label.add_theme_font_size_override("font_size", _get_title_font_size(title))
	_description_label.text = description_text
	_description_label.add_theme_font_size_override(
		"font_size",
		_get_description_font_size(description_text)
	)
	_art_color_rect.color = art_color

	var base_art_style := _art_frame.get_theme_stylebox("panel")
	var art_style := base_art_style.duplicate() as StyleBoxFlat
	if art_style != null:
		art_style.bg_color = art_color.darkened(0.38)
		_art_frame.add_theme_stylebox_override("panel", art_style)


func _get_title_font_size(text: String) -> int:
	var text_length := text.length()
	if text_length > 18:
		return 10
	if text_length > 12:
		return 11
	return 12


func _get_description_font_size(text: String) -> int:
	var text_length := text.length()
	if text_length > 74:
		return 9
	if text_length > 48:
		return 10
	return 11
