extends CharacterBody2D

@export var health_component: HealthComponent
@export var movement_component: MovementComponent
@export_range(1, 100, 1, "or_greater") var contact_damage: int = 2
@export_range(0.1, 10.0, 0.1, "or_greater") var contact_cooldown: float = 1.0

@onready var player := get_tree().get_first_node_in_group(
	&"player"
) as CharacterBody2D

var _contact_cooldown_remaining: float = 0.0


func _ready() -> void:
	$AnimatedSprite2D.modulate = Color.RED


func _physics_process(delta: float) -> void:
	_contact_cooldown_remaining = maxf(
		_contact_cooldown_remaining - delta,
		0.0
	)
	velocity = movement_component.get_velocity()
	if player != null:
		rotation = movement_component.get_rotation(
			global_position,
			player.global_position
		)
	move_and_slide()
	_apply_contact_damage()


func _apply_contact_damage() -> void:
	if _contact_cooldown_remaining > 0.0:
		return
	for collision_index: int in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(collision_index)
		var collider := collision.get_collider() as PlayerController
		if collider == null:
			continue
		var time_health := collider.health_component as TimeHealthComponent
		if time_health != null:
			var applied: float = time_health.take_time_damage(
				float(contact_damage),
				&"minion_contact"
			)
			if applied > 0.0:
				_contact_cooldown_remaining = contact_cooldown
		return
