class_name BossTelegraphState
extends BossState

@export var attack_state: BossState

var _attack: BossAttack
var _time_remaining: float = 0.0


func enter(context: Dictionary = {}) -> void:
	_attack = context.get("attack") as BossAttack
	boss.velocity = Vector2.ZERO
	if _attack == null:
		push_error("BossTelegraphState requires a BossAttack.")
		return

	_time_remaining = _attack.telegraph_duration \
			* boss.phase_controller.get_telegraph_multiplier()
	_attack.begin_telegraph(boss, boss.phase_controller.current_phase)


func exit() -> void:
	boss.telegraph_presenter.hide_all()


func physics_update(delta: float) -> void:
	if _attack == null:
		return

	boss.velocity = Vector2.ZERO
	_time_remaining -= delta
	if _time_remaining <= 0.0:
		state_machine.change_state(attack_state, {"attack": _attack})
