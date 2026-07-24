class_name WeaponComponent
extends Node

signal weapon_equipped(slot: int, weapon: Weapon)
signal weapon_switched(active_weapon: Weapon, secondary_weapon: Weapon)
signal loadout_changed(active_weapon: Weapon, secondary_weapon: Weapon)

const SLOT_COUNT: int = 2

@export var weapon_holder: Node2D
@export_range(0, 1, 1) var active_slot_index: int = 0
@export var starting_weapon_scenes: Array[PackedScene] = []

var current_weapon: Weapon
var secondary_weapon: Weapon

var _weapons: Array[Weapon] = [null, null]
var _weapon_scenes: Array[PackedScene] = [null, null]
var _cooldowns: Array[float] = [0.0, 0.0]
var _attack_was_pressed: bool = false


func _ready() -> void:
	if weapon_holder == null:
		push_error("WeaponComponent requires a WeaponHolder Node2D.")
		return

	var discovered_slot: int = 0
	for child: Node in weapon_holder.get_children():
		if not child is Weapon:
			continue

		if discovered_slot >= SLOT_COUNT:
			push_warning(
				"WeaponHolder contains more than two Weapon nodes; '%s' was removed."
				% child.name
			)
			child.free()
			continue

		_weapons[discovered_slot] = child as Weapon
		if discovered_slot < starting_weapon_scenes.size():
			_weapon_scenes[discovered_slot] = starting_weapon_scenes[
				discovered_slot
			]
		discovered_slot += 1

	_refresh_weapon_states()
	loadout_changed.emit(current_weapon, secondary_weapon)


func _physics_process(delta: float) -> void:
	for slot: int in range(SLOT_COUNT):
		_cooldowns[slot] = maxf(_cooldowns[slot] - delta, 0.0)


func equip_weapon(weapon_scene: PackedScene, slot: int = 0) -> bool:
	if not _is_valid_slot(slot):
		push_error("WeaponComponent slot must be 0 or 1; received %d." % slot)
		return false

	if weapon_holder == null:
		push_error("WeaponComponent cannot equip a weapon without a WeaponHolder.")
		return false

	if weapon_scene == null:
		push_error("WeaponComponent cannot equip a null PackedScene.")
		return false

	var weapon_node: Node = weapon_scene.instantiate()
	var new_weapon: Weapon = weapon_node as Weapon
	if new_weapon == null:
		weapon_node.free()
		push_error("Equipped scene root must extend Weapon.")
		return false

	var replaced_weapon: Weapon = _weapons[slot]
	if replaced_weapon != null and is_instance_valid(replaced_weapon):
		replaced_weapon.deactivate()
		replaced_weapon.free()

	weapon_holder.add_child(new_weapon)
	_weapons[slot] = new_weapon
	_weapon_scenes[slot] = weapon_scene
	_cooldowns[slot] = 0.0
	_refresh_weapon_states()
	weapon_equipped.emit(slot, new_weapon)
	loadout_changed.emit(current_weapon, secondary_weapon)
	return true


func switch_weapon() -> bool:
	var other_slot: int = 1 - active_slot_index
	var other_weapon: Weapon = _weapons[other_slot]

	if other_weapon == null or not is_instance_valid(other_weapon):
		push_warning(
			"WeaponComponent cannot switch because slot %d is empty." % other_slot
		)
		return false

	active_slot_index = other_slot
	_refresh_weapon_states()
	weapon_switched.emit(current_weapon, secondary_weapon)
	return true


func get_active_weapon() -> Weapon:
	return current_weapon


func get_secondary_weapon() -> Weapon:
	return secondary_weapon


func get_weapon_in_slot(slot: int) -> Weapon:
	if not _is_valid_slot(slot):
		push_error("WeaponComponent slot must be 0 or 1; received %d." % slot)
		return null

	return _weapons[slot]


func get_weapon_scene_in_slot(slot: int) -> PackedScene:
	if not _is_valid_slot(slot):
		push_error("WeaponComponent slot must be 0 or 1; received %d." % slot)
		return null
	return _weapon_scenes[slot]


