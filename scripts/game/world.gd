extends Node2D

const ENEMY_SCENE := preload("res://scenes/enemies/enemy_bot.tscn")
const MAP_CONFIG_PATH := "res://config/maps.json"
const DEFAULT_MAP_SCENE := "res://scenes/world/maps/map_1.tscn"
const RANDOM_SPAWN_ATTEMPTS := 32
const FALLBACK_MAP_RECT := Rect2(Vector2(-700, -450), Vector2(6000, 2400))
const MAP_TRANSITION_LOCK_MSEC := 650
const MAP_TRANSITION_LOCKED_UNTIL_META := "map_transition_locked_until_msec"
const PLAYER_SPAWN_POINT_NODE_NAME := "PlayerSpawnPoint"
const SPAWN_ANCHOR_NODE_NAME := "SpawnAnchor"

@onready var map_root: Node2D = $MapRoot
@onready var enemies: Node2D = $Enemies

var _rng := RandomNumberGenerator.new()
var _next_enemy_id := 1
var _current_map_scene_path := ""
var _map_configs: Dictionary = {}
var _enemy_spawn_blocks: Array[Dictionary] = []
var _respawn_map_scene_path := ""
var _respawn_spawn_name := SPAWN_ANCHOR_NODE_NAME


func _ready() -> void:
	_load_map_configs()
	_rng.randomize()
	_load_map(DEFAULT_MAP_SCENE)


func _process(delta: float) -> void:
	if not multiplayer.is_server():
		return

	_update_enemy_spawn_blocks(delta)


func sync_enemies_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server():
		return

	for enemy in enemies.get_children():
		var enemy_2d := enemy as Node2D
		if enemy_2d == null:
			continue
		spawn_enemy.rpc_id(
			peer_id,
			str(enemy.name),
			enemy_2d.position,
			str(enemy.get("enemy_id")),
			int(enemy.get_meta("spawn_block_index", -1))
		)


func sync_map_to_peer(peer_id: int) -> void:
	if not multiplayer.is_server() or _current_map_scene_path.is_empty():
		return

	_load_map_rpc.rpc_id(peer_id, _current_map_scene_path)


func change_map_for_player(player: Node2D, map_scene_path: String, spawn_name: String) -> void:
	if player == null or map_scene_path.is_empty():
		return
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return

	if multiplayer.multiplayer_peer == null:
		_change_map_for_player_local(map_scene_path, spawn_name, player.get_path())
	else:
		_change_map_for_player_rpc.rpc(map_scene_path, spawn_name, player.get_path())


func revive_player_at_spawn(player: Node2D) -> bool:
	if player == null or _respawn_map_scene_path.is_empty():
		return false
	if multiplayer.multiplayer_peer != null and not multiplayer.is_server():
		return false

	if multiplayer.multiplayer_peer == null:
		_change_map_for_player_local(_respawn_map_scene_path, _respawn_spawn_name, player.get_path())
	else:
		_change_map_for_player_rpc.rpc(_respawn_map_scene_path, _respawn_spawn_name, player.get_path())
	return true


@rpc("authority", "call_local", "reliable")
func _load_map_rpc(map_scene_path: String) -> void:
	_load_map(map_scene_path)


@rpc("authority", "call_local", "reliable")
func _change_map_for_player_rpc(map_scene_path: String, spawn_name: String, player_path: NodePath) -> void:
	_change_map_for_player_local(map_scene_path, spawn_name, player_path)


func _change_map_for_player_local(map_scene_path: String, spawn_name: String, player_path: NodePath) -> void:
	_load_map(map_scene_path)

	var player := get_node_or_null(player_path) as Node2D
	if player == null:
		return

	var spawn_marker := _find_spawn_marker(spawn_name)
	if spawn_marker == null:
		spawn_marker = _find_spawn_marker(SPAWN_ANCHOR_NODE_NAME)
	if spawn_marker == null:
		spawn_marker = _find_spawn_marker(PLAYER_SPAWN_POINT_NODE_NAME)

	player.set_meta(
		MAP_TRANSITION_LOCKED_UNTIL_META,
		Time.get_ticks_msec() + MAP_TRANSITION_LOCK_MSEC
	)
	if spawn_marker != null:
		player.global_position = spawn_marker.global_position
	else:
		push_warning("Spawn marker '%s' not found on %s; using map center" % [spawn_name, map_scene_path])
		player.global_position = _get_current_map_rect().get_center()
	player.set("velocity", Vector2.ZERO)


