class_name DoppelgangerMovementBehavior
extends MovementBehavior

func _get_velocity(speed: float) -> Vector2:
	return Vector2()
	
func _get_rotation(origin: Vector2, target: Vector2) -> float:
	return origin.direction_to(target).angle() + PI / 2.0
