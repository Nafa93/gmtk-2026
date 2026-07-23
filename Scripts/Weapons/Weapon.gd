class_name Weapon
extends Node2D

@export var data: WeaponData
@export var weapon_sprite: Sprite2D
@export var muzzle: Marker2D
@export var fire_audio: AudioStreamPlayer2D
@export var animation_player: AnimationPlayer
@export var muzzle_flash: GPUParticles2D

var _is_active: bool = false


func _ready() -> void:
	deactivate()


func activate() -> void:
	_is_active = true
	visible = true
	set_process(true)
	set_physics_process(true)


func deactivate() -> void:
	_is_active = false
	visible = false
	set_process(false)
	set_physics_process(false)

	if fire_audio != null and fire_audio.playing:
		fire_audio.stop()

	if animation_player != null and animation_player.is_playing():
		animation_player.stop()

	if muzzle_flash != null:
		muzzle_flash.emitting = false


func play_fire_effects() -> void:
	if not _is_active:
		return

	if fire_audio != null and fire_audio.stream != null:
		fire_audio.play()

	if animation_player != null and animation_player.has_animation(&"fire"):
		animation_player.play(&"fire")

	if muzzle_flash != null:
		muzzle_flash.restart()
		muzzle_flash.emitting = true


func get_muzzle_position() -> Vector2:
	if muzzle == null:
		push_warning("Weapon '%s' has no Muzzle assigned." % name)
		return global_position

	return muzzle.global_position


func get_muzzle_direction() -> Vector2:
	if muzzle == null:
		push_warning("Weapon '%s' has no Muzzle assigned." % name)
		return -global_transform.y.normalized()

	var muzzle_direction: Vector2 = global_position.direction_to(muzzle.global_position)
	if muzzle_direction.is_zero_approx():
		return -global_transform.y.normalized()

	return muzzle_direction
