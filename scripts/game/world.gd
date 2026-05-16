extends Node2D


func _ready() -> void:
	_build_map()


func _build_map() -> void:
	var ground := ColorRect.new()
	ground.color = Color(0.18, 0.28, 0.18)
	ground.size = Vector2(2000, 1400)
	ground.position = Vector2(-700, -450)
	add_child(ground)
	move_child(ground, 0)

	for i in range(12):
		var rock := StaticBody2D.new()
		rock.position = Vector2(130 + (i % 4) * 190, 120 + (i / 4) * 180)
		add_child(rock)

		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(54, 42)
		shape.shape = rect
		rock.add_child(shape)

		var visual := ColorRect.new()
		visual.color = Color(0.24, 0.24, 0.22)
		visual.size = rect.size
		visual.position = -rect.size / 2.0
		rock.add_child(visual)
