class_name WeaponComponent
extends Node

@export var weapon_holder: Node2D

var current_weapon: Weapon

var _cooldown_remaining: float = 0.0
var _attack_was_pressed: bool = false


func _ready() -> void:
	if weapon_holder == null:
		push_error("WeaponComponent requires a WeaponHolder Node2D.")
		return

	for child: Node in weapon_holder.get_children():
		if child is Weapon:
			current_weapon = child as Weapon
			return


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func equip_weapon(scene: PackedScene) -> bool:
	if weapon_holder == null:
		push_error("WeaponComponent cannot equip a weapon without a WeaponHolder.")
		return false

	if scene == null:
		push_error("WeaponComponent cannot equip a null PackedScene.")
		return false

	var weapon_node: Node = scene.instantiate()
	var new_weapon: Weapon = weapon_node as Weapon
	if new_weapon == null:
		weapon_node.free()
		push_error("Equipped scene root must extend Weapon.")
		return false

	if current_weapon != null and is_instance_valid(current_weapon):
		if current_weapon.get_parent() != null:
			current_weapon.get_parent().remove_child(current_weapon)
		current_weapon.queue_free()

	weapon_holder.add_child(new_weapon)
	current_weapon = new_weapon
	_cooldown_remaining = 0.0
	_attack_was_pressed = false
	return true


func handle_attack_input(
	owner: Node2D,
	is_pressed: bool,
	aim_position: Vector2,
	aim_direction: Vector2 = Vector2.ZERO
) -> bool:
	var weapon_data: WeaponData = _get_current_data()
	var should_try_attack: bool = false

	if weapon_data == null:
		should_try_attack = is_pressed and not _attack_was_pressed
	elif weapon_data.automatic:
		should_try_attack = is_pressed
	else:
		should_try_attack = is_pressed and not _attack_was_pressed

	_attack_was_pressed = is_pressed

	if not should_try_attack:
		return false

	return try_attack(owner, aim_position, aim_direction)


func try_attack(
	owner: Node2D,
	aim_position: Vector2,
	aim_direction: Vector2 = Vector2.ZERO
) -> bool:
	if owner == null:
		push_error("WeaponComponent cannot attack without an owner.")
		return false

	if current_weapon == null or not is_instance_valid(current_weapon):
		push_warning("WeaponComponent on '%s' has no Weapon equipped." % owner.name)
		return false

	var weapon_data: WeaponData = current_weapon.data
	if weapon_data == null:
		push_warning("Weapon '%s' has no WeaponData assigned." % current_weapon.name)
		return false

	if weapon_data.attack_behavior == null:
		push_error("WeaponData '%s' has no AttackBehavior assigned." % weapon_data.weapon_name)
		return false

	if current_weapon.muzzle == null:
		push_error("Weapon '%s' has no Muzzle Marker2D assigned." % current_weapon.name)
		return false

	if weapon_data.attacks_per_second <= 0.0:
		push_error(
			"WeaponData '%s' must have attacks_per_second greater than zero."
			% weapon_data.weapon_name
		)
		return false

	if _cooldown_remaining > 0.0:
		return false

	var attack_position: Vector2 = current_weapon.get_muzzle_position()
	var resolved_direction: Vector2 = aim_direction.normalized()
	if resolved_direction.is_zero_approx():
		resolved_direction = attack_position.direction_to(aim_position)

	if resolved_direction.is_zero_approx():
		push_warning(
			"WeaponComponent on '%s' cannot attack with a zero-length aim direction."
			% owner.name
		)
		return false

	weapon_data.attack_behavior.attack(
		owner,
		weapon_data,
		attack_position,
		resolved_direction
	)

	var attack_interval: float = 1.0 / weapon_data.attacks_per_second
	_cooldown_remaining = attack_interval
	current_weapon.play_fire_effects()
	return true


func attack(owner: Node2D) -> void:
	if current_weapon == null or not is_instance_valid(current_weapon):
		push_error("WeaponComponent cannot use attack() without an equipped Weapon.")
		return

	var fallback_direction: Vector2 = current_weapon.get_muzzle_direction()
	try_attack(
		owner,
		current_weapon.get_muzzle_position() + fallback_direction,
		fallback_direction
	)


func get_attack_origin() -> Marker2D:
	if current_weapon == null or not is_instance_valid(current_weapon):
		return null

	return current_weapon.muzzle


func _get_current_data() -> WeaponData:
	if current_weapon == null or not is_instance_valid(current_weapon):
		return null

	return current_weapon.data
