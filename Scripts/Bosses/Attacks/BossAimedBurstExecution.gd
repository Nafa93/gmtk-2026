class_name BossAimedBurstExecution
extends BossAttackExecution

var _boss: BossController
var _direction: Vector2
var _shots_remaining: int
var _shot_interval: float
var _projectile_speed: float
var _damage: int
var _retarget_each_shot: bool
var _time_until_shot: float = 0.0


func _init(
	boss: BossController,
	attack: BossAimedBurstAttack,
	phase: int
) -> void:
	_boss = boss
	_direction = boss.get_locked_attack_direction()
	_shots_remaining = attack.burst_count
	_shot_interval = attack.shot_interval
	_projectile_speed = attack.projectile_speed
	_damage = attack.damage
	_retarget_each_shot = attack.retarget_each_shot

	if phase >= 2:
		_shots_remaining += attack.phase_two_burst_bonus
		_shot_interval *= attack.phase_two_interval_multiplier
		_projectile_speed *= boss.phase_two_projectile_speed_multiplier

	_shot_interval = maxf(_shot_interval, 0.01)
	_boss.play_attack_effects()


func physics_update(delta: float) -> void:
	if finished or not is_instance_valid(_boss):
		finished = true
		return

	_boss.velocity = Vector2.ZERO
	_time_until_shot -= delta

	while _shots_remaining > 0 and _time_until_shot <= 0.0:
		var shot_direction: Vector2 = _direction
		if _retarget_each_shot:
			var current_direction: Vector2 = _boss.get_direction_to_target()
			if not current_direction.is_zero_approx():
				shot_direction = current_direction

		_boss.spawn_boss_projectile(
			shot_direction,
			_projectile_speed,
			_damage
		)
		_shots_remaining -= 1
		_time_until_shot += _shot_interval

	if _shots_remaining <= 0:
		finished = true
