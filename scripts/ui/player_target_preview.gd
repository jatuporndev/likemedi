extends RefCounted

const FLOOR_OFFSET := Vector2(0.0, 46.0)
const FLOOR_RADIUS := 34.0
const FLOOR_Y_SCALE := 0.52
const FLOOR_SEGMENTS := 48
const MARK_COUNT := 12
const CURSOR_RADIUS := 24.0
const CURSOR_MARK_LENGTH := 13.0
const CURSOR_MARK_COUNT := 4
const TYPE_BUFF := "buff"
const TYPE_DEBUFF := "debuff"
const COLOR_CURSOR := "cursor"
const COLOR_FILL := "fill"
const COLOR_RING := "ring"
const COLOR_INNER_RING := "inner_ring"
const COLOR_RUNE := "rune"

var _cursor_center: Line2D
var _cursor_marks: Array[Line2D] = []
var _floor_root: Node2D
var _floor_fill: Polygon2D
var _floor_ring: Line2D
var _floor_inner_ring: Line2D
var _floor_rune_ring: Line2D
var _floor_marks: Array[Line2D] = []


func setup(canvas_parent: Node, floor_parent: Node) -> void:
	_cursor_center = Line2D.new()
	_cursor_center.visible = false
	_cursor_center.z_index = 30
	_cursor_center.width = 1.4
	canvas_parent.add_child(_cursor_center)

	_cursor_marks.clear()
	for _index in range(CURSOR_MARK_COUNT):
		var mark := Line2D.new()
		mark.visible = false
		mark.z_index = 31
		mark.width = 2.0
		_cursor_marks.append(mark)
		canvas_parent.add_child(mark)

	_floor_root = Node2D.new()
	_floor_root.z_index = 0
	_floor_root.y_sort_enabled = false
	if floor_parent != null:
		floor_parent.add_child(_floor_root)
		floor_parent.move_child(_floor_root, 0)
	else:
		canvas_parent.add_child(_floor_root)

	_floor_fill = Polygon2D.new()
	_floor_fill.visible = false
	_floor_root.add_child(_floor_fill)

	_floor_ring = Line2D.new()
	_floor_ring.visible = false
	_floor_ring.width = 3.0
	_floor_root.add_child(_floor_ring)

	_floor_inner_ring = Line2D.new()
	_floor_inner_ring.visible = false
	_floor_inner_ring.width = 1.5
	_floor_root.add_child(_floor_inner_ring)

	_floor_rune_ring = Line2D.new()
	_floor_rune_ring.visible = false
	_floor_rune_ring.width = 1.0
	_floor_root.add_child(_floor_rune_ring)

	_floor_marks.clear()
	for _index in range(MARK_COUNT):
		var mark := Line2D.new()
		mark.visible = false
		mark.width = 2.0
		_floor_marks.append(mark)
		_floor_root.add_child(mark)


func get_floor_root() -> Node2D:
	return _floor_root


func hide_all() -> void:
	hide_cursor()
	hide_floor()


func hide_cursor() -> void:
	if _cursor_center != null:
		_cursor_center.visible = false
	for mark in _cursor_marks:
		mark.visible = false


func hide_floor() -> void:
	if _floor_fill != null:
		_floor_fill.visible = false
	if _floor_ring != null:
		_floor_ring.visible = false
	if _floor_inner_ring != null:
		_floor_inner_ring.visible = false
	if _floor_rune_ring != null:
		_floor_rune_ring.visible = false
	for mark in _floor_marks:
		mark.visible = false


func update_cursor(center: Vector2, skill_type: String) -> void:
	var color := _get_colors(skill_type)[COLOR_CURSOR] as Color
	var pulse := 1.0 + sin(float(Time.get_ticks_msec()) * 0.009) * 0.08
	if _cursor_center != null:
		var diamond_radius := CURSOR_MARK_LENGTH * 0.34 * pulse
		var center_color := color
		center_color.a *= 0.38
		_cursor_center.default_color = center_color
		_cursor_center.points = PackedVector2Array([
			center + Vector2(0.0, -diamond_radius),
			center + Vector2(diamond_radius, 0.0),
			center + Vector2(0.0, diamond_radius),
			center + Vector2(-diamond_radius, 0.0),
			center + Vector2(0.0, -diamond_radius),
		])
		_cursor_center.visible = true

	for index in range(_cursor_marks.size()):
		var angle := (PI * 0.25) + TAU * float(index) / float(_cursor_marks.size())
		var direction := Vector2(cos(angle), sin(angle))
		var tangent := Vector2(-direction.y, direction.x)
		var pulse_offset := sin(float(Time.get_ticks_msec()) * 0.008 + float(index)) * 1.5
		var outer := center + direction * (CURSOR_RADIUS * pulse + pulse_offset)
		var inner := outer - direction * CURSOR_MARK_LENGTH
		var mark_color := color
		mark_color.a *= 0.74
		_cursor_marks[index].default_color = mark_color
		_cursor_marks[index].points = PackedVector2Array([
			inner + tangent * 4.0,
			outer,
			inner - tangent * 4.0,
		])
		_cursor_marks[index].visible = true


