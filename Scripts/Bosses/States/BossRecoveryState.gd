class_name BossRecoveryState
extends BossState

@export var move_state: BossState

var _time_remaining: float = 0.0


func enter(context: Dictionary = {}) -> void:
	boss.velocity = Vector2.ZERO
	boss.telegraph_presenter.hide_all()
	var attack: BossAttack = context.get("attack") as BossAttack
	_time_remaining = 0.25
	if attack != null:
		_time_remaining = attack.recovery_duration \
				* boss.phase_controller.get_recovery_multiplier()


func physics_update(delta: float) -> void:
	boss.velocity = Vector2.ZERO
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		state_machine.change_state(move_state)
