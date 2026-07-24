class_name BossChargeAttack
extends BossAttack

## Velocidad de desplazamiento del jefe durante la carga, expresada en píxeles por segundo.
@export_range(0.01, 10000.0, 1.0, "or_greater") var charge_speed: float = 780.0
## Duración máxima de la carga en segundos, aunque no choque ni alcance la distancia límite.
@export_range(0.01, 30.0, 0.01, "or_greater") var maximum_duration: float = 0.8
## Daño aplicado al jugador cuando la carga lo impacta.
@export_range(1, 10000, 1, "or_greater") var contact_damage: int = 2
## Multiplicador aplicado a la velocidad de carga durante la fase 2.
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_speed_multiplier: float = 1.3


func begin_telegraph(boss: BossController, _phase: int) -> void:
	boss.lock_attack_direction_to_target()
	boss.show_direction_telegraph(
		boss.get_locked_attack_direction(),
		maximum_distance,
		24.0,
		telegraph_color
	)


func create_execution(
	boss: BossController,
	phase: int
) -> BossAttackExecution:
	return BossChargeExecution.new(boss, self, phase)
