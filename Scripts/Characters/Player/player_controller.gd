class_name PlayerController
extends CharacterBody2D

@export var movement_component: MovementComponent
@export var health_component: HealthComponent

func _process(delta: float) -> void:
	velocity = movement_component.get_velocity()
	
	rotation = movement_component.get_rotation(global_position, get_global_mouse_position())

	move_and_slide()
