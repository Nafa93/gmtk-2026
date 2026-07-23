class_name BossAttackScheduler
extends Node

@export var attacks: Array[BossAttack] = []

var _cooldowns: Array[float] = []
var _last_attack_index: int = -1


func initialize() -> void:
	_cooldowns.resize(attacks.size())
	_cooldowns.fill(0.0)


func physics_update(delta: float) -> void:
	for attack_index: int in range(_cooldowns.size()):
		_cooldowns[attack_index] = maxf(
			_cooldowns[attack_index] - delta,
			0.0
		)


func select_attack(
	distance_to_target: float,
	cooldown_multiplier: float = 1.0
) -> BossAttack:
	_ensure_runtime_size()
	var candidates: Array[int] = _get_valid_indices(distance_to_target, true)
	if candidates.is_empty():
		candidates = _get_valid_indices(distance_to_target, false)
	if candidates.is_empty():
		return null

	var selected_index: int = _pick_weighted_index(candidates)
	var selected_attack: BossAttack = attacks[selected_index]
	_last_attack_index = selected_index
	_cooldowns[selected_index] = selected_attack.cooldown \
			* maxf(cooldown_multiplier, 0.0)
	return selected_attack


func reset_runtime() -> void:
	_last_attack_index = -1
	_cooldowns.resize(attacks.size())
	_cooldowns.fill(0.0)


func get_last_attack_index() -> int:
	return _last_attack_index


func get_cooldown(attack_index: int) -> float:
	if attack_index < 0 or attack_index >= _cooldowns.size():
		return 0.0
	return _cooldowns[attack_index]


func _ensure_runtime_size() -> void:
	if _cooldowns.size() == attacks.size():
		return
	_cooldowns.resize(attacks.size())
	_cooldowns.fill(0.0)
	_last_attack_index = -1


func _get_valid_indices(
	distance_to_target: float,
	exclude_last: bool
) -> Array[int]:
	var valid_indices: Array[int] = []
	for attack_index: int in range(attacks.size()):
		var attack: BossAttack = attacks[attack_index]
		if attack == null:
			continue
		if _cooldowns[attack_index] > 0.0:
			continue
		if exclude_last and attack_index == _last_attack_index:
			continue
		if not attack.is_valid_for_distance(distance_to_target):
			continue
		valid_indices.append(attack_index)
	return valid_indices


func _pick_weighted_index(candidates: Array[int]) -> int:
	var total_weight: float = 0.0
	for attack_index: int in candidates:
		total_weight += maxf(attacks[attack_index].selection_weight, 0.0)

	if total_weight <= 0.0:
		return candidates[0]

	var roll: float = randf() * total_weight
	for attack_index: int in candidates:
		roll -= maxf(attacks[attack_index].selection_weight, 0.0)
		if roll <= 0.0:
			return attack_index
	return candidates.back()
