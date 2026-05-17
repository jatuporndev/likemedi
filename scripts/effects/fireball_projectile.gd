extends Area2D

@export var speed := 520.0
@export var lifetime_seconds := 0.65
@export var fps := 18.0
@export var frame_count := 8

@onready var sprite: Sprite2D = $Sprite2D

var _direction := Vector2.RIGHT
var _time := 0.0
var _anim_time := 0.0
var _damage := 0
var _caster_peer_id := -1
var _caster_node: Node2D


func setup(origin: Vector2, direction: Vector2, damage: int, caster_peer_id: int, caster_node: Node2D = null) -> void:
	global_position = origin
	_direction = direction.normalized()
	if _direction.length_squared() <= 0.0:
		_direction = Vector2.RIGHT
	_damage = max(damage, 0)
	_caster_peer_id = caster_peer_id
	_caster_node = caster_node
	rotation = _direction.angle()


func _ready() -> void:
	sprite.hframes = frame_count
	sprite.vframes = 1
	sprite.frame = 0

	# Only the server (or offline mode) applies damage; clients still show visuals.
	monitoring = multiplayer.multiplayer_peer == null or multiplayer.is_server()
	monitorable = monitoring

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_time += delta
	if _time >= lifetime_seconds:
		queue_free()
		return

	position += _direction * speed * delta

	_anim_time += delta * fps
	if frame_count > 0:
		sprite.frame = int(_anim_time) % frame_count


func _on_body_entered(body: Node) -> void:
	if not (multiplayer.multiplayer_peer == null or multiplayer.is_server()):
		return
	if body == null or not is_instance_valid(body):
		return
	if body == _caster_node:
		return
	if _caster_peer_id >= 0 and str(body.name) == str(_caster_peer_id):
		return
	if not body.has_method("_take_test_damage"):
		return

	if _damage > 0:
		body.call("_take_test_damage", _damage, _caster_node)
	queue_free()

