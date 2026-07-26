class_name TimeLightingController
extends Node

@export_range(0.05, 1.0, 0.05) var minimum_brightness: float = 0.3
@export_range(1.0, 4.0, 0.1, "or_greater") var starting_size_multiplier: float = 1.8
@export_range(0.1, 1.0, 0.05) var minimum_size_multiplier: float = 0.35
@export_range(1.0, 300.0, 1.0, "or_greater") var seconds_to_minimum: float = 60.0

var elapsed_seconds: int = 0

var _second_accumulator: float = 0.0
var _active: bool = false
var _base_light_energy: Dictionary = {}
var _base_light_scale: Dictionary = {}


func _ready() -> void:
	process_priority = 1000


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if not _active:
		if player == null:
			return
		reset_for_run()
	var time_health: TimeHealthComponent = (
		player.health_component as TimeHealthComponent if player != null else null
	)
	if (
		time_health != null
		and time_health.is_timer_running
		and not time_health.is_timer_paused
	):
		_second_accumulator += delta
		while _second_accumulator >= 1.0:
			_second_accumulator -= 1.0
			elapsed_seconds += 1
	_apply_to_scene_lights()


func reset_for_run() -> void:
	elapsed_seconds = 0
	_second_accumulator = 0.0
	_active = true
	_base_light_energy.clear()
	_base_light_scale.clear()


func get_brightness_multiplier() -> float:
	return lerpf(1.0, minimum_brightness, _get_darkness_progress())


func get_size_multiplier() -> float:
	return lerpf(
		starting_size_multiplier,
		minimum_size_multiplier,
		_get_darkness_progress()
	)


func _get_darkness_progress() -> float:
	return clampf(
		float(elapsed_seconds) / maxf(seconds_to_minimum, 1.0),
		0.0,
		1.0
	)


func _apply_to_scene_lights() -> void:
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return
	var live_ids: Dictionary = {}
	var lights: Array[PointLight2D] = []
	_collect_point_lights(scene_root, lights)
	for light: PointLight2D in lights:
		if _is_managed_torch_light(light):
			continue
		var light_id: int = light.get_instance_id()
		live_ids[light_id] = true
		if not _base_light_energy.has(light_id):
			_base_light_energy[light_id] = light.energy
			_base_light_scale[light_id] = light.texture_scale
		light.energy = float(_base_light_energy[light_id]) * get_brightness_multiplier()
		light.texture_scale = (
			float(_base_light_scale[light_id]) * get_size_multiplier()
		)
	for stored_id: Variant in _base_light_energy.keys():
		if not live_ids.has(stored_id):
			_base_light_energy.erase(stored_id)
			_base_light_scale.erase(stored_id)


func _collect_point_lights(
	parent: Node,
	result: Array[PointLight2D]
) -> void:
	for child: Node in parent.get_children():
		if child is PointLight2D:
			result.append(child as PointLight2D)
		_collect_point_lights(child, result)


func _is_managed_torch_light(light: PointLight2D) -> bool:
	var ancestor: Node = light.get_parent()
	while ancestor != null:
		if ancestor is WallTorch:
			return true
		ancestor = ancestor.get_parent()
	return false
