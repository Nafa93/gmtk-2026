extends CharacterBody2D

@export var health_component: HealthComponent
@export var movement_component: MovementComponent

@onready var player = get_tree().get_first_node_in_group("player") as CharacterBody2D

func _ready() -> void:
	$AnimatedSprite2D.modulate = Color.RED

func _process(delta: float) -> void:
	velocity = movement_component.get_velocity()
	
	if player != null:
		rotation = movement_component.get_rotation(global_position, player.global_position)

	move_and_slide()
