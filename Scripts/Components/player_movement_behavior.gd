class_name PlayerMovementBehavior
extends MovementBehavior

func _get_velocity(speed: float) -> Vector2:
	var direction := Input.get_vector(
		"MOVE_LEFT",
		"MOVE_RIGHT",
		"MOVE_UP",
        "MOVE_DOWN"
	)
	
	return direction * speed

func _get_rotation(origin: Vector2, target: Vector2) -> float:
	return origin.direction_to(target).angle() + PI / 2.0