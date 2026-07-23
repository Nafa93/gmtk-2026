class_name HealthComponent
extends Node

signal died
signal damaged(amount: int)
signal health_changed(current_health: int, max_health: int)

@export_range(1, 1000000, 1, "or_greater") var max_health: int = 3

var current_health: int
var _is_dead: bool = false


func _ready() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func take_damage(amount: int) -> void:
	if _is_dead or amount <= 0:
		return

	var previous_health: int = current_health
	current_health = maxi(current_health - amount, 0)
	var applied_damage: int = previous_health - current_health

	if applied_damage <= 0:
		return

	damaged.emit(applied_damage)
	health_changed.emit(current_health, max_health)

	if current_health == 0:
		_is_dead = true
		died.emit()


func get_health_ratio() -> float:
	if max_health <= 0:
		return 0.0

	return float(current_health) / float(max_health)


func is_dead() -> bool:
	return _is_dead
