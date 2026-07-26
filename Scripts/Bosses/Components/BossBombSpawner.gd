class_name BossBombSpawner
extends Node

@export var bomb_scene: PackedScene
@export_range(0.0, 500.0, 1.0, "or_greater") var target_scatter: float = 90.0

var _boss: BossController


func _ready() -> void:
	_boss = get_parent().get_parent() as BossController


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
		bomb.global_position = center + Vector2.RIGHT.rotated(angle) * target_scatter
	return count
