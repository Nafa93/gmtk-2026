class_name BossMinionController
extends CharacterBody2D

@export var health_component: HealthComponent
@export_range(1.0, 1000.0, 1.0, "or_greater") var movement_speed: float = 190.0
@export_range(1, 100, 1, "or_greater") var contact_damage: int = 2
@export_range(0.1, 10.0, 0.05, "or_greater") var contact_cooldown: float = 0.8
@export_range(0.0, 2000.0, 10.0, "or_greater") var knockback_strength: float = 420.0

var _player: PlayerController
var _contact_cooldown_remaining: float = 0.0


func _ready() -> void:
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController
	if health_component == null:
		push_error("BossMinionController requires a HealthComponent.")


func _physics_process(delta: float) -> void:
	_contact_cooldown_remaining = maxf(
		_contact_cooldown_remaining - delta,
		0.0
	)
	_resolve_player()

	if _player == null:
		velocity = Vector2.ZERO
	else:
		velocity = global_position.direction_to(
			_player.global_position
		) * movement_speed

	move_and_slide()
	_apply_contact_damage()


func _resolve_player() -> void:
	if _player != null and is_instance_valid(_player):
		return
	_player = get_tree().get_first_node_in_group(&"player") as PlayerController


func _apply_contact_damage() -> void:
	if _contact_cooldown_remaining > 0.0:
		return

	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		var player := collision.get_collider() as PlayerController
		if player == null:
			continue

		var time_health := player.health_component as TimeHealthComponent
		if time_health == null:
			return
		var applied_damage: float = time_health.take_time_damage(
			float(contact_damage),
			&"minion_contact"
		)
		if applied_damage > 0.0:
			player.apply_knockback(global_position, knockback_strength)
			_contact_cooldown_remaining = contact_cooldown
		return
