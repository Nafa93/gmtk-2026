class_name WeaponPickup
extends Area2D

signal weapon_collected(
	player: PlayerController,
	weapon_scene: PackedScene,
	slot: int
)
signal weapon_replaced(
	player: PlayerController,
	equipped_scene: PackedScene,
	dropped_scene: PackedScene,
	slot: int
)

@export var weapon_scene: PackedScene
@export var visual_root: Node2D
@export var name_label: Label

var weapon_preview: Weapon

var _phase_controller: PreparationPhaseController
var _players_in_range: Array[PlayerController] = []


func _ready() -> void:
	_build_preview()
	_phase_controller = get_tree().get_first_node_in_group(
		&"preparation_phase_controller"
	) as PreparationPhaseController
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	if not tree_exiting.is_connected(_on_tree_exiting):
		tree_exiting.connect(_on_tree_exiting)


func configure(selected_weapon_scene: PackedScene) -> void:
	weapon_scene = selected_weapon_scene
	if is_inside_tree():
		_build_preview()


func get_weapon_scene() -> PackedScene:
	return weapon_scene


func interact(player: PlayerController) -> bool:
	if player == null or player not in _players_in_range:
		return false
	if not _can_collect():
		return false

	var component: WeaponComponent = player.weapon_component
	if component == null:
		push_warning("WeaponPickup found a player without WeaponComponent.")
		return false

	var empty_slot: int = component.get_first_empty_slot()
	if empty_slot >= 0:
		return _collect_into_empty_slot(player, component, empty_slot)
	return _replace_active_weapon(player, component)


func _build_preview() -> void:
	if weapon_scene == null:
		push_warning("WeaponPickup has no weapon_scene assigned.")
		return
	if visual_root == null:
		push_error("WeaponPickup requires a visual_root.")
		return

	if weapon_preview != null and is_instance_valid(weapon_preview):
		weapon_preview.free()
	weapon_preview = null

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


func _on_body_entered(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null or player in _players_in_range:
		return

	_players_in_range.append(player)
	if not _can_collect() or player.weapon_component == null:
		return

	var empty_slot: int = player.weapon_component.get_first_empty_slot()
	if empty_slot >= 0:
		_collect_into_empty_slot(player, player.weapon_component, empty_slot)
	else:
		player.register_interactable(self)


func _on_body_exited(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null:
		return
	_players_in_range.erase(player)
	player.unregister_interactable(self)


func _on_tree_exiting() -> void:
	for player: PlayerController in _players_in_range:
		if player != null and is_instance_valid(player):
			player.unregister_interactable(self)
	_players_in_range.clear()


func _collect_into_empty_slot(
	player: PlayerController,
	component: WeaponComponent,
	slot: int
) -> bool:
	var collected_scene: PackedScene = weapon_scene
	if collected_scene == null or not component.equip_weapon(collected_scene, slot):
		return false

	weapon_collected.emit(player, collected_scene, slot)
	player.unregister_interactable(self)
	queue_free()
	return true


func _replace_active_weapon(
	player: PlayerController,
	component: WeaponComponent
) -> bool:
	var slot: int = component.active_slot_index
	var dropped_scene: PackedScene = component.get_weapon_scene_in_slot(slot)
	if dropped_scene == null:
		push_warning(
			"WeaponPickup cannot leave the active weapon on the floor because "
			+ "its source PackedScene is unknown."
		)
		return false

	var equipped_scene: PackedScene = weapon_scene
	if equipped_scene == null or not component.equip_weapon(equipped_scene, slot):
		return false

	configure(dropped_scene)
	weapon_replaced.emit(player, equipped_scene, dropped_scene, slot)
	return true


func _can_collect() -> bool:
	return _phase_controller == null or _phase_controller.can_interact()
