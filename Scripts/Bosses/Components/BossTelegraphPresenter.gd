class_name BossTelegraphPresenter
extends Node

@export var direction_telegraph: Polygon2D
@export var radial_telegraph: Line2D
@export var animation_player: AnimationPlayer
@export var telegraph_audio: AudioStreamPlayer2D
@export var attack_audio: AudioStreamPlayer2D


func show_direction(
	owner: Node2D,
	direction: Vector2,
	length: float,
	width: float,
	color: Color
) -> void:
	hide_all()
	if direction_telegraph == null:
		return

	owner.rotation = direction.angle() + PI / 2.0
	var half_width: float = width * 0.5
	direction_telegraph.polygon = PackedVector2Array([
		Vector2(-half_width, 0.0),
		Vector2(half_width, 0.0),
		Vector2(half_width, -length),
		Vector2(-half_width, -length),
	])
	direction_telegraph.color = color
	direction_telegraph.visible = true
	play_telegraph_effects()


func show_radial(radius: float, color: Color) -> void:
	hide_all()
	if radial_telegraph == null:
		return

	var points := PackedVector2Array()
	var segment_count: int = 48
	for segment: int in range(segment_count + 1):
		var angle: float = TAU * float(segment) / float(segment_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)

	radial_telegraph.points = points
	radial_telegraph.default_color = color
	radial_telegraph.visible = true
	play_telegraph_effects()


func hide_all() -> void:
	if direction_telegraph != null:
		direction_telegraph.visible = false
	if radial_telegraph != null:
		radial_telegraph.visible = false


func play_telegraph_effects() -> void:
	if telegraph_audio != null and telegraph_audio.stream != null:
		telegraph_audio.play()
	if animation_player != null and animation_player.has_animation(&"telegraph"):
		animation_player.play(&"telegraph")


func play_attack_effects() -> void:
	if attack_audio != null and attack_audio.stream != null:
		attack_audio.play()
	if animation_player != null and animation_player.has_animation(&"attack"):
		animation_player.play(&"attack")


func stop_all() -> void:
	hide_all()
	if telegraph_audio != null:
		telegraph_audio.stop()
	if attack_audio != null:
		attack_audio.stop()
	if animation_player != null:
		animation_player.stop()
