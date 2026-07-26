class_name RunLoadoutState
extends Node

const SLOT_COUNT: int = 2

var active_slot_index: int = 0
var _weapon_scenes: Array[PackedScene] = [null, null]
var _has_loadout: bool = false

var current_time: float = 0.0
var maximum_time: float = 60.0
var _has_time_state: bool = false

var preparation_started_at: float = 0.0
var time_at_boss_start: float = 0.0
var boss_started_at: float = 0.0
var total_time_lost: float = 0.0
var total_time_recovered: float = 0.0
var time_lost_by_source: Dictionary = {}
var time_recovered_by_source: Dictionary = {}
var death_cause: StringName = &""


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


func capture_time_from(time_health: TimeHealthComponent) -> void:
	if time_health == null:
		return
	current_time = time_health.current_time
	maximum_time = time_health.maximum_time
	_has_time_state = true


func has_time_state() -> bool:
	return _has_time_state


func mark_preparation_started(time_health: TimeHealthComponent) -> void:
	preparation_started_at = Time.get_ticks_msec() / 1000.0
	capture_time_from(time_health)


func mark_boss_started(time_health: TimeHealthComponent) -> void:
	time_at_boss_start = time_health.current_time if time_health != null else 0.0
	boss_started_at = Time.get_ticks_msec() / 1000.0
	capture_time_from(time_health)


func record_time_lost(amount: float, source: StringName) -> void:
	total_time_lost += amount
	time_lost_by_source[source] = (
		float(time_lost_by_source.get(source, 0.0)) + amount
	)


func record_time_recovered(amount: float, source: StringName) -> void:
	total_time_recovered += amount
	time_recovered_by_source[source] = (
		float(time_recovered_by_source.get(source, 0.0)) + amount
	)


func print_time_summary() -> void:
	if not OS.is_debug_build():
		return
	var now: float = Time.get_ticks_msec() / 1000.0
	var preparation_duration: float = maxf(
		boss_started_at - preparation_started_at,
		0.0
	)
	var boss_duration: float = (
		maxf(now - boss_started_at, 0.0) if boss_started_at > 0.0 else 0.0
	)
	print("=== TIME ECONOMY SUMMARY ===")
	print("Preparation duration: %.2f" % preparation_duration)
	print("Time at boss start: %.2f" % time_at_boss_start)
	print("Boss duration: %.2f" % boss_duration)
	print("Total time lost: %.2f" % total_time_lost)
	print("Total time recovered: %.2f" % total_time_recovered)
	print("Loss sources: %s" % time_lost_by_source)
	print("Recovery sources: %s" % time_recovered_by_source)
	print("Death cause: %s" % death_cause)


func clear_loadout() -> void:
	for slot: int in range(SLOT_COUNT):
		_weapon_scenes[slot] = null
	active_slot_index = 0
	_has_loadout = false


func reset_run() -> void:
	clear_loadout()
	current_time = 0.0
	maximum_time = 60.0
	_has_time_state = false
	preparation_started_at = 0.0
	time_at_boss_start = 0.0
	boss_started_at = 0.0
	total_time_lost = 0.0
	total_time_recovered = 0.0
	time_lost_by_source.clear()
	time_recovered_by_source.clear()
	death_cause = &""