func get_first_empty_slot() -> int:
	for slot: int in range(SLOT_COUNT):
		var weapon: Weapon = _weapons[slot]
		if weapon == null or not is_instance_valid(weapon):
			return slot
	return -1


func get_equipped_weapon_count() -> int:
	var count: int = 0
	for weapon: Weapon in _weapons:
		if weapon != null and is_instance_valid(weapon):
			count += 1
	return count


func clear_all_weapons() -> void:
	for slot: int in range(SLOT_COUNT):
		var weapon: Weapon = _weapons[slot]
		if weapon != null and is_instance_valid(weapon):
			weapon.deactivate()
			weapon.free()
		_weapons[slot] = null
		_weapon_scenes[slot] = null
		_cooldowns[slot] = 0.0

	active_slot_index = 0
	_attack_was_pressed = false
	_refresh_weapon_states()
	loadout_changed.emit(current_weapon, secondary_weapon)


func set_active_slot(slot: int) -> bool:
	if not _is_valid_slot(slot):
		push_error("WeaponComponent slot must be 0 or 1; received %d." % slot)
		return false
	if _weapons[slot] == null or not is_instance_valid(_weapons[slot]):
		push_warning("WeaponComponent cannot activate empty slot %d." % slot)
		return false

	active_slot_index = slot
	_refresh_weapon_states()
	weapon_switched.emit(current_weapon, secondary_weapon)
	return true


func handle_attack_input(
	owner: Node2D,
	is_pressed: bool,
	aim_position: Vector2,
	aim_direction: Vector2 = Vector2.ZERO
) -> bool:
	var weapon_data: WeaponData = _get_active_data()
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

	var active_weapon: Weapon = get_active_weapon()
	if active_weapon == null or not is_instance_valid(active_weapon):
		push_warning("WeaponComponent on '%s' has no active Weapon." % owner.name)
		return false

	var weapon_data: WeaponData = active_weapon.data
	if weapon_data == null:
		push_warning("Weapon '%s' has no WeaponData assigned." % active_weapon.name)
		return false

	if weapon_data.attack_behavior == null:
		push_error("WeaponData '%s' has no AttackBehavior assigned." % weapon_data.weapon_name)
		return false

	if active_weapon.muzzle == null:
		push_error("Weapon '%s' has no Muzzle Marker2D assigned." % active_weapon.name)
		return false

	if weapon_data.attacks_per_second <= 0.0:
		push_error(
			"WeaponData '%s' must have attacks_per_second greater than zero."
			% weapon_data.weapon_name
		)
		return false

	if _cooldowns[active_slot_index] > 0.0:
		return false

	var attack_position: Vector2 = active_weapon.get_muzzle_position()
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
	_cooldowns[active_slot_index] = attack_interval
	active_weapon.play_fire_effects()
	return true


func attack(owner: Node2D) -> void:
	var active_weapon: Weapon = get_active_weapon()
	if active_weapon == null or not is_instance_valid(active_weapon):
		push_error("WeaponComponent cannot use attack() without an active Weapon.")
		return

	var fallback_direction: Vector2 = active_weapon.get_muzzle_direction()
	try_attack(
		owner,
		active_weapon.get_muzzle_position() + fallback_direction,
		fallback_direction
	)


func get_attack_origin() -> Marker2D:
	var active_weapon: Weapon = get_active_weapon()
	if active_weapon == null or not is_instance_valid(active_weapon):
		return null

	return active_weapon.muzzle


func _refresh_weapon_states() -> void:
	current_weapon = _weapons[active_slot_index]
	secondary_weapon = _weapons[1 - active_slot_index]

	for slot: int in range(SLOT_COUNT):
		var weapon: Weapon = _weapons[slot]
		if weapon == null or not is_instance_valid(weapon):
			continue

		if slot == active_slot_index:
			weapon.activate()
		else:
			weapon.deactivate()


func _get_active_data() -> WeaponData:
	var active_weapon: Weapon = get_active_weapon()
	if active_weapon == null or not is_instance_valid(active_weapon):
		return null

	return active_weapon.data


func _is_valid_slot(slot: int) -> bool:
	return slot >= 0 and slot < SLOT_COUNT
