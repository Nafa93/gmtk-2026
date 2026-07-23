class_name BossDeadState
extends BossState


func enter(_context: Dictionary = {}) -> void:
	boss.perform_death_cleanup()
