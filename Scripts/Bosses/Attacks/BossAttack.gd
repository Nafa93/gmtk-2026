class_name BossAttack
extends Resource

## Nombre descriptivo del ataque, utilizado para identificarlo en el editor y durante la depuración.
@export var attack_name: String = "Boss Attack"
## Peso relativo usado por el selector aleatorio. Un valor mayor hace que el ataque sea elegido con más frecuencia.
@export_range(0.0, 1000.0, 0.1, "or_greater") var selection_weight: float = 1.0
## Tiempo mínimo en segundos que debe pasar antes de que este ataque pueda volver a ser seleccionado.
@export_range(0.0, 120.0, 0.05, "or_greater") var cooldown: float = 2.0
## Distancia mínima al objetivo requerida para que el ataque sea válido.
@export_range(0.0, 10000.0, 1.0, "or_greater") var minimum_distance: float = 0.0
## Distancia máxima al objetivo a la que el ataque puede ser seleccionado.
@export_range(0.0, 10000.0, 1.0, "or_greater") var maximum_distance: float = 100000.0
## Duración en segundos del aviso visual previo a la ejecución del ataque.
@export_range(0.0, 30.0, 0.05, "or_greater") var telegraph_duration: float = 0.75
## Tiempo en segundos durante el cual el jefe se recupera después de ejecutar el ataque.
@export_range(0.0, 30.0, 0.05, "or_greater") var recovery_duration: float = 0.75
## Color utilizado por la representación visual que anticipa el ataque.
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
