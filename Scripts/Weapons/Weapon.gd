class_name Weapon
extends Node2D

@export var data: WeaponData
@export var weapon_sprite: Sprite2D
@export var muzzle: Marker2D
@export var fire_audio: AudioStreamPlayer2D
@export var animation_player: AnimationPlayer
@export var muzzle_flash: GPUParticles2D


func play_fire_effects() -> void:
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
		return global_transform.x.normalized()

	return muzzle.global_transform.x.normalized()