func update_floor(center: Vector2, skill_type: String) -> void:
	var colors := _get_colors(skill_type)
	var pulse := 1.0 + sin(Time.get_ticks_msec() * 0.008) * 0.07
	var radius := FLOOR_RADIUS * pulse
	var radii := Vector2(radius, radius * FLOOR_Y_SCALE)
	var spin := float(Time.get_ticks_msec()) * 0.0018

	if _floor_fill != null:
		_floor_fill.color = colors[COLOR_FILL] as Color
		_floor_fill.polygon = _make_ellipse_polygon(center, radii * 0.96, FLOOR_SEGMENTS)

	_floor_ring.default_color = _color_with_alpha(colors[COLOR_RING] as Color, 0.78 + 0.14 * pulse)
	_update_ellipse_ring_points(_floor_ring, center, radii, FLOOR_SEGMENTS)
	_floor_inner_ring.default_color = _color_with_alpha(
		colors[COLOR_INNER_RING] as Color,
		0.54 + 0.10 * pulse
	)
	_update_ellipse_ring_points(_floor_inner_ring, center, radii * 0.66, FLOOR_SEGMENTS)
	_floor_rune_ring.default_color = _color_with_alpha(colors[COLOR_RUNE] as Color, 0.44 + 0.10 * pulse)
	_update_rotated_ellipse_ring_points(_floor_rune_ring, center, radii * 0.82, FLOOR_SEGMENTS, spin)
	_update_floor_marks(center, radii, spin)
	_set_floor_visible(true)


func _get_colors(skill_type: String) -> Dictionary:
	if skill_type == TYPE_BUFF:
		return {
			COLOR_CURSOR: Color(0.48, 0.82, 1.0, 0.70),
			COLOR_FILL: Color(0.06, 0.50, 0.92, 0.18),
			COLOR_RING: Color(0.42, 0.78, 1.0),
			COLOR_INNER_RING: Color(0.72, 0.92, 1.0),
			COLOR_RUNE: Color(0.24, 0.66, 1.0),
		}
	if skill_type == TYPE_DEBUFF:
		return {
			COLOR_CURSOR: Color(0.80, 0.48, 1.0, 0.70),
			COLOR_FILL: Color(0.46, 0.10, 0.72, 0.18),
			COLOR_RING: Color(0.78, 0.42, 1.0),
			COLOR_INNER_RING: Color(0.92, 0.72, 1.0),
			COLOR_RUNE: Color(0.62, 0.24, 1.0),
		}

	return {
		COLOR_CURSOR: Color(0.58, 0.96, 0.68, 0.70),
		COLOR_FILL: Color(0.04, 0.86, 0.35, 0.18),
		COLOR_RING: Color(0.52, 1.0, 0.66),
		COLOR_INNER_RING: Color(0.78, 1.0, 0.80),
		COLOR_RUNE: Color(0.28, 1.0, 0.56),
	}


func _set_floor_visible(is_visible: bool) -> void:
	if _floor_fill != null:
		_floor_fill.visible = is_visible
	if _floor_ring != null:
		_floor_ring.visible = is_visible
	if _floor_inner_ring != null:
		_floor_inner_ring.visible = is_visible
	if _floor_rune_ring != null:
		_floor_rune_ring.visible = is_visible
	for mark in _floor_marks:
		mark.visible = is_visible


func _update_floor_marks(center: Vector2, radii: Vector2, spin: float) -> void:
	for index in range(_floor_marks.size()):
		var angle := spin + TAU * float(index) / float(_floor_marks.size())
		var direction := Vector2(cos(angle), sin(angle))
		var inner := center + direction * radii * 0.74
		var outer := center + direction * radii * 0.98
		_floor_marks[index].points = PackedVector2Array([inner, outer])


func _make_ellipse_polygon(center: Vector2, radii: Vector2, segment_count: int) -> PackedVector2Array:
	var points := PackedVector2Array([center])
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	return points


func _update_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _update_rotated_ellipse_ring_points(
	ring: Line2D,
	center: Vector2,
	radii: Vector2,
	segment_count: int,
	rotation: float
) -> void:
	if ring == null:
		return

	var points := PackedVector2Array()
	for i in range(segment_count + 1):
		var angle := rotation + TAU * float(i) / float(segment_count)
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	ring.points = points


func _color_with_alpha(color: Color, alpha: float) -> Color:
	return Color(color.r, color.g, color.b, alpha)
