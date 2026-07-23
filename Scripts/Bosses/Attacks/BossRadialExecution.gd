class_name BossRadialExecution
extends BossAttackExecution

var _boss: BossController
var _projectile_count: int
var _projectile_speed: float
var _damage: int
var _angular_offset_degrees: float
var _waves_remaining: int
var _wave_index: int = 0
var _time_between_waves: float
var _rotation_per_wave_degrees: float
var _time_until_wave: float = 0.0


func _init(
	boss: BossController,
	attack: BossRadialAttack,
	phase: int
) -> void:
	_boss = boss
	_projectile_count = attack.projectile_count
	_projectile_speed = attack.projectile_speed
	_damage = attack.damage
	_angular_offset_degrees = attack.angular_offset_degrees
	_waves_remaining = attack.wave_count
	_time_between_waves = attack.time_between_waves
	_rotation_per_wave_degrees = attack.rotation_per_wave_degrees

	if phase >= 2:
		_projectile_count += attack.phase_two_projectile_bonus
		_waves_remaining += attack.phase_two_wave_bonus
		_time_between_waves *= attack.phase_two_wave_interval_multiplier
		_projectile_speed *= boss.phase_two_projectile_speed_multiplier

	_projectile_count = maxi(_projectile_count, 1)
	_time_between_waves = maxf(_time_between_waves, 0.01)
	_boss.play_attack_effects()


func physics_update(delta: float) -> void:
	if finished or not is_instance_valid(_boss):
		finished = true
		return

	_boss.velocity = Vector2.ZERO
	_time_until_wave -= delta

	while _waves_remaining > 0 and _time_until_wave <= 0.0:
		_fire_wave()
		_waves_remaining -= 1
		_wave_index += 1
		_time_until_wave += _time_between_waves

	if _waves_remaining <= 0:
		finished = true


func _fire_wave() -> void:
	var wave_offset: float = _angular_offset_degrees \
			+ _rotation_per_wave_degrees * float(_wave_index)
	var angle_step: float = TAU / float(_projectile_count)

	for projectile_index: int in range(_projectile_count):
		var angle: float = deg_to_rad(wave_offset) \
				+ angle_step * float(projectile_index)
		var direction: Vector2 = Vector2.RIGHT.rotated(angle)
		_boss.spawn_boss_projectile(direction, _projectile_speed, _damage)
