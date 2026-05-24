@tool
extends ColorRect

const DEFAULT_MAP_ORIGIN := Vector2(-700.0, -450.0)
const DEFAULT_MAP_SIZE := Vector2(6000.0, 2400.0)

@export var enforce_project_defaults := false:
	set(value):
		enforce_project_defaults = value
		_apply_defaults_if_enabled()

@export var default_map_origin := DEFAULT_MAP_ORIGIN:
	set(value):
		default_map_origin = value
		_apply_defaults_if_enabled()

@export var default_map_size := DEFAULT_MAP_SIZE:
	set(value):
		default_map_size = value
		_apply_defaults_if_enabled()

@export var show_in_game := false:
	set(value):
		show_in_game = value
		_sync_visibility()

@export var outline_color := Color(1.0, 0.72, 0.25, 0.9)
@export_range(1.0, 12.0, 1.0) var outline_width := 3.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_defaults_if_enabled()
	_sync_visibility()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint():
		set_process(false)
		return

	_sync_visibility()


func get_map_rect_global() -> Rect2:
	return Rect2(global_position, size)


func _apply_defaults_if_enabled() -> void:
	if not enforce_project_defaults:
		color = Color(0, 0, 0, 0)
		queue_redraw()
		return

	offset_left = default_map_origin.x
	offset_top = default_map_origin.y
	offset_right = default_map_origin.x + default_map_size.x
	offset_bottom = default_map_origin.y + default_map_size.y

	color = Color(0, 0, 0, 0)
	queue_redraw()


func _sync_visibility() -> void:
	visible = Engine.is_editor_hint() or show_in_game


func _draw() -> void:
	if not visible:
		return
	if not Engine.is_editor_hint() and not show_in_game:
		return

	draw_rect(Rect2(Vector2.ZERO, size), outline_color, false, outline_width)
