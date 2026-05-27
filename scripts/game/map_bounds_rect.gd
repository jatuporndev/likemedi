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

@export var build_border_walls := true
@export_range(8.0, 256.0, 1.0) var border_wall_thickness := 64.0
@export_flags_2d_physics var border_wall_collision_layer := 1

const BORDER_WALLS_NODE_NAME := "MapBorderWalls"

var _walls_root: Node2D = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_defaults_if_enabled()
	_sync_visibility()
	if not Engine.is_editor_hint() and build_border_walls:
		call_deferred("_build_border_walls")


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


func _build_border_walls() -> void:
	if _walls_root != null and is_instance_valid(_walls_root):
		_walls_root.queue_free()
		_walls_root = null

	var parent := get_parent()
	if parent == null:
		return

	var rect := get_map_rect_global()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return

	_walls_root = Node2D.new()
	_walls_root.name = BORDER_WALLS_NODE_NAME
	parent.add_child(_walls_root)
	_walls_root.global_position = Vector2.ZERO

	var t := border_wall_thickness
	var top_left := rect.position
	var size := rect.size

	_add_wall(Rect2(Vector2(top_left.x - t, top_left.y - t), Vector2(size.x + t * 2.0, t)))
	_add_wall(Rect2(Vector2(top_left.x - t, top_left.y + size.y), Vector2(size.x + t * 2.0, t)))
	_add_wall(Rect2(Vector2(top_left.x - t, top_left.y), Vector2(t, size.y)))
	_add_wall(Rect2(Vector2(top_left.x + size.x, top_left.y), Vector2(t, size.y)))


func _add_wall(world_rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = border_wall_collision_layer
	body.collision_mask = 0

	var shape_node := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = world_rect.size
	shape_node.shape = rect_shape
	shape_node.position = world_rect.position + world_rect.size * 0.5

	body.add_child(shape_node)
	_walls_root.add_child(body)


func _draw() -> void:
	if not visible:
		return
	if not Engine.is_editor_hint() and not show_in_game:
		return

	draw_rect(Rect2(Vector2.ZERO, size), outline_color, false, outline_width)
