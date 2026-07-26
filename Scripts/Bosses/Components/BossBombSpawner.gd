class_name BossBombSpawner
extends Node

@export var bomb_scene: PackedScene
@export_range(0.0, 500.0, 1.0, "or_greater") var target_scatter: float = 90.0
@export_group("Periodic Throws")
@export_range(0.25, 60.0, 0.25, "or_greater") var periodic_interval: float = 5.0
@export_range(0.0, 60.0, 0.25, "or_greater") var initial_delay: float = 2.5
@export_range(1, 10, 1, "or_greater") var periodic_bomb_count: int = 1
@export_range(0.05, 2.0, 0.05, "or_greater") var throw_duration: float = 0.45

var _boss: BossController
var _periodic_timer: float


func _ready() -> void:
	_boss = get_parent().get_parent() as BossController
	_periodic_timer = initial_delay


func _process(delta: float) -> void:
	if _boss == null or _boss.is_dead():
		return
	_periodic_timer -= delta
	if _periodic_timer > 0.0:
		return
	throw_bombs(periodic_bomb_count)
	_periodic_timer = periodic_interval


func throw_bombs(count: int) -> int:
	if _boss == null or bomb_scene == null or count <= 0:
		return 0
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	var center: Vector2 = player.global_position if player != null else _boss.global_position
	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		return 0
	for index: int in range(count):
		var bomb_node: Node = bomb_scene.instantiate()
		var bomb := bomb_node as Node2D
		if bomb == null:
			bomb_node.free()
			continue
		scene_root.add_child(bomb)
		var angle: float = TAU * float(index) / maxf(float(count), 1.0)
		var target_position: Vector2 = (
			center + Vector2.RIGHT.rotated(angle) * target_scatter
		)
		bomb.global_position = _boss.global_position
		var throw_tween: Tween = bomb.create_tween()
		throw_tween.set_trans(Tween.TRANS_QUAD)
		throw_tween.set_ease(Tween.EASE_OUT)
		throw_tween.tween_property(
			bomb,
			^"global_position",
			target_position,
			throw_duration
		)
	return count
