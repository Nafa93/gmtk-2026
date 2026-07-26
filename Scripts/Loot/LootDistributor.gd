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

@export_group("Distance Rating")
## When enabled, distant spawn points receive weapons with higher ratings.
@export var use_distance_rating: bool = true
## Position from which room distance is measured, normally the player spawn.
@export var distance_origin: Node2D
@export_range(1, 5, 1) var minimum_target_rating: int = 1
@export_range(1, 5, 1) var maximum_target_rating: int = 5

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
	available_weapons = _get_unique_weapon_scenes(available_weapons)

	if available_weapons.is_empty():
		push_warning("LootDistributor has no valid weapon scenes in its LootPool.")
		distribution_finished.emit(0, used_seed)
		return 0
	if pickup_scene == null:
		push_warning("LootDistributor has no pickup_scene assigned.")
		distribution_finished.emit(0, used_seed)
		return 0

	if use_distance_rating:
		_sort_points_by_distance(available_points)
	else:
		_shuffle_points(available_points)
	var requested_count: int = maxi(total_weapon_count, 0)
	var spawn_count: int = mini(
		requested_count,
		mini(available_points.size(), available_weapons.size())
	)
	var selected_points: Array[LootSpawnPoint] = (
		_select_spread_points(available_points, spawn_count)
		if use_distance_rating
		else available_points.slice(0, spawn_count)
	)

	if spawn_count < requested_count:
		push_warning(
			(
				"LootDistributor requested %d weapons but only %d valid, unique "
				+ "spawn points are available. It will generate %d weapons."
			)
			% [requested_count, available_points.size(), spawn_count]
		)

	for index: int in range(spawn_count):
		var point: LootSpawnPoint = selected_points[index]
		var weapon_scene: PackedScene
		if use_distance_rating:
			weapon_scene = _select_weapon_for_point(
				point,
				available_points,
				available_weapons
			)
		else:
			weapon_scene = available_weapons[
				_rng.randi_range(0, available_weapons.size() - 1)
			]
		_spawn_weapon(point, weapon_scene)
		available_weapons.erase(weapon_scene)

	distribution_finished.emit(spawned_pickups.size(), used_seed)
	return spawned_pickups.size()


func _select_spread_points(
	sorted_points: Array[LootSpawnPoint],
	count: int
) -> Array[LootSpawnPoint]:
	var selected: Array[LootSpawnPoint] = []
	if count <= 0 or sorted_points.is_empty():
		return selected
	if count == 1:
		selected.append(sorted_points[sorted_points.size() - 1])
		return selected

	# Spread the two unique weapons through the middle of the layout. Sending the
	# highest-rated weapon to the absolute farthest room made it too easy to miss
	# before the automatic boss transition.
	var minimum_distance_ratio: float = 0.35
	var maximum_distance_ratio: float = 0.65
	for index: int in range(count):
		var distribution_ratio: float = float(index) / float(count - 1)
		var ratio: float = lerpf(
			minimum_distance_ratio,
			maximum_distance_ratio,
			distribution_ratio
		)
		var point_index: int = roundi(
			ratio * float(sorted_points.size() - 1)
		)
		selected.append(sorted_points[point_index])
	return selected


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


func _get_unique_weapon_scenes(
	weapon_scenes: Array[PackedScene]
) -> Array[PackedScene]:
	var unique_scenes: Array[PackedScene] = []
	var known_paths: Dictionary = {}
	for weapon_scene: PackedScene in weapon_scenes:
		if weapon_scene == null:
			continue
		var scene_path: String = weapon_scene.resource_path
		if known_paths.has(scene_path):
			continue
		known_paths[scene_path] = true
		unique_scenes.append(weapon_scene)
	return unique_scenes


func _sort_points_by_distance(points: Array[LootSpawnPoint]) -> void:
	var origin_position: Vector2 = _get_distance_origin()
	points.sort_custom(
		func(first: LootSpawnPoint, second: LootSpawnPoint) -> bool:
			return first.global_position.distance_squared_to(origin_position) < (
				second.global_position.distance_squared_to(origin_position)
			)
	)


func _select_weapon_for_point(
	point: LootSpawnPoint,
	all_points: Array[LootSpawnPoint],
	weapons: Array[PackedScene]
) -> PackedScene:
	var origin_position: Vector2 = _get_distance_origin()
	var maximum_distance: float = 0.0
	for spawn_point: LootSpawnPoint in all_points:
		maximum_distance = maxf(
			maximum_distance,
			spawn_point.global_position.distance_to(origin_position)
		)

	var distance_ratio: float = 0.0
	if maximum_distance > 0.0:
		distance_ratio = point.global_position.distance_to(
			origin_position
		) / maximum_distance

	var low_rating: int = mini(minimum_target_rating, maximum_target_rating)
	var high_rating: int = maxi(minimum_target_rating, maximum_target_rating)
	var target_rating: int = roundi(lerpf(
		float(low_rating),
		float(high_rating),
		clampf(distance_ratio, 0.0, 1.0)
	))

	var closest_scenes: Array[PackedScene] = []
	var closest_difference: int = 1000000
	for weapon_scene: PackedScene in weapons:
		var rating: int = _get_weapon_rating(weapon_scene)
		var difference: int = absi(rating - target_rating)
		if difference < closest_difference:
			closest_difference = difference
			closest_scenes.clear()
			closest_scenes.append(weapon_scene)
		elif difference == closest_difference:
			closest_scenes.append(weapon_scene)

	return closest_scenes[_rng.randi_range(0, closest_scenes.size() - 1)]


func _get_weapon_rating(weapon_scene: PackedScene) -> int:
	var weapon_node: Node = weapon_scene.instantiate()
	var weapon := weapon_node as Weapon
	if weapon == null:
		weapon_node.free()
		return minimum_target_rating
	var rating: int = weapon.data.rating if weapon.data != null else minimum_target_rating
	weapon.free()
	return rating


func _get_distance_origin() -> Vector2:
	if distance_origin != null:
		return distance_origin.global_position
	return Vector2.ZERO


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
