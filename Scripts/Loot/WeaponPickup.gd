class_name WeaponPickup
extends Area2D

## Escena Weapon que representa este pickup y que se equipará en el futuro.
@export var weapon_scene: PackedScene
@export var visual_root: Node2D
@export var name_label: Label

var weapon_preview: Weapon


func _ready() -> void:
	_build_preview()


func configure(selected_weapon_scene: PackedScene) -> void:
	weapon_scene = selected_weapon_scene


func get_weapon_scene() -> PackedScene:
	return weapon_scene


func _build_preview() -> void:
	if weapon_scene == null:
		push_warning("WeaponPickup has no weapon_scene assigned.")
		return
	if visual_root == null:
		push_error("WeaponPickup requires a visual_root.")
		return

	var weapon_node: Node = weapon_scene.instantiate()
	weapon_preview = weapon_node as Weapon
	if weapon_preview == null:
		weapon_node.free()
		push_error("WeaponPickup weapon_scene root must extend Weapon.")
		return

	visual_root.add_child(weapon_preview)
	weapon_preview.position = Vector2.ZERO
	weapon_preview.rotation = 0.0
	weapon_preview.activate()

	if name_label != null:
		if weapon_preview.data != null:
			name_label.text = weapon_preview.data.weapon_name
		else:
			name_label.text = weapon_preview.name
