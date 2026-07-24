class_name BossAimedBurstAttack
extends BossAttack

## Cantidad de proyectiles disparados en cada ráfaga.
@export_range(1, 128, 1, "or_greater") var burst_count: int = 3
## Tiempo en segundos entre un proyectil y el siguiente de la misma ráfaga.
@export_range(0.01, 10.0, 0.01, "or_greater") var shot_interval: float = 0.18
## Velocidad de desplazamiento de cada proyectil, expresada en píxeles por segundo.
@export_range(0.01, 10000.0, 1.0, "or_greater") var projectile_speed: float = 520.0
## Daño causado por cada proyectil que impacta al objetivo.
@export_range(1, 10000, 1, "or_greater") var damage: int = 1
## Si está activo, cada proyectil vuelve a apuntar a la posición actual del objetivo. Si está desactivado, toda la ráfaga usa la dirección fijada al comenzar el ataque.
@export var retarget_each_shot: bool = false

## Proyectiles adicionales que se agregan a la ráfaga durante la fase 2.
@export_range(0, 128, 1, "or_greater") var phase_two_burst_bonus: int = 2
## Multiplicador aplicado al intervalo entre disparos en fase 2. Valores menores que 1 aceleran la ráfaga.
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
