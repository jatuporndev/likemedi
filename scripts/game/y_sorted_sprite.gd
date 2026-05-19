extends Sprite2D

@export var draw_order_foot_offset := 0.0
@export var region_animation_frame_count := 1
@export var region_animation_fps := 0.0
@export var region_animation_ping_pong := true

const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4095

var _base_region_rect := Rect2()
var _animation_elapsed := 0.0


func _ready() -> void:
	z_as_relative = false
	_base_region_rect = region_rect
	_update_draw_order()


func _process(delta: float) -> void:
	_update_region_animation(delta)
	_update_draw_order()


func _update_region_animation(delta: float) -> void:
	if not region_enabled or region_animation_frame_count <= 1 or region_animation_fps <= 0.0:
		return

	_animation_elapsed += delta
	var frame_index := int(floor(_animation_elapsed * region_animation_fps))

	if region_animation_ping_pong and region_animation_frame_count > 2:
		var cycle_length := (region_animation_frame_count * 2) - 2
		var cycle_frame := frame_index % cycle_length
		if cycle_frame >= region_animation_frame_count:
			frame_index = cycle_length - cycle_frame
		else:
			frame_index = cycle_frame
	else:
		frame_index %= region_animation_frame_count

	region_rect = Rect2(
		_base_region_rect.position + Vector2(_base_region_rect.size.x * frame_index, 0.0),
		_base_region_rect.size
	)


func _update_draw_order() -> void:
	z_index = clampi(
		int(round(global_position.y + draw_order_foot_offset)),
		DRAW_ORDER_MIN,
		DRAW_ORDER_MAX
	)
