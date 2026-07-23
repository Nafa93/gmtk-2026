class_name Projectile
extends Area2D

const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const PLAYER_PROJECTILE_LAYER: int = 4
const ENEMY_LAYER: int = 8
const ENEMY_PROJECTILE_LAYER: int = 16

@export_range(0.1, 60.0, 0.1, "or_greater") var max_lifetime: float = 5.0

var direction: Vector2 = Vector2.ZERO
var speed: float = 0.0
var damage: int = 0
var shooter: Node = null

var _elapsed_lifetime: float = 0.0
var _has_impacted: bool = false


func initialize(
	initial_direction: Vector2,
	initial_speed: float,
	initial_damage: int,
	shooting_actor: Node
) -> void:
	direction = initial_direction.normalized()
	speed = maxf(initial_speed, 0.0)
	damage = maxi(initial_damage, 0)
	shooter = shooting_actor
	_configure_collision_for_shooter()


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

	_elapsed_lifetime += delta
	if _elapsed_lifetime >= max_lifetime:
		queue_free()


func _on_body_entered(body: Node2D) -> void:
	_handle_impact(body)


func _on_area_entered(area: Area2D) -> void:
	_handle_impact(area)


func _handle_impact(hit_object: Node) -> void:
	if _has_impacted or _belongs_to_shooter(hit_object):
		return

	_has_impacted = true
	set_deferred(&"monitoring", false)

	var health_component: HealthComponent = _find_health_component(hit_object)
	if health_component != null:
		health_component.take_damage(damage)

	queue_free()


func _belongs_to_shooter(hit_object: Node) -> bool:
	if shooter == null or not is_instance_valid(shooter):
		return false

	return hit_object == shooter or shooter.is_ancestor_of(hit_object)


func _find_health_component(start_node: Node) -> HealthComponent:
	var current_node: Node = start_node

	while current_node != null:
		if current_node is HealthComponent:
			return current_node as HealthComponent

		for child: Node in current_node.get_children():
			if child is HealthComponent:
				return child as HealthComponent

		current_node = current_node.get_parent()

	return null


func _configure_collision_for_shooter() -> void:
	if shooter == null or not is_instance_valid(shooter):
		collision_layer = PLAYER_PROJECTILE_LAYER
		collision_mask = WORLD_LAYER | PLAYER_LAYER | ENEMY_LAYER
		push_warning(
			"Projectile initialized without a valid shooter; it will collide with both teams."
		)
		return

	if shooter.is_in_group(&"player"):
		collision_layer = PLAYER_PROJECTILE_LAYER
		collision_mask = WORLD_LAYER | ENEMY_LAYER
		return

	if shooter.is_in_group(&"enemy"):
		collision_layer = ENEMY_PROJECTILE_LAYER
		collision_mask = WORLD_LAYER | PLAYER_LAYER
		return

	collision_layer = PLAYER_PROJECTILE_LAYER
	collision_mask = WORLD_LAYER | PLAYER_LAYER | ENEMY_LAYER
	push_warning(
		(
			"Projectile shooter '%s' is not in the 'player' or 'enemy' group; "
			+ "the projectile will collide with both teams."
		)
		% shooter.name
	)
