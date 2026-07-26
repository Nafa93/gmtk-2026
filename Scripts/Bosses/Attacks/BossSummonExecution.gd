class_name BossSummonExecution
extends BossAttackExecution


func _init(boss: BossController, attack: BossSummonAttack) -> void:
	if boss == null or not is_instance_valid(boss):
		finished = true
		return
	boss.velocity = Vector2.ZERO
	boss.play_attack_effects()
	boss.throw_boss_bombs(attack.bomb_count)
	finished = true
