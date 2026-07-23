class_name BossController
extends CharacterBody2D

signal phase_changed(new_phase: int)
signal boss_died
signal state_changed(new_state: StringName)

@export_group("Required References")
@export var health_component: HealthComponent
@export var boss_sprite: CanvasItem
@export var collision_shape: CollisionShape2D

@export_group("Boss Components")
@export var state_machine: BossStateMachine
@export var dead_state: BossState
@export var targeting: BossTargeting
@export var attack_scheduler: BossAttackScheduler
@export var projectile_emitter: BossProjectileEmitter
@export var telegraph_presenter: BossTelegraphPresenter
@export var phase_controller: BossPhaseController

@export_group("Movement")
@export_range(0.0, 10000.0, 1.0, "or_greater") var movement_speed: float = 115.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var preferred_minimum_distance: float = 260.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var preferred_maximum_distance: float = 430.0
@export_range(0.05, 30.0, 0.05, "or_greater") var reposition_duration: float = 1.25

var _is_dead: bool = false

var attacks: Array[BossAttack]:
	get:
		return attack_scheduler.attacks if attack_scheduler != null else []

var current_phase: int:
	get:
		return phase_controller.current_phase if phase_controller != null else 1

var current_state: StringName:
	get:
		if state_machine == null or state_machine.current_state == null:
			return &""
		return state_machine.current_state.state_name

var phase_two_projectile_speed_multiplier: float:
	get:
		if phase_controller == null:
			return 1.0
		return phase_controller.phase_two_projectile_speed_multiplier


func _ready() -> void:
	if not _validate_required_references():
		set_physics_process(false)
		return

	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	if not phase_controller.phase_changed.is_connected(_on_phase_changed):
		phase_controller.phase_changed.connect(_on_phase_changed)
	if not state_machine.state_changed.is_connected(_on_state_changed):
		state_machine.state_changed.connect(_on_state_changed)

	targeting.refresh_target()
	attack_scheduler.initialize()
	phase_controller.initialize(health_component, boss_sprite)
	state_machine.initialize(self)


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	targeting.refresh_target()
	attack_scheduler.physics_update(delta)
	state_machine.physics_update(delta)

	if _is_dead or state_machine.current_state == dead_state:
		return

	move_and_slide()
	state_machine.after_move()


func spawn_boss_projectile(
	direction: Vector2,
	speed: float,
	damage: int
) -> bool:
	if _is_dead:
		return false
	return projectile_emitter.fire(self, direction, speed, damage)


func lock_attack_direction_to_target() -> void:
	var locked_direction: Vector2 = targeting.lock_direction_from(global_position)
	rotation = locked_direction.angle() + PI / 2.0


func get_locked_attack_direction() -> Vector2:
	return targeting.locked_direction


func show_direction_telegraph(
	direction: Vector2,
	length: float,
	width: float,
	color: Color
) -> void:
	telegraph_presenter.show_direction(self, direction, length, width, color)


func show_radial_telegraph(radius: float, color: Color) -> void:
	telegraph_presenter.show_radial(radius, color)


func hide_telegraphs() -> void:
	telegraph_presenter.hide_all()


func play_attack_effects() -> void:
	telegraph_presenter.play_attack_effects()


func find_health_component(start_node: Node) -> HealthComponent:
	var current_node: Node = start_node
	while current_node != null:
		if current_node is HealthComponent:
			return current_node as HealthComponent
		for child: Node in current_node.get_children():
			if child is HealthComponent:
				return child as HealthComponent
		current_node = current_node.get_parent()
	return null


func perform_death_cleanup() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	telegraph_presenter.stop_all()

	if telegraph_presenter.animation_player != null:
		if telegraph_presenter.animation_player.has_animation(&"dead"):
			telegraph_presenter.animation_player.play(&"dead")

	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)
	collision_layer = 0
	collision_mask = 0
	set_physics_process(false)
	boss_died.emit()


func is_dead() -> bool:
	return _is_dead


func _validate_required_references() -> bool:
	var is_valid: bool = true
	if health_component == null:
		push_error("BossController requires a HealthComponent.")
		is_valid = false
	if state_machine == null:
		push_error("BossController requires a BossStateMachine.")
		is_valid = false
	if dead_state == null:
		push_error("BossController requires a DeadState.")
		is_valid = false
	if targeting == null:
		push_error("BossController requires BossTargeting.")
		is_valid = false
	if attack_scheduler == null:
		push_error("BossController requires BossAttackScheduler.")
		is_valid = false
	if projectile_emitter == null:
		push_error("BossController requires BossProjectileEmitter.")
		is_valid = false
	if telegraph_presenter == null:
		push_error("BossController requires BossTelegraphPresenter.")
		is_valid = false
	if phase_controller == null:
		push_error("BossController requires BossPhaseController.")
		is_valid = false
	return is_valid


func _on_phase_changed(new_phase: int) -> void:
	phase_changed.emit(new_phase)


func _on_state_changed(
	_previous_state: BossState,
	new_state: BossState
) -> void:
	state_changed.emit(new_state.state_name)


func _on_died() -> void:
	if _is_dead:
		return
	state_machine.change_state(dead_state)
