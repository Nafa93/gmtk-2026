class_name BossEntranceInteractable
extends Area2D

signal availability_changed(available: bool)

@export var phase_controller: PreparationPhaseController

var _players_in_range: Array[PlayerController] = []
var _transition_requested: bool = false


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


func _on_body_entered(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null or player in _players_in_range:
		return
	_players_in_range.append(player)
	_try_transition()


func _on_body_exited(body: Node2D) -> void:
	var player := body as PlayerController
	if player == null:
		return
	_players_in_range.erase(player)


func _on_tree_exiting() -> void:
	_players_in_range.clear()


func _on_interactions_enabled_changed(_enabled: bool) -> void:
	_try_transition()


func _try_transition() -> void:
	if (
		_transition_requested
		or _players_in_range.is_empty()
		or phase_controller == null
		or not phase_controller.can_interact()
	):
		return
	_transition_requested = true
	availability_changed.emit(false)
	phase_controller.set_boss_interaction_available(false)
	phase_controller.finish_phase()
