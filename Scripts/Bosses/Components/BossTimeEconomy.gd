class_name BossTimeEconomy
extends Node

signal milestone_reward_triggered(health_ratio: float, amount: float)

@export_group("References")
@export var health_component: HealthComponent
@export var phase_controller: BossPhaseController

@export_group("Health Milestones")
@export_range(0.05, 1.0, 0.05) var milestone_interval: float = 0.2
@export_range(0.0, 120.0, 0.5, "or_greater") var milestone_time_reward: float = 5.0

var _player_time: TimeHealthComponent
var _next_milestone_ratio: float = 0.8
var _active: bool = true


func _ready() -> void:
	if health_component == null:
		push_error("BossTimeEconomy requires a HealthComponent.")
		return
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)
	if not health_component.died.is_connected(_on_boss_died):
		health_component.died.connect(_on_boss_died)
	if phase_controller != null:
		if not phase_controller.phase_changed.is_connected(_on_phase_changed):
			phase_controller.phase_changed.connect(_on_phase_changed)
	call_deferred(&"_resolve_player_time")


func grant_milestone_time(
	amount: float,
	source: StringName = &"boss_milestone"
) -> float:
	if not _active:
		return 0.0
	_resolve_player_time()
	if _player_time == null:
		return 0.0
	return _player_time.grant_time(amount, source)


func _resolve_player_time() -> void:
	if _player_time != null and is_instance_valid(_player_time):
		return
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player != null:
		_player_time = player.health_component as TimeHealthComponent


func _on_health_changed(current_health: int, max_health: int) -> void:
	if not _active or max_health <= 0:
		return
	var health_ratio: float = float(current_health) / float(max_health)
	while health_ratio <= _next_milestone_ratio and _next_milestone_ratio >= 0.0:
		var crossed_ratio: float = _next_milestone_ratio
		_next_milestone_ratio -= milestone_interval
		var granted: float = grant_milestone_time(
			milestone_time_reward,
			&"boss_health_milestone"
		)
		if granted > 0.0:
			milestone_reward_triggered.emit(crossed_ratio, granted)


func _on_phase_changed(_new_phase: int) -> void:
	# Milestones span the whole health bar and never reset between phases.
	return


func _on_boss_died() -> void:
	_active = false
