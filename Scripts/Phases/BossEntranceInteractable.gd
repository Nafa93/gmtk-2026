class_name BossEntranceInteractable
extends Area2D

signal availability_changed(available: bool)

@export var phase_controller: PreparationPhaseController

var _players_in_range: Array[PlayerController] = []
var _interacting_player: PlayerController


func _ready() -> void:
	if phase_controller == null:
		phase_controller = get_tree().get_first_node_in_group(
			&"preparation_phase_controller"
		) as PreparationPhaseController
	if phase_controller == null:
		push_error("BossEntranceInteractable requires a PreparationPhaseController.")
		return

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	tree_exiting.connect(_on_tree_exiting)
	phase_controller.interactions_enabled_changed.connect(
		_on_interactions_enabled_changed
	)


func _physics_process(_delta: float) -> void:
	if _interacting_player == null:
		return
	if not Input.is_action_pressed(&"INTERACT"):
		_cancel_interaction()


func interact(player: PlayerController) -> bool:
	if (
		player == null
		or player not in _players_in_range
		or phase_controller == null
		or not phase_controller.can_interact()
	):
		return false

	_interacting_player = player
	if not phase_controller.begin_boss_interaction():
		_interacting_player = null
		return false
	return true


func _on_body_entered(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null or player in _players_in_range:
		return
	_players_in_range.append(player)
	player.register_interactable(self)
	_update_availability()


func _on_body_exited(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null:
		return
	_players_in_range.erase(player)
	player.unregister_interactable(self)
	if player == _interacting_player:
		_cancel_interaction()
	_update_availability()


func _on_tree_exiting() -> void:
	for player: PlayerController in _players_in_range:
		if player != null and is_instance_valid(player):
			player.unregister_interactable(self)
	_players_in_range.clear()
	_cancel_interaction()


func _on_interactions_enabled_changed(_enabled: bool) -> void:
	if phase_controller == null or not phase_controller.can_interact():
		_cancel_interaction()
	_update_availability()


func _cancel_interaction() -> void:
	if _interacting_player == null:
		return
	_interacting_player = null
	if phase_controller != null:
		phase_controller.cancel_boss_interaction()


func _update_availability() -> void:
	var available: bool = (
		not _players_in_range.is_empty()
		and phase_controller != null
		and phase_controller.can_interact()
	)
	availability_changed.emit(available)
	phase_controller.set_boss_interaction_available(available)
