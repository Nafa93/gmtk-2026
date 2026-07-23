class_name HealthComponent
extends Node

signal died

@export var max_health: int = 3

var current_health: int

func _ready() -> void:
	current_health = max_health

func take_damage(amount: int) -> void:
	current_health = max(current_health - amount, 0)

	if current_health == 0:
		died.emit()