func _load_map(map_scene_path: String) -> void:
	if _current_map_scene_path == map_scene_path:
		return

	var map_scene := load(map_scene_path) as PackedScene
	if map_scene == null:
		push_warning("Unable to load map scene: %s" % map_scene_path)
		return

	for child in map_root.get_children():
		map_root.remove_child(child)
		child.queue_free()

	var map := map_scene.instantiate()
	map_root.add_child(map)
	_current_map_scene_path = map_scene_path
	_update_respawn_crystal_for_current_map()
	_load_current_map_enemy_blocks()
	_spawn_current_map_props(map)
	_clear_enemies()
	if multiplayer.is_server():
		_spawn_initial_map_enemies()


func _find_spawn_marker(spawn_name: String) -> Node2D:
	if map_root == null:
		return null
	var marker := map_root.find_child(spawn_name, true, false) as Node2D
	return marker


func _update_respawn_crystal_for_current_map() -> void:
	var spawn_point := _find_spawn_marker(PLAYER_SPAWN_POINT_NODE_NAME)
	if spawn_point == null:
		return

	_respawn_map_scene_path = _current_map_scene_path
	var spawn_anchor := spawn_point.get_node_or_null(SPAWN_ANCHOR_NODE_NAME) as Node2D
	_respawn_spawn_name = SPAWN_ANCHOR_NODE_NAME if spawn_anchor != null else PLAYER_SPAWN_POINT_NODE_NAME


func _load_map_configs() -> void:
	if not FileAccess.file_exists(MAP_CONFIG_PATH):
		push_warning("Map config not found: %s" % MAP_CONFIG_PATH)
		return

	var parsed = JSON.parse_string(FileAccess.get_file_as_string(MAP_CONFIG_PATH))
	if not (parsed is Dictionary):
		push_warning("Map config is not a dictionary: %s" % MAP_CONFIG_PATH)
		return

	_map_configs = parsed


func _load_current_map_enemy_blocks() -> void:
	_enemy_spawn_blocks.clear()
	if not _map_configs.has(_current_map_scene_path):
		return

	var map_config = _map_configs[_current_map_scene_path]
	if not (map_config is Dictionary):
		return

	var enemy_blocks = map_config.get("enemies", [])
	if not (enemy_blocks is Array):
		return

	for index in range(enemy_blocks.size()):
		var block = enemy_blocks[index]
		if not (block is Dictionary):
			continue

		var enemy_id := str(block.get("enemy_id", ""))
		var count := maxi(int(block.get("count", 0)), 0)
		var respawn_seconds := maxf(float(block.get("respawn_seconds", 0.0)), 0.0)
		if enemy_id.is_empty() or count <= 0:
			continue

		_enemy_spawn_blocks.append({
			"id": "block_%d" % index,
			"enemy_id": enemy_id,
			"count": count,
			"respawn_seconds": respawn_seconds,
			"respawn_time": 0.0,
		})


const PROP_COUNT := 130
const PROP_MIN_SPACING := 95.0
const PROP_SPAWN_CLEARANCE := 520.0
const PROP_BOUNDS_INSET := 96.0
const DRAW_ORDER_MIN := -4096
const DRAW_ORDER_MAX := 4095
const AMBIENT_TINT := Color(0.78, 0.74, 0.80)
const BIOME_CELL := 64.0


func _spawn_current_map_props(map: Node) -> void:
	if map == null:
		return

	var bounds := _find_map_bounds_rect(map)
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		bounds = FALLBACK_MAP_RECT

	var inner := bounds.grow(-PROP_BOUNDS_INSET)
	if inner.size.x <= 0.0 or inner.size.y <= 0.0:
		return

	var spawn_marker := map.find_child(PLAYER_SPAWN_POINT_NODE_NAME, true, false) as Node2D
	var spawn_center := spawn_marker.global_position if spawn_marker != null else inner.position + inner.size * 0.5

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(_current_map_scene_path)

	var modulate_node := CanvasModulate.new()
	modulate_node.name = "AmbientTint"
	modulate_node.color = AMBIENT_TINT
	map.add_child(modulate_node)

	_paint_biome_base(map, bounds, rng)
	_decorate_map_ground(map, bounds, spawn_center, rng)

	var props_root := Node2D.new()
	props_root.name = "Props"
	map.add_child(props_root)

	var placed: Array[Vector2] = []
	var attempts := 0
	var max_attempts := PROP_COUNT * 12

	while placed.size() < PROP_COUNT and attempts < max_attempts:
		attempts += 1
		var pos := Vector2(
			rng.randf_range(inner.position.x, inner.position.x + inner.size.x),
			rng.randf_range(inner.position.y, inner.position.y + inner.size.y)
		)
		if pos.distance_to(spawn_center) < PROP_SPAWN_CLEARANCE:
			continue
		var too_close := false
		for existing in placed:
			if existing.distance_to(pos) < PROP_MIN_SPACING:
				too_close = true
				break
		if too_close:
			continue

		var kind_roll := rng.randf()
		var kind := "tree"
		if kind_roll < 0.10:
			kind = "tombstone"
		elif kind_roll < 0.22:
			kind = "dead_tree"
		elif kind_roll < 0.34:
			kind = "rock"
		elif kind_roll < 0.46:
			kind = "mushroom"
		elif kind_roll < 0.60:
			kind = "bush"

		_spawn_procedural_prop(props_root, kind, pos, rng)
		placed.append(pos)


