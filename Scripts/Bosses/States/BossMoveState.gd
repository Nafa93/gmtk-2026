class_name BossMoveState
extends BossState

@export var telegraph_state: BossState

var _time_remaining: float = 0.0


func enter(_context: Dictionary = {}) -> void:
	_time_remaining = boss.reposition_duration
	boss.velocity = Vector2.ZERO


func physics_update(delta: float) -> void:
	_time_remaining -= delta
	if not boss.targeting.is_target_valid():
		boss.velocity = Vector2.ZERO
		if _time_remaining <= 0.0:
			_time_remaining = 0.25
		return

	var to_target: Vector2 = boss.targeting.get_direction_from(boss.global_position)
	var distance_to_target: float = boss.targeting.get_distance_from(
		boss.global_position
	)
	var move_direction: Vector2

	if distance_to_target > boss.preferred_maximum_distance:
		move_direction = to_target
	elif distance_to_target < boss.preferred_minimum_distance:
		move_direction = -to_target
	else:
		move_direction = to_target.rotated(PI / 2.0)

	var speed: float = boss.movement_speed \
			* boss.phase_controller.get_movement_speed_multiplier()
	boss.velocity = move_direction * speed
	boss.rotation = to_target.angle() + PI / 2.0

	if _time_remaining > 0.0:
		return

	var selected_attack: BossAttack = boss.attack_scheduler.select_attack(
		distance_to_target,
		boss.phase_controller.get_cooldown_multiplier()
	)
	if selected_attack == null:
		boss.velocity = Vector2.ZERO
		_time_remaining = 0.25
		return

	state_machine.change_state(
		telegraph_state,
		{"attack": selected_attack}
	)
