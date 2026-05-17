extends RefCounted


static func get_definition(skill_name: String) -> Dictionary:
	match skill_name:
		"fireball":
			return {
				"title": "Fireball",
				"cost": "2",
				"description": "Drag upward\nto cast",
				"art_color": Color(0.82, 0.22, 0.04, 1.0),
			}
		_:
			return {
				"title": "Strike",
				"cost": "1",
				"description": "Drag upward\nto attack",
				"art_color": Color(0.32, 0.08, 0.08, 1.0),
			}