func _find_map_bounds_rect(map: Node) -> Rect2:
	if map == null:
		return Rect2()
	var stack: Array = [map]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.has_method("get_map_rect_global"):
			var rect = node.call("get_map_rect_global")
			if rect is Rect2:
				return rect
		for child in node.get_children():
			stack.append(child)
	return Rect2()


const PROP_PIXEL_SCALE := 4

func _spawn_procedural_prop(parent: Node2D, kind: String, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos

	var variant := rng.randi_range(0, 3)
	var texture := PixelProps.generate(kind, variant)

	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.centered = false
	sprite.offset = Vector2(-texture.get_width() * 0.5, -float(texture.get_height()))
	sprite.scale = Vector2(PROP_PIXEL_SCALE, PROP_PIXEL_SCALE)
	body.add_child(sprite)

	var collision_shape := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = PixelProps.collision_size_for(kind)
	collision_shape.shape = rect_shape
	collision_shape.position = PixelProps.collision_offset_for(kind)
	body.add_child(collision_shape)

	parent.add_child(body)

	var foot_y := pos.y + collision_shape.position.y + rect_shape.size.y * 0.5
	var z := clampi(int(round(foot_y)), DRAW_ORDER_MIN, DRAW_ORDER_MAX)
	sprite.z_as_relative = false
	sprite.z_index = z


func _get_map_biome() -> Dictionary:
	if _current_map_scene_path.find("map_2") >= 0:
		return {
			"left": Color(0.16, 0.30, 0.14),
			"right": Color(0.78, 0.66, 0.42),
			"left_pct": 0.20,
			"blend_pct": 0.30,
			"tuft": Color(0.30, 0.50, 0.24),
			"sand_hi": Color(0.92, 0.82, 0.56),
			"sand_lo": Color(0.58, 0.46, 0.26),
		}
	return {
		"left": Color(0.14, 0.30, 0.15),
		"right": Color(0.20, 0.38, 0.20),
		"left_pct": 0.0,
		"blend_pct": 1.0,
		"tuft": Color(0.36, 0.56, 0.28),
		"sand_hi": Color(0.32, 0.50, 0.26),
		"sand_lo": Color(0.10, 0.22, 0.10),
	}


func _paint_biome_base(map: Node, bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var biome := _get_map_biome()
	var biome_root := Node2D.new()
	biome_root.name = "BiomeGround"
	biome_root.z_as_relative = false
	biome_root.z_index = DRAW_ORDER_MIN + 100
	map.add_child(biome_root)

	var cols := int(ceil(bounds.size.x / BIOME_CELL)) + 1
	var rows := int(ceil(bounds.size.y / BIOME_CELL)) + 1
	var blend_start := float(biome["left_pct"])
	var blend_end := blend_start + float(biome["blend_pct"])

	for r in range(rows):
		for col in range(cols):
			var p := bounds.position + Vector2(float(col) * BIOME_CELL, float(r) * BIOME_CELL)
			var tx := float(col) / float(max(cols - 1, 1))
			var b: float = 0.0
			if tx <= blend_start:
				b = 0.0
			elif tx >= blend_end:
				b = 1.0
			else:
				b = (tx - blend_start) / maxf(blend_end - blend_start, 0.001)
			b = clampf(b + rng.randf_range(-0.12, 0.12), 0.0, 1.0)
			var base: Color = (biome["left"] as Color).lerp(biome["right"] as Color, b)
			base = base.lerp(Color(base.r, base.g, base.b).darkened(0.18), rng.randf_range(0.0, 0.5))

			var cell := Polygon2D.new()
			cell.color = base
			cell.polygon = PackedVector2Array([
				p,
				p + Vector2(BIOME_CELL, 0),
				p + Vector2(BIOME_CELL, BIOME_CELL),
				p + Vector2(0, BIOME_CELL),
			])
			biome_root.add_child(cell)

			if rng.randf() < 0.40:
				var spot := Polygon2D.new()
				var spot_color: Color
				if b < 0.5:
					spot_color = biome["tuft"] as Color
					spot_color.a = 0.55
				else:
					spot_color = (biome["sand_hi"] as Color).lerp(biome["sand_lo"] as Color, rng.randf())
					spot_color.a = 0.65
				spot.color = spot_color
				var cx := p.x + rng.randf_range(8.0, BIOME_CELL - 8.0)
				var cy := p.y + rng.randf_range(8.0, BIOME_CELL - 8.0)
				var rx := rng.randf_range(6.0, 14.0)
				var ry := rng.randf_range(4.0, 9.0)
				var segs := 8
				var pts := PackedVector2Array()
				for s in range(segs):
					var ang := TAU * float(s) / float(segs)
					var j := rng.randf_range(0.8, 1.2)
					pts.append(Vector2(cx + cos(ang) * rx * j, cy + sin(ang) * ry * j))
				spot.polygon = pts
				biome_root.add_child(spot)


func _decorate_map_ground(map: Node, bounds: Rect2, spawn_center: Vector2, rng: RandomNumberGenerator) -> void:
	var decor := Node2D.new()
	decor.name = "GroundDecor"
	decor.z_as_relative = false
	decor.z_index = DRAW_ORDER_MIN + 200
	map.add_child(decor)

	# Dark grass / dirt patches scattered across the floor.
	var patch_count := 70
	for i in range(patch_count):
		var pos := Vector2(
			rng.randf_range(bounds.position.x, bounds.position.x + bounds.size.x),
			rng.randf_range(bounds.position.y, bounds.position.y + bounds.size.y)
		)
		var is_dirt := rng.randf() < 0.42
		var patch := Polygon2D.new()
		if is_dirt:
			patch.color = Color(0.18, 0.13, 0.09, 0.55).lerp(Color(0.10, 0.07, 0.05, 0.6), rng.randf())
		else:
			patch.color = Color(0.07, 0.18, 0.09, 0.55).lerp(Color(0.04, 0.10, 0.05, 0.65), rng.randf())
		var rx := rng.randf_range(60.0, 140.0)
		var ry := rng.randf_range(40.0, 90.0)
		var segments := 12
		var pts := PackedVector2Array()
		for s in range(segments):
			var ang := TAU * float(s) / float(segments)
			var j := rng.randf_range(0.7, 1.25)
			pts.append(pos + Vector2(cos(ang) * rx, sin(ang) * ry) * j)
		patch.polygon = pts
		decor.add_child(patch)

	# Stone path radiating from spawn toward each map edge.
	_build_stone_paths(decor, bounds, spawn_center, rng)

	# Distant mountain backdrop ringing the map (outside playable bounds).
	_build_border_mountains(decor, bounds, rng)

	# Corner vignettes for mood.
	_build_corner_vignettes(decor, bounds)


func _build_stone_paths(parent: Node2D, bounds: Rect2, spawn_center: Vector2, rng: RandomNumberGenerator) -> void:
	var edges := [
		Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + 40.0),
		Vector2(bounds.position.x + bounds.size.x * 0.5, bounds.position.y + bounds.size.y - 40.0),
		Vector2(bounds.position.x + 40.0, bounds.position.y + bounds.size.y * 0.5),
		Vector2(bounds.position.x + bounds.size.x - 40.0, bounds.position.y + bounds.size.y * 0.5),
	]
	for target_variant in edges:
		var target: Vector2 = target_variant
		_build_stone_path_segment(parent, spawn_center, target, rng)


func _build_stone_path_segment(parent: Node2D, from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> void:
	var dir := (to - from)
	var dist := dir.length()
	if dist <= 1.0:
		return
	var step := 22.0
	var steps := int(dist / step)
	var perp := dir.orthogonal().normalized()
	var base_color := Color(0.40, 0.36, 0.30)
	for i in range(steps):
		var t := float(i) / float(max(steps - 1, 1))
		var wobble := perp * sin(t * PI * 3.0 + rng.randf() * 0.4) * 14.0
		var center := from.lerp(to, t) + wobble
		var stone := Polygon2D.new()
		stone.color = base_color.lerp(Color(0.55, 0.50, 0.42), rng.randf()).darkened(rng.randf_range(0.0, 0.15))
		var rx := rng.randf_range(10.0, 16.0)
		var ry := rng.randf_range(7.0, 11.0)
		var segs := 7
		var pts := PackedVector2Array()
		for s in range(segs):
			var ang := TAU * float(s) / float(segs)
			var j := rng.randf_range(0.82, 1.18)
			pts.append(center + Vector2(cos(ang) * rx, sin(ang) * ry) * j)
		stone.polygon = pts
		parent.add_child(stone)


func _build_border_mountains(parent: Node2D, bounds: Rect2, rng: RandomNumberGenerator) -> void:
	var rock_dark := Color(0.10, 0.10, 0.16)
	var rock_mid := Color(0.22, 0.22, 0.30)
	var rock_light := Color(0.42, 0.42, 0.50)
	var snow := Color(0.92, 0.93, 0.96)
	var edges := [
		{
			"from": Vector2(bounds.position.x - 120.0, bounds.position.y),
			"to": Vector2(bounds.position.x + bounds.size.x + 120.0, bounds.position.y),
			"outward": Vector2(0, -1),
		},
		{
			"from": Vector2(bounds.position.x - 120.0, bounds.position.y + bounds.size.y),
			"to": Vector2(bounds.position.x + bounds.size.x + 120.0, bounds.position.y + bounds.size.y),
			"outward": Vector2(0, 1),
		},
		{
			"from": Vector2(bounds.position.x, bounds.position.y - 120.0),
			"to": Vector2(bounds.position.x, bounds.position.y + bounds.size.y + 120.0),
			"outward": Vector2(-1, 0),
		},
		{
			"from": Vector2(bounds.position.x + bounds.size.x, bounds.position.y - 120.0),
			"to": Vector2(bounds.position.x + bounds.size.x, bounds.position.y + bounds.size.y + 120.0),
			"outward": Vector2(1, 0),
		},
	]

	for edge_variant in edges:
		var edge: Dictionary = edge_variant
		var from_pos: Vector2 = edge["from"]
		var to_pos: Vector2 = edge["to"]
		var outward: Vector2 = edge["outward"]
		var along := to_pos - from_pos
		var length := along.length()
		if length <= 0.0:
			continue
		var dir := along / length
		var spacing := 64.0
		var n := maxi(int(length / spacing), 1)

		# Back layer: large, dark, overlapping bases.
		for i in range(n):
			var t := (float(i) + 0.5) / float(n)
			var center := from_pos + along * t + dir * rng.randf_range(-18.0, 18.0)
			var base_w := rng.randf_range(160.0, 240.0)
			var height := rng.randf_range(150.0, 240.0)
			var tip := center + outward * height
			var p1 := center - dir * (base_w * 0.5)
			var p2 := center + dir * (base_w * 0.5)
			var peak := Polygon2D.new()
			peak.color = rock_dark.lerp(rock_mid, rng.randf_range(0.0, 0.4))
			peak.polygon = PackedVector2Array([p1, tip, p2])
			peak.z_as_relative = false
			peak.z_index = -12
			parent.add_child(peak)

		# Front layer: smaller, brighter, with snow caps.
		for i in range(n):
			var t2 := (float(i) + rng.randf_range(0.2, 0.8)) / float(n)
			var center2 := from_pos + along * t2
			var base_w2 := rng.randf_range(90.0, 150.0)
			var height2 := rng.randf_range(90.0, 160.0)
			var tip2 := center2 + outward * height2
			var p1b := center2 - dir * (base_w2 * 0.5)
			var p2b := center2 + dir * (base_w2 * 0.5)
			var peak2 := Polygon2D.new()
			peak2.color = rock_mid.lerp(rock_light, rng.randf_range(0.1, 0.5))
			peak2.polygon = PackedVector2Array([p1b, tip2, p2b])
			peak2.z_as_relative = false
			peak2.z_index = -10
			parent.add_child(peak2)

			if rng.randf() < 0.7:
				var cap_h := height2 * rng.randf_range(0.22, 0.38)
				var cap_base := tip2 - outward * cap_h
				var cap_l := cap_base - dir * (base_w2 * 0.18)
				var cap_r := cap_base + dir * (base_w2 * 0.18)
				var cap := Polygon2D.new()
				cap.color = snow
				cap.polygon = PackedVector2Array([cap_l, tip2, cap_r])
				cap.z_as_relative = false
				cap.z_index = -9
				parent.add_child(cap)


func _build_corner_vignettes(parent: Node2D, bounds: Rect2) -> void:
	var corners := [
		bounds.position,
		bounds.position + Vector2(bounds.size.x, 0),
		bounds.position + Vector2(0, bounds.size.y),
		bounds.position + bounds.size,
	]
	for c_variant in corners:
		var c: Vector2 = c_variant
		var vignette := Polygon2D.new()
		vignette.color = Color(0.0, 0.0, 0.0, 0.45)
		var rx := 360.0
		var ry := 260.0
		var segs := 14
		var pts := PackedVector2Array()
		for s in range(segs):
			var ang := TAU * float(s) / float(segs)
			pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
		vignette.polygon = pts
		vignette.z_index = -10
		parent.add_child(vignette)



func _spawn_initial_map_enemies() -> void:
	for index in range(_enemy_spawn_blocks.size()):
		while _get_enemy_count_for_block(index) < int(_enemy_spawn_blocks[index]["count"]):
			_spawn_enemy_from_block(index)


func _update_enemy_spawn_blocks(delta: float) -> void:
	for index in range(_enemy_spawn_blocks.size()):
		var block := _enemy_spawn_blocks[index]
		var target_count := int(block["count"])
		if _get_enemy_count_for_block(index) >= target_count:
			block["respawn_time"] = 0.0
			_enemy_spawn_blocks[index] = block
			continue

		block["respawn_time"] = maxf(float(block["respawn_time"]) - delta, 0.0)
		if float(block["respawn_time"]) <= 0.0:
			_spawn_enemy_from_block(index)
			block["respawn_time"] = float(block["respawn_seconds"])
		_enemy_spawn_blocks[index] = block


func _spawn_enemy_from_block(block_index: int) -> void:
	if block_index < 0 or block_index >= _enemy_spawn_blocks.size():
		return

	var block := _enemy_spawn_blocks[block_index]
	var enemy_name := "Enemy%d" % _next_enemy_id
	_next_enemy_id += 1
	var spawn_position := _get_random_walkable_spawn_position()

	if multiplayer.multiplayer_peer == null:
		spawn_enemy(enemy_name, spawn_position, str(block["enemy_id"]), block_index)
	else:
		spawn_enemy.rpc(enemy_name, spawn_position, str(block["enemy_id"]), block_index)


@rpc("authority", "call_local", "reliable")
func spawn_enemy(enemy_name: String, spawn_position: Vector2, enemy_id: String, spawn_block_index: int = -1) -> void:
	if enemies.has_node(enemy_name):
		return

	var enemy := ENEMY_SCENE.instantiate()
	enemy.name = enemy_name
	enemy.enemy_id = enemy_id
	enemy.position = spawn_position
	enemy.set_meta("spawn_block_index", spawn_block_index)
	enemy.set_multiplayer_authority(1)
	enemies.add_child(enemy)


func _get_enemy_count_for_block(block_index: int) -> int:
	var count := 0
	for enemy in enemies.get_children():
		if not enemy.is_queued_for_deletion() and int(enemy.get_meta("spawn_block_index", -1)) == block_index:
			count += 1
	return count


func _clear_enemies() -> void:
	for enemy in enemies.get_children():
		enemies.remove_child(enemy)
		enemy.queue_free()


func _get_random_walkable_spawn_position() -> Vector2:
	var map_rect := _get_current_map_rect()
	for _attempt in range(RANDOM_SPAWN_ATTEMPTS):
		var candidate := Vector2(
			_rng.randf_range(map_rect.position.x, map_rect.end.x),
			_rng.randf_range(map_rect.position.y, map_rect.end.y)
		)
		if _is_spawn_position_walkable(candidate):
			return candidate

	return map_rect.get_center()


func _get_current_map_rect() -> Rect2:
	if map_root == null or map_root.get_child_count() <= 0:
		return FALLBACK_MAP_RECT

	var current_map := map_root.get_child(0)
	var ground := current_map.get_node_or_null("Ground") as ColorRect
	if ground == null:
		return FALLBACK_MAP_RECT

	return Rect2(ground.global_position, ground.size)


func get_current_map_rect() -> Rect2:
	return _get_current_map_rect()


func _is_spawn_position_walkable(candidate: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = candidate
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.collision_mask = 0xffffffff

	var hits := get_world_2d().direct_space_state.intersect_point(query, 1)
	return hits.is_empty()
