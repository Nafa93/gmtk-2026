class_name BossAttackExecution
extends RefCounted

var finished: bool = false


func physics_update(_delta: float) -> void:
	pass


func after_move() -> void:
	pass


func cancel() -> void:
	finished = true
