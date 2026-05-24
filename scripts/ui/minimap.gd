extends Control

@export var world_path: NodePath
@export var padding := 8.0

@export var background_color := Color(0.05, 0.04, 0.03, 0.72)
@export var border_color := Color(0.90, 0.67, 0.30, 0.92)
@export var border_width := 2.0

@export var player_color := Color(0.30, 0.95, 0.40, 1.0)
@export var enemy_color := Color(0.95, 0.30, 0.22, 1.0)
@export var warp_color := Color(1.0, 0.72, 0.25, 1.0)
@export var marker_radius := 2.6
@export var warp_radius := 2.8

var _world: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_world = get_node_or_null(world_path) if not world_path.is_empty() else get_parent()
	set_process(true)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(Vector2.ZERO, size)
	draw_rect(rect, background_color, true)
	draw_rect(rect, border_color, false, border_width)

	if _world == null or not _world.has_method("get_current_map_rect"):
		return

	var map_rect: Rect2 = _world.call("get_current_map_rect")
	if map_rect.size.x <= 0.0 or map_rect.size.y <= 0.0:
		return

	var inner_size := Vector2(maxf(size.x - padding * 2.0, 1.0), maxf(size.y - padding * 2.0, 1.0))

	_draw_warp_markers(map_rect, inner_size)
	_draw_enemy_markers(map_rect, inner_size)
	_draw_player_marker(map_rect, inner_size)


func _draw_player_marker(map_rect: Rect2, inner_size: Vector2) -> void:
	var player := _get_local_player()
	if player == null:
		return

	var pos := _world_to_minimap(player.global_position, map_rect, inner_size)
	draw_circle(pos, marker_radius + 1.2, Color(0, 0, 0, 0.7))
	draw_circle(pos, marker_radius, player_color)


func _draw_enemy_markers(map_rect: Rect2, inner_size: Vector2) -> void:
	var enemies_node := _world.get_node_or_null("Enemies") as Node
	if enemies_node == null:
		return

	for child in enemies_node.get_children():
		var enemy := child as Node2D
		if enemy == null:
			continue
		var pos := _world_to_minimap(enemy.global_position, map_rect, inner_size)
		draw_circle(pos, marker_radius, enemy_color)


func _draw_warp_markers(map_rect: Rect2, inner_size: Vector2) -> void:
	var warps := get_tree().get_nodes_in_group("warp_points")
	for node in warps:
		var warp := node as Node2D
		if warp == null or warp.is_queued_for_deletion():
			continue
		var pos := _world_to_minimap(warp.global_position, map_rect, inner_size)
		draw_circle(pos, warp_radius + 1.3, Color(0, 0, 0, 0.65))
		draw_circle(pos, warp_radius, warp_color)


func _get_local_player() -> Node2D:
	var players_node := _world.get_node_or_null("Players") as Node
	if players_node == null:
		return null

	var local_player := players_node.get_node_or_null(str(multiplayer.get_unique_id())) as Node2D
	if local_player != null and not local_player.is_queued_for_deletion():
		return local_player

	for child in players_node.get_children():
		var player := child as Node2D
		if player != null and not player.is_queued_for_deletion():
			return player

	return null


func _world_to_minimap(world_pos: Vector2, map_rect: Rect2, inner_size: Vector2) -> Vector2:
	var t := (world_pos - map_rect.position) / map_rect.size
	t.x = clampf(t.x, 0.0, 1.0)
	t.y = clampf(t.y, 0.0, 1.0)
	return Vector2(padding, padding) + Vector2(t.x * inner_size.x, t.y * inner_size.y)
