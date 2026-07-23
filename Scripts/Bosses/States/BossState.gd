class_name BossState
extends Node

@export var state_name: StringName

var boss: BossController
var state_machine: BossStateMachine


func setup(
	boss_controller: BossController,
	machine: BossStateMachine
) -> void:
	boss = boss_controller
	state_machine = machine


func enter(_context: Dictionary = {}) -> void:
	pass


func exit() -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


func after_move() -> void:
	pass
