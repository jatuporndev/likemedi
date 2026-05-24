extends PanelContainer
class_name DeckBuilderCard

signal drag_requested(card: DeckBuilderCard, skill_name: String, from: String, definition: Dictionary)

const SKILL_CARD_SCENE := preload("res://scenes/ui/skill_card_view.tscn")

var skill_name := ""
var from := ""
var definition: Dictionary = {}

var _card_view: SkillCardView


func setup(p_skill_name: String, p_definition: Dictionary, p_from: String) -> void:
	skill_name = p_skill_name
	definition = p_definition
	from = p_from

	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	add_theme_stylebox_override("panel", StyleBoxEmpty.new())

	_card_view = SKILL_CARD_SCENE.instantiate() as SkillCardView
	add_child(_card_view)
	if _card_view != null:
		custom_minimum_size = _card_view.custom_minimum_size
		_card_view.gui_input.connect(_on_card_view_gui_input)
		_card_view.call_deferred(
			"setup",
			skill_name,
			str(definition.get("title", skill_name)),
			str(definition.get("cost", 0)),
			str(definition.get("description", "")),
			definition.get("art_color", Color.WHITE)
		)
		call_deferred("_disable_card_view_input")


func _gui_input(event: InputEvent) -> void:
	_handle_drag_input(event)


func _on_card_view_gui_input(event: InputEvent) -> void:
	_handle_drag_input(event)


func _disable_card_view_input() -> void:
	_set_control_tree_mouse_filter(_card_view, Control.MOUSE_FILTER_IGNORE)


func _set_control_tree_mouse_filter(control: Control, filter: int) -> void:
	if control == null:
		return

	control.mouse_filter = filter
	for child in control.get_children():
		if child is Control:
			_set_control_tree_mouse_filter(child, filter)


func _handle_drag_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if skill_name.is_empty():
			return
		drag_requested.emit(self, skill_name, from, definition)
		get_viewport().set_input_as_handled()
