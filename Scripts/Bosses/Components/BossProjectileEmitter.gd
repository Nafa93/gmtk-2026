class_name BossProjectileEmitter
extends Node

@export var projectile_origin: Marker2D
@export var projectile_scene: PackedScene


func fire(
	shooter: Node2D,
	direction: Vector2,
	speed: float,
	damage: int
) -> bool:
	if shooter == null or not is_instance_valid(shooter):
		push_error("BossProjectileEmitter requires a valid shooter.")
		return false
	if projectile_scene == null:
		push_warning("BossProjectileEmitter has no projectile_scene assigned.")
		return false
	if direction.is_zero_approx():
		push_warning("BossProjectileEmitter cannot fire with zero direction.")
		return false

	var projectile_node: Node = projectile_scene.instantiate()
	var projectile: Projectile = projectile_node as Projectile
	if projectile == null:
		projectile_node.free()
		push_error("Boss projectile_scene root must extend Projectile.")
		return false

	var scene_root: Node = shooter.get_tree().current_scene
	if scene_root == null:
		projectile.free()
		push_error("BossProjectileEmitter requires a current scene.")
		return false

	projectile.initialize(direction.normalized(), speed, damage, shooter)
	scene_root.add_child(projectile)
	projectile.global_position = projectile_origin.global_position \
			if projectile_origin != null else shooter.global_position
	projectile.global_rotation = direction.angle()
	return true
