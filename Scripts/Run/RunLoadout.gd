class_name RunLoadoutState
extends Node

const SLOT_COUNT: int = 2

var active_slot_index: int = 0
var _weapon_scenes: Array[PackedScene] = [null, null]
var _has_loadout: bool = false


func capture_from(weapon_component: WeaponComponent) -> void:
	if weapon_component == null:
		push_error("RunLoadout cannot capture a null WeaponComponent.")
		return

	for slot: int in range(SLOT_COUNT):
		_weapon_scenes[slot] = weapon_component.get_weapon_scene_in_slot(slot)
	active_slot_index = weapon_component.active_slot_index
	_has_loadout = true


func apply_to(weapon_component: WeaponComponent) -> void:
	if weapon_component == null or not _has_loadout:
		return

	weapon_component.clear_all_weapons()
	for slot: int in range(SLOT_COUNT):
		var weapon_scene: PackedScene = _weapon_scenes[slot]
		if weapon_scene != null:
			weapon_component.equip_weapon(weapon_scene, slot)

	if weapon_component.get_weapon_in_slot(active_slot_index) != null:
		weapon_component.set_active_slot(active_slot_index)


func has_loadout() -> bool:
	return _has_loadout


func clear_loadout() -> void:
	for slot: int in range(SLOT_COUNT):
		_weapon_scenes[slot] = null
	active_slot_index = 0
	_has_loadout = false
