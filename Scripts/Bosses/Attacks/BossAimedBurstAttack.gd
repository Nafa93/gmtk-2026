class_name BossAimedBurstAttack
extends BossAttack

@export_range(1, 128, 1, "or_greater") var burst_count: int = 3
@export_range(0.01, 10.0, 0.01, "or_greater") var shot_interval: float = 0.18
@export_range(0.01, 100000.0, 1.0, "or_greater") var projectile_speed: float = 520.0
@export_range(1, 1000000, 1, "or_greater") var damage: int = 1

@export_range(0, 128, 1, "or_greater") var phase_two_burst_bonus: int = 2
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_interval_multiplier: float = 0.8


func begin_telegraph(boss: BossController, _phase: int) -> void:
	boss.lock_attack_direction_to_target()
	boss.show_direction_telegraph(
		boss.get_locked_attack_direction(),
		300.0,
		8.0,
		telegraph_color
	)


func create_execution(
	boss: BossController,
	phase: int
) -> BossAttackExecution:
	return BossAimedBurstExecution.new(boss, self, phase)
