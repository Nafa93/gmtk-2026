class_name PlayerController
extends CharacterBody2D

@export var movement_component: MovementComponent
@export var health_component: HealthComponent
@export var weapon_component: WeaponComponent
@export var character_sprite: AnimatedSprite2D

var _nearby_interactables: Array[Node2D] = []


func _ready() -> void:
	var run_loadout := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_loadout != null and run_loadout.has_loadout():
		run_loadout.apply_to(weapon_component)


func _physics_process(_delta: float) -> void:
	velocity = movement_component.get_velocity()

	var aim_position: Vector2 = get_global_mouse_position()
	_update_character_visual(aim_position)

	if weapon_component != null:
		weapon_component.update_aim(self, aim_position)
		if Input.is_action_just_pressed(&"CHANGE_WEAPON"):
			weapon_component.switch_weapon()

		weapon_component.handle_attack_input(
			self,
			Input.is_action_pressed(&"SHOOT"),
			aim_position
		)

	if Input.is_action_just_pressed(&"INTERACT"):
		_interact_with_nearest()

	move_and_slide()


func _update_character_visual(aim_position: Vector2) -> void:
	if character_sprite == null:
		return

	character_sprite.rotation = 0.0
	character_sprite.flip_h = aim_position.x < global_position.x

	var desired_animation: StringName = (
		&"idle" if velocity.is_zero_approx() else &"walk"
	)
	if character_sprite.animation != desired_animation:
		character_sprite.play(desired_animation)


func register_interactable(interactable: Node2D) -> void:
	if interactable == null or interactable in _nearby_interactables:
		return
	_nearby_interactables.append(interactable)


func unregister_interactable(interactable: Node2D) -> void:
	_nearby_interactables.erase(interactable)


func _interact_with_nearest() -> void:
	var nearest: Node2D
	var nearest_distance_squared: float = INF

	for index: int in range(_nearby_interactables.size() - 1, -1, -1):
		var candidate: Node2D = _nearby_interactables[index]
		if candidate == null or not is_instance_valid(candidate):
			_nearby_interactables.remove_at(index)
			continue
		if not candidate.has_method(&"interact"):
			continue

		var distance_squared: float = global_position.distance_squared_to(
			candidate.global_position
		)
		if distance_squared < nearest_distance_squared:
			nearest = candidate
			nearest_distance_squared = distance_squared

	if nearest != null:
		nearest.call(&"interact", self)
