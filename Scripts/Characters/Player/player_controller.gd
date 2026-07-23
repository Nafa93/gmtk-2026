class_name PlayerController
extends CharacterBody2D

@export var movement_component: MovementComponent
@export var health_component: HealthComponent
@export var weapon_component: WeaponComponent


func _physics_process(_delta: float) -> void:
	velocity = movement_component.get_velocity()

	var aim_position: Vector2 = get_global_mouse_position()
	rotation = movement_component.get_rotation(global_position, aim_position)

	if weapon_component != null:
		var aim_direction: Vector2 = Vector2.ZERO
		var attack_origin: Marker2D = weapon_component.get_attack_origin()
		if attack_origin != null:
			aim_direction = attack_origin.global_position.direction_to(aim_position)

		weapon_component.handle_attack_input(
			self,
			Input.is_action_pressed(&"SHOOT"),
			aim_position,
			aim_direction
		)

	move_and_slide()
