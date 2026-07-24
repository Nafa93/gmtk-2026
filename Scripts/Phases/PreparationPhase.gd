extends Node2D

@export var phase_controller: PreparationPhaseController
@export var hud: PreparationHUD


func _ready() -> void:
	if phase_controller == null:
		push_error("PreparationPhase requires a PreparationPhaseController.")
		return
	if hud == null:
		push_error("PreparationPhase requires a PreparationHUD.")
		return

	hud.bind_to_controller(phase_controller)
