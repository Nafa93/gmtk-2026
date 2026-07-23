class_name BossTargeting
extends Node

@export var target_group: StringName = &"player"

var target: Node2D
var locked_direction: Vector2 = Vector2.DOWN


func refresh_target() -> void:
	if is_target_valid():
		return

	target = get_tree().get_first_node_in_group(target_group) as Node2D


func is_target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.is_inside_tree()


func get_distance_from(origin: Vector2) -> float:
	if not is_target_valid():
		return INF

	return origin.distance_to(target.global_position)


func get_direction_from(origin: Vector2) -> Vector2:
	if not is_target_valid():
		return Vector2.ZERO

	return origin.direction_to(target.global_position)


func lock_direction_from(origin: Vector2) -> Vector2:
	var candidate_direction: Vector2 = get_direction_from(origin)
	if not candidate_direction.is_zero_approx():
		locked_direction = candidate_direction

	if locked_direction.is_zero_approx():
		locked_direction = Vector2.DOWN

	return locked_direction
