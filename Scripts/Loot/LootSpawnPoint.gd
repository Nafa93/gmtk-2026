class_name LootSpawnPoint
extends Marker2D

## Grupo utilizado por el distribuidor cuando no se configura una raíz de búsqueda.
@export var spawn_group: StringName = &"loot_spawn_point"
## Permite excluir este punto sin eliminarlo del mapa.
@export var excluded: bool = false

var _reserved: bool = false


func _enter_tree() -> void:
	if not spawn_group.is_empty():
		add_to_group(spawn_group)


func is_available() -> bool:
	return not excluded and not _reserved and is_inside_tree()


func reserve() -> bool:
	if not is_available():
		return false

	_reserved = true
	return true


func release() -> void:
	_reserved = false


func is_reserved() -> bool:
	return _reserved
