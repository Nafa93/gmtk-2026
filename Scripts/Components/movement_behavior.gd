class_name MovementBehavior
extends Node

func _get_velocity(speed: float) -> Vector2:
	print("Missing get velocity implementation", speed)
	return Vector2()

func _get_rotation(origin: Vector2, target: Vector2) -> float:
	print("Missing get rotation implementation", origin, target)
	return 0.0
