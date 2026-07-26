class_name BossSummonAttack
extends BossAttack

@export_range(1, 20, 1, "or_greater") var bomb_count: int = 2


func begin_telegraph(boss: BossController, _phase: int) -> void:
	boss.show_radial_telegraph(140.0, telegraph_color)


func create_execution(
	boss: BossController,
	_phase: int
) -> BossAttackExecution:
	return BossSummonExecution.new(boss, self)
