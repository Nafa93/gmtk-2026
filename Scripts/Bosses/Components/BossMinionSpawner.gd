class_name BossMinionSpawner
extends Node

signal minion_spawned(minion: Node2D)
signal minion_defeated(time_reward: float)

@export var minion_scene: PackedScene
@export_range(0, 100, 1, "or_greater") var maximum_total_minions: int = 6
@export_range(0, 20, 1, "or_greater") var maximum_alive_minions: int = 2
@export_range(0.0, 1000.0, 1.0, "or_greater") var spawn_radius: float = 180.0
@export_range(0.0, 120.0, 0.5, "or_greater") var minion_time_reward: float = 2.0

var total_spawned: int = 0

var _boss: BossController
var _alive_minions: Array[Node2D] = []
var _rewarded_minions: Dictionary = {}
var _encounter_active: bool = true


func _ready() -> void:
	_boss = get_parent().get_parent() as BossController
	if _boss == null:
		push_error("BossMinionSpawner must be under a BossController.")
		return
	if not _boss.boss_died.is_connected(_on_boss_died):
		_boss.boss_died.connect(_on_boss_died)


func spawn_minions(requested_count: int) -> int:
	if not _encounter_active or minion_scene == null or requested_count <= 0:
		return 0
	_prune_minions()

	var total_capacity: int = maximum_total_minions - total_spawned
	var alive_capacity: int = maximum_alive_minions - _alive_minions.size()
	var spawn_count: int = mini(requested_count, mini(total_capacity, alive_capacity))
	if spawn_count <= 0:
		return 0

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return 0

	for index: int in range(spawn_count):
		var minion_node: Node = minion_scene.instantiate()
		var minion := minion_node as Node2D
		if minion == null:
			minion_node.free()
			continue

		scene_root.add_child(minion)
		var angle: float = TAU * float(total_spawned + index) / maxf(
			float(maximum_total_minions),
			1.0
		)
		minion.global_position = _boss.global_position + Vector2.RIGHT.rotated(
			angle
		) * spawn_radius
		_alive_minions.append(minion)
		total_spawned += 1
		_connect_minion_death(minion)
		minion_spawned.emit(minion)

	return spawn_count


func _connect_minion_death(minion: Node2D) -> void:
	var health: HealthComponent = _find_health_component(minion)
	if health == null:
		push_warning("Spawned minion has no HealthComponent.")
		return
	health.died.connect(_on_minion_died.bind(minion), CONNECT_ONE_SHOT)


func _on_minion_died(minion: Node2D) -> void:
	if minion == null:
		return
	var minion_id: int = minion.get_instance_id()
	if _rewarded_minions.has(minion_id):
		return
	_rewarded_minions[minion_id] = true
	_alive_minions.erase(minion)

	if _encounter_active:
		var player := get_tree().get_first_node_in_group(&"player") as PlayerController
		var time_health: TimeHealthComponent = (
			player.health_component as TimeHealthComponent
			if player != null
			else null
		)
		if time_health != null and not time_health.is_dead():
			var granted: float = time_health.grant_time(
				minion_time_reward,
				&"minion_defeat"
			)
			if granted > 0.0:
				minion_defeated.emit(granted)

	minion.queue_free()


func _on_boss_died() -> void:
	_encounter_active = false


func _prune_minions() -> void:
	for index: int in range(_alive_minions.size() - 1, -1, -1):
		var minion: Node2D = _alive_minions[index]
		if minion == null or not is_instance_valid(minion):
			_alive_minions.remove_at(index)


func _find_health_component(actor: Node) -> HealthComponent:
	for child: Node in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
