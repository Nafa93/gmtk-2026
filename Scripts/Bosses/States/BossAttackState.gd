class_name BossAttackState
extends BossState

@export var recovery_state: BossState

var active_attack: BossAttack
var active_execution: BossAttackExecution


func enter(context: Dictionary = {}) -> void:
	active_attack = context.get("attack") as BossAttack
	boss.velocity = Vector2.ZERO
	if active_attack == null:
		push_error("BossAttackState requires a BossAttack.")
		state_machine.change_state(recovery_state)
		return

	active_execution = active_attack.create_execution(
		boss,
		boss.phase_controller.current_phase
	)
	if active_execution == null:
		state_machine.change_state(
			recovery_state,
			{"attack": active_attack}
		)


func exit() -> void:
	if active_execution != null:
		active_execution.cancel()
	active_execution = null


func physics_update(delta: float) -> void:
	if active_execution == null:
		return

	active_execution.physics_update(delta)
	if active_execution.finished:
		state_machine.change_state(
			recovery_state,
			{"attack": active_attack}
		)


func after_move() -> void:
	if active_execution == null:
		return

	active_execution.after_move()
	if active_execution.finished:
		state_machine.change_state(
			recovery_state,
			{"attack": active_attack}
		)
