class_name BossBomb
extends Area2D

signal disarmed(time_reward: float)

@export var health_component: HealthComponent
@export_range(0.1, 10.0, 0.1, "or_greater") var fuse_duration: float = 2.0
@export_range(0.0, 120.0, 0.5, "or_greater") var disarm_time_reward: float = 2.0
@export_range(0.0, 1000.0, 1.0, "or_greater") var explosion_radius: float = 115.0
@export_range(0.0, 120.0, 0.5, "or_greater") var explosion_time_damage: float = 5.0

var _fuse_remaining: float
var _resolved: bool = false


func _ready() -> void:
	_fuse_remaining = fuse_duration
	if health_component == null:
		push_error("BossBomb requires a HealthComponent.")
		return
	health_component.died.connect(_on_destroyed, CONNECT_ONE_SHOT)


func _process(delta: float) -> void:
	if _resolved:
		return
	_fuse_remaining -= delta
	queue_redraw()
	if _fuse_remaining <= 0.0:
		_explode()


func _draw() -> void:
	var ratio: float = clampf(_fuse_remaining / maxf(fuse_duration, 0.01), 0.0, 1.0)
	draw_circle(Vector2.ZERO, 22.0, Color(0.12, 0.12, 0.16))
	draw_arc(Vector2.ZERO, 29.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, Color(1.0, 0.25, 0.08), 6.0)


func _on_destroyed() -> void:
	if _resolved:
		return
	_resolved = true
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	var time_health: TimeHealthComponent = (
		player.health_component as TimeHealthComponent if player != null else null
	)
	var granted: float = 0.0
	if time_health != null and not time_health.is_dead():
		granted = time_health.grant_time(disarm_time_reward, &"bomb_disarm")
	if granted > 0.0:
		disarmed.emit(granted)
	queue_free()


func _explode() -> void:
	if _resolved:
		return
	_resolved = true
	var player := get_tree().get_first_node_in_group(&"player") as PlayerController
	if player != null and global_position.distance_to(player.global_position) <= explosion_radius:
		var time_health := player.health_component as TimeHealthComponent
		if time_health != null:
			time_health.take_time_damage(explosion_time_damage, &"boss_bomb")
	queue_free()
