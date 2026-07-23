class_name WeaponComponent
extends Node

@export var weapon: WeaponData:
	set(value):
		weapon = value
		_cooldown_remaining = 0.0
		_attack_was_pressed = false

@export var muzzle: Marker2D

var _cooldown_remaining: float = 0.0
var _attack_was_pressed: bool = false


func _physics_process(delta: float) -> void:
	_cooldown_remaining = maxf(_cooldown_remaining - delta, 0.0)


func handle_attack_input(
	owner: Node2D,
	is_pressed: bool,
	aim_position: Vector2,
	aim_direction: Vector2 = Vector2.ZERO
) -> bool:
	var should_try_attack: bool = false

	if weapon == null:
		should_try_attack = is_pressed and not _attack_was_pressed
	elif weapon.automatic:
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

	if weapon == null:
		push_warning("WeaponComponent on '%s' has no WeaponData assigned." % owner.name)
		return false

	if weapon.attack_behavior == null:
		push_error("WeaponData '%s' has no AttackBehavior assigned." % weapon.weapon_name)
		return false

	if muzzle == null:
		push_error("WeaponComponent on '%s' has no muzzle Marker2D assigned." % owner.name)
		return false

	if weapon.attacks_per_second <= 0.0:
		push_error(
			"WeaponData '%s' must have attacks_per_second greater than zero."
			% weapon.weapon_name
		)
		return false

	if _cooldown_remaining > 0.0:
		return false

	var resolved_direction: Vector2 = aim_direction.normalized()
	if resolved_direction.is_zero_approx():
		resolved_direction = muzzle.global_position.direction_to(aim_position)

	if resolved_direction.is_zero_approx():
		push_warning(
			"WeaponComponent on '%s' cannot attack with a zero-length aim direction."
			% owner.name
		)
		return false

	weapon.attack_behavior.attack(
		owner,
		weapon,
		muzzle.global_position,
		resolved_direction
	)

	var attack_interval: float = 1.0 / weapon.attacks_per_second
	_cooldown_remaining = attack_interval
	return true


func attack(owner: Node2D) -> void:
	if muzzle == null:
		push_error("WeaponComponent cannot use attack() without a muzzle Marker2D.")
		return

	var fallback_direction: Vector2 = muzzle.global_transform.x.normalized()
	try_attack(
		owner,
		muzzle.global_position + fallback_direction,
		fallback_direction
	)


func get_attack_origin() -> Marker2D:
	return muzzle
