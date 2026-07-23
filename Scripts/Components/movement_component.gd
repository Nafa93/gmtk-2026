class_name MovementComponent
extends Node

@export var speed: float = 40.0
@export var behavior: MovementBehavior

func get_velocity() -> Vector2:
	return behavior._get_velocity(speed)

func get_rotation(origin: Vector2, target: Vector2) -> float:
	return behavior._get_rotation(origin, target)
