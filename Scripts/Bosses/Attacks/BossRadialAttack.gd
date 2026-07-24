class_name BossRadialAttack
extends BossAttack

## Cantidad de proyectiles distribuidos uniformemente en cada onda circular.
@export_range(1, 256, 1, "or_greater") var projectile_count: int = 12
## Velocidad de desplazamiento de cada proyectil, expresada en píxeles por segundo.
@export_range(0.01, 10000.0, 1.0, "or_greater") var projectile_speed: float = 420.0
## Daño causado por cada proyectil que impacta al objetivo.
@export_range(1, 10000, 1, "or_greater") var damage: int = 1
## Rotación inicial en grados aplicada al patrón circular completo.
@export_range(-360.0, 360.0, 0.1) var angular_offset_degrees: float = 0.0
## Cantidad de ondas circulares emitidas durante una ejecución del ataque.
@export_range(1, 32, 1, "or_greater") var wave_count: int = 2
## Tiempo en segundos entre una onda circular y la siguiente.
@export_range(0.01, 10.0, 0.01, "or_greater") var time_between_waves: float = 0.45
## Rotación adicional en grados aplicada a cada onda respecto de la anterior.
@export_range(-360.0, 360.0, 0.1) var rotation_per_wave_degrees: float = 15.0

## Proyectiles adicionales por onda durante la fase 2.
@export_range(0, 256, 1, "or_greater") var phase_two_projectile_bonus: int = 4
## Ondas adicionales emitidas durante la fase 2.
@export_range(0, 32, 1, "or_greater") var phase_two_wave_bonus: int = 1
## Multiplicador aplicado al intervalo entre ondas en fase 2. Valores menores que 1 aceleran el ataque.
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_wave_interval_multiplier: float = 0.8


func begin_telegraph(boss: BossController, _phase: int) -> void:
	boss.show_radial_telegraph(95.0, telegraph_color)


func create_execution(
	boss: BossController,
	phase: int
) -> BossAttackExecution:
	return BossRadialExecution.new(boss, self, phase)
