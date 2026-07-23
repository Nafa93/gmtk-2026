class_name BossStateMachine
extends Node

signal state_changed(previous_state: BossState, current_state: BossState)

@export var initial_state: BossState

var current_state: BossState
var _boss: BossController


func initialize(boss: BossController) -> void:
	_boss = boss
	for child: Node in get_children():
		if child is BossState:
			(child as BossState).setup(boss, self)

	if initial_state == null:
		push_error("BossStateMachine requires an initial_state.")
		return

	change_state(initial_state)


func change_state(
	next_state: BossState,
	context: Dictionary = {}
) -> void:
	if next_state == null:
		push_error("BossStateMachine cannot transition to a null state.")
		return
	if current_state == next_state:
		return

	var previous_state: BossState = current_state
	if current_state != null:
		current_state.exit()

	current_state = next_state
	current_state.enter(context)
	state_changed.emit(previous_state, current_state)


func physics_update(delta: float) -> void:
	if current_state != null:
		current_state.physics_update(delta)


func after_move() -> void:
	if current_state != null:
		current_state.after_move()
