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
		if Input.is_action_just_pressed(&"CHANGE_WEAPON"):
			weapon_component.switch_weapon()

		weapon_component.handle_attack_input(
			self,
			Input.is_action_pressed(&"SHOOT"),
			aim_position
		)

	move_and_slide()
