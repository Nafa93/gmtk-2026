class_name LootDistributor
extends Node

signal weapon_spawned(
	pickup: WeaponPickup,
	spawn_point: LootSpawnPoint,
	weapon_scene: PackedScene
)
signal distribution_finished(spawned_count: int, used_seed: int)

@export_group("Distribution")
## Cantidad máxima de armas que se intentará generar.
@export_range(0, 512, 1, "or_greater") var total_weapon_count: int = 6
## Semilla determinista. Usa -1 para generar una semilla aleatoria.
@export var random_seed: int = -1
## Si está activo, distribuye automáticamente al entrar en la escena.
@export var distribute_on_ready: bool = true

@export_group("Spawn Point Discovery")
## Si se asigna, solamente se buscan LootSpawnPoint descendientes de este nodo.
@export var spawn_points_root: Node
## Grupo usado cuando spawn_points_root está vacío.
@export var spawn_point_group: StringName = &"loot_spawn_point"

@export_group("Loot")
@export var loot_pool: LootPool
@export var pickup_scene: PackedScene
## Contenedor opcional para los pickups generados. Por defecto se usa el padre.
@export var output_container: Node

var used_seed: int = 0
var spawned_pickups: Array[WeaponPickup] = []

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _reserved_points: Array[LootSpawnPoint] = []


func _ready() -> void:
	if distribute_on_ready:
		call_deferred(&"distribute")


func distribute() -> int:
	clear_generated_loot()
	_configure_rng()

	var available_points: Array[LootSpawnPoint] = _find_available_points()
	var available_weapons: Array[PackedScene] = (
		loot_pool.get_valid_weapon_scenes()
		if loot_pool != null
		else []
	)

	if available_weapons.is_empty():
		push_warning("LootDistributor has no valid weapon scenes in its LootPool.")
		distribution_finished.emit(0, used_seed)
		return 0
	if pickup_scene == null:
		push_warning("LootDistributor has no pickup_scene assigned.")
		distribution_finished.emit(0, used_seed)
		return 0

	_shuffle_points(available_points)
	var requested_count: int = maxi(total_weapon_count, 0)
	var spawn_count: int = mini(requested_count, available_points.size())

	if spawn_count < requested_count:
		push_warning(
			(
				"LootDistributor requested %d weapons but only %d valid, unique "
				+ "spawn points are available. It will generate %d weapons."
			)
			% [requested_count, available_points.size(), spawn_count]
		)

	for index: int in range(spawn_count):
		var point: LootSpawnPoint = available_points[index]
		var weapon_scene: PackedScene = available_weapons[
			_rng.randi_range(0, available_weapons.size() - 1)
		]
		_spawn_weapon(point, weapon_scene)

	distribution_finished.emit(spawned_pickups.size(), used_seed)
	return spawned_pickups.size()


func clear_generated_loot() -> void:
	for pickup: WeaponPickup in spawned_pickups:
		if pickup != null and is_instance_valid(pickup):
			pickup.queue_free()
	spawned_pickups.clear()

	for point: LootSpawnPoint in _reserved_points:
		if point != null and is_instance_valid(point):
			point.release()
	_reserved_points.clear()


func _configure_rng() -> void:
	if random_seed != -1:
		used_seed = random_seed
		_rng.seed = used_seed
	else:
		_rng.randomize()
		used_seed = _rng.seed

	if OS.is_debug_build():
		print("LootDistributor seed: %d" % used_seed)


func _find_available_points() -> Array[LootSpawnPoint]:
	var candidates: Array[LootSpawnPoint] = []
	if spawn_points_root != null:
		_collect_points_recursive(spawn_points_root, candidates)
	else:
		for node: Node in get_tree().get_nodes_in_group(spawn_point_group):
			if node is LootSpawnPoint:
				candidates.append(node as LootSpawnPoint)

	var unique_points: Array[LootSpawnPoint] = []
	var known_ids: Dictionary = {}
	for point: LootSpawnPoint in candidates:
		if point == null or not point.is_available():
			continue
		var point_id: int = point.get_instance_id()
		if known_ids.has(point_id):
			continue
		known_ids[point_id] = true
		unique_points.append(point)

	# A stable initial order is required before applying the seeded shuffle.
	unique_points.sort_custom(
		func(first: LootSpawnPoint, second: LootSpawnPoint) -> bool:
			return String(first.get_path()) < String(second.get_path())
	)
	return unique_points


func _collect_points_recursive(
	parent_node: Node,
	result: Array[LootSpawnPoint]
) -> void:
	for child: Node in parent_node.get_children():
		if child is LootSpawnPoint:
			result.append(child as LootSpawnPoint)
		_collect_points_recursive(child, result)


func _shuffle_points(points: Array[LootSpawnPoint]) -> void:
	for index: int in range(points.size() - 1, 0, -1):
		var swap_index: int = _rng.randi_range(0, index)
		var temporary: LootSpawnPoint = points[index]
		points[index] = points[swap_index]
		points[swap_index] = temporary


func _spawn_weapon(
	point: LootSpawnPoint,
	weapon_scene: PackedScene
) -> void:
	if not point.reserve():
		push_warning("Loot spawn point '%s' could not be reserved." % point.name)
		return

	var pickup_node: Node = pickup_scene.instantiate()
	var pickup: WeaponPickup = pickup_node as WeaponPickup
	if pickup == null:
		pickup_node.free()
		point.release()
		push_error("LootDistributor pickup_scene root must extend WeaponPickup.")
		return

	pickup.configure(weapon_scene)
	var container: Node = output_container if output_container != null else get_parent()
	container.add_child(pickup)
	pickup.global_position = point.global_position
	spawned_pickups.append(pickup)
	_reserved_points.append(point)
	weapon_spawned.emit(pickup, point, weapon_scene)
