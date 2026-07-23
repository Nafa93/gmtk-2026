class_name BossPhaseController
extends Node

signal phase_changed(new_phase: int)

@export_range(0.01, 0.99, 0.01) var phase_two_health_ratio: float = 0.5
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_movement_speed_multiplier: float = 1.2
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_projectile_speed_multiplier: float = 1.2
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_telegraph_multiplier: float = 0.85
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_recovery_multiplier: float = 0.7
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_cooldown_multiplier: float = 0.8

var current_phase: int = 1
var _boss_sprite: CanvasItem


func initialize(
	health_component: HealthComponent,
	boss_sprite: CanvasItem
) -> void:
	_boss_sprite = boss_sprite
	if health_component == null:
		push_error("BossPhaseController requires a HealthComponent.")
		return

	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)
	_evaluate_phase(
		health_component.current_health,
		health_component.max_health
	)


func get_movement_speed_multiplier() -> float:
	return phase_two_movement_speed_multiplier if current_phase >= 2 else 1.0


func get_projectile_speed_multiplier() -> float:
	return phase_two_projectile_speed_multiplier if current_phase >= 2 else 1.0


func get_telegraph_multiplier() -> float:
	return phase_two_telegraph_multiplier if current_phase >= 2 else 1.0


func get_recovery_multiplier() -> float:
	return phase_two_recovery_multiplier if current_phase >= 2 else 1.0


func get_cooldown_multiplier() -> float:
	return phase_two_cooldown_multiplier if current_phase >= 2 else 1.0


func _on_health_changed(current_health: int, max_health: int) -> void:
	_evaluate_phase(current_health, max_health)


func _evaluate_phase(current_health: int, max_health: int) -> void:
	if current_phase >= 2 or max_health <= 0:
		return

	var health_ratio: float = float(current_health) / float(max_health)
	if health_ratio > phase_two_health_ratio:
		return

	current_phase = 2
	if _boss_sprite != null:
		_boss_sprite.modulate = Color(1.0, 0.35, 0.65, 1.0)
	phase_changed.emit(current_phase)
