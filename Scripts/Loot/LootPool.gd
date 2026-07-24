class_name LootPool
extends Resource

## Escenas de armas disponibles para esta distribución simple.
## Una escena repetida funciona como peso adicional.
@export var weapon_scenes: Array[PackedScene] = []


func get_valid_weapon_scenes() -> Array[PackedScene]:
	var valid_scenes: Array[PackedScene] = []
	for weapon_scene: PackedScene in weapon_scenes:
		if weapon_scene != null:
			valid_scenes.append(weapon_scene)
	return valid_scenes
