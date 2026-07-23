class_name BossAttack
extends Resource

@export var attack_name: String = "Boss Attack"
@export_range(0.0, 1000.0, 0.1, "or_greater") var selection_weight: float = 1.0
@export_range(0.0, 120.0, 0.05, "or_greater") var cooldown: float = 2.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var minimum_distance: float = 0.0
@export_range(0.0, 100000.0, 1.0, "or_greater") var maximum_distance: float = 100000.0
@export_range(0.0, 30.0, 0.05, "or_greater") var telegraph_duration: float = 0.75
@export_range(0.0, 30.0, 0.05, "or_greater") var recovery_duration: float = 0.75
@export var telegraph_color: Color = Color(1.0, 0.3, 0.1, 0.7)


func is_valid_for_distance(distance_to_target: float) -> bool:
	return distance_to_target >= minimum_distance \
			and distance_to_target <= maximum_distance


func begin_telegraph(boss: BossController, _phase: int) -> void:
	boss.hide_telegraphs()


func create_execution(
	_boss: BossController,
	_phase: int
) -> BossAttackExecution:
	push_error("BossAttack '%s' has no execution implementation." % attack_name)
	return null
