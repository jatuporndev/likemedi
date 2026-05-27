@tool
extends StaticBody2D

@export var texture: Texture2D:
	set(value):
		texture = value
		_rebuild()

@export var sprite_offset := Vector2.ZERO:
	set(value):
		sprite_offset = value
		_rebuild()

@export var sprite_scale := Vector2.ONE:
	set(value):
		sprite_scale = value
		_rebuild()

@export var collision_size := Vector2(48.0, 32.0):
	set(value):
		collision_size = value
		_rebuild()

@export var collision_offset := Vector2.ZERO:
	set(value):
		collision_offset = value
		_rebuild()

@export var y_sort_foot_offset := 0.0:
	set(value):
		y_sort_foot_offset = value
		_rebuild()

const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4095

var _sprite: Sprite2D = null
var _collision_shape: CollisionShape2D = null


func _ready() -> void:
	_rebuild()


func _process(_delta: float) -> void:
	if _sprite == null:
		return
	_sprite.z_as_relative = false
	_sprite.z_index = clampi(
		int(round(global_position.y + y_sort_foot_offset)),
		DRAW_ORDER_MIN,
		DRAW_ORDER_MAX
	)


func _rebuild() -> void:
	if not is_inside_tree():
		return

	if _sprite == null:
		_sprite = Sprite2D.new()
		_sprite.name = "Sprite"
		add_child(_sprite)

	_sprite.texture = texture
	_sprite.position = sprite_offset
	_sprite.scale = sprite_scale

	if _collision_shape == null:
		_collision_shape = CollisionShape2D.new()
		_collision_shape.name = "CollisionShape2D"
		add_child(_collision_shape)

	var rect_shape := _collision_shape.shape as RectangleShape2D
	if rect_shape == null:
		rect_shape = RectangleShape2D.new()
		_collision_shape.shape = rect_shape
	rect_shape.size = collision_size
	_collision_shape.position = collision_offset
