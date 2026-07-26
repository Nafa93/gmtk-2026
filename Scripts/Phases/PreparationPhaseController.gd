class_name PreparationPhaseController
extends Node

signal state_changed(new_state: PhaseState)
signal player_resolved(player: PlayerController)
signal time_remaining_changed(seconds_remaining: float)
signal warning_started(seconds_remaining: float)
signal warning_ended
signal interactions_enabled_changed(enabled: bool)
signal boss_hold_progress_changed(progress: float)
signal boss_hold_cancelled
signal boss_start_blocked(minimum_time: float)
signal boss_interaction_availability_changed(available: bool)
signal phase_finishing
signal transition_started(next_scene: PackedScene)
signal phase_completed

enum PhaseState {
	INITIALIZING,
	LOOTING,
	FINISHING,
	TRANSITIONING,
	COMPLETED,
}

@export_group("Boss Start")
@export var allow_early_boss_start: bool = true
@export_range(0.1, 10.0, 0.1, "or_greater") var boss_start_hold_duration: float = 1.0
@export_range(0.0, 120.0, 0.5, "or_greater") var minimum_boss_entry_time: float = 5.0
@export_range(0.0, 30.0, 0.1, "or_greater") var transition_delay: float = 1.0
@export var next_boss_scene: PackedScene
@export var defeat_scene: PackedScene
@export var start_with_empty_loadout: bool = true

@export_group("References")
@export var player: PlayerController
@export var display_tick_timer: Timer
@export var transition_timer: Timer
@export var boss_hold_timer: Timer

var current_state: PhaseState = PhaseState.INITIALIZING
var interactions_enabled: bool = false

var _time_health: TimeHealthComponent
var _finish_requested: bool = false
var _hold_active: bool = false
var _boss_interaction_available: bool = false


func _ready() -> void:
	add_to_group(&"preparation_phase_controller")
	if not _validate_references():
		return
	_connect_timers()
	call_deferred(&"_initialize_phase")


func finish_phase() -> void:
	if _finish_requested or current_state != PhaseState.LOOTING:
		return
	if _time_health == null or _time_health.is_dead():
		return

	_finish_requested = true
	_cancel_boss_hold(false)
	_set_interactions_enabled(false)
	_time_health.pause_timer()
	_set_state(PhaseState.FINISHING)
	phase_finishing.emit()
	_capture_phase_result()

	if transition_delay <= 0.0:
		_begin_transition()
	else:
		transition_timer.start(transition_delay)


func can_interact() -> bool:
	return interactions_enabled and current_state == PhaseState.LOOTING


func get_time_remaining() -> float:
	return _time_health.current_time if _time_health != null else 0.0


func begin_boss_interaction() -> bool:
	if (
		not allow_early_boss_start
		or not _boss_interaction_available
		or not can_interact()
	):
		return false
	return _begin_boss_hold()


func cancel_boss_interaction() -> void:
	_cancel_boss_hold()


func set_boss_interaction_available(available: bool) -> void:
	var effective_availability: bool = available and allow_early_boss_start
	if effective_availability == _boss_interaction_available:
		return
	_boss_interaction_available = effective_availability
	boss_interaction_availability_changed.emit(effective_availability)


func start_boss_immediately_debug() -> void:
	if not OS.is_debug_build():
		return
	finish_phase()


func _initialize_phase() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as PlayerController
	if player == null:
		push_error("PreparationPhaseController could not find the player.")
		return

	_time_health = player.health_component as TimeHealthComponent
	if _time_health == null:
		push_error("Preparation phase player requires TimeHealthComponent.")
		return

	if start_with_empty_loadout and player.weapon_component != null:
		player.weapon_component.clear_all_weapons()
		var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
		if run_state != null:
			run_state.clear_loadout()

	_connect_time_health()
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null:
		run_state.mark_preparation_started(_time_health)

	player_resolved.emit(player)
	time_remaining_changed.emit(_time_health.current_time)
	_set_interactions_enabled(true)
	_set_state(PhaseState.LOOTING)
	_time_health.resume_timer()
	if not _time_health.is_timer_running:
		_time_health.start_timer()
	display_tick_timer.start()


func _connect_time_health() -> void:
	if not _time_health.time_changed.is_connected(_on_time_changed):
		_time_health.time_changed.connect(_on_time_changed)
	if not _time_health.critical_entered.is_connected(_on_critical_entered):
		_time_health.critical_entered.connect(_on_critical_entered)
	if not _time_health.critical_exited.is_connected(_on_critical_exited):
		_time_health.critical_exited.connect(_on_critical_exited)
	if not _time_health.depleted.is_connected(_on_time_depleted):
		_time_health.depleted.connect(_on_time_depleted)


func _connect_timers() -> void:
	if not display_tick_timer.timeout.is_connected(_on_display_tick):
		display_tick_timer.timeout.connect(_on_display_tick)
	if not transition_timer.timeout.is_connected(_begin_transition):
		transition_timer.timeout.connect(_begin_transition)
	if not boss_hold_timer.timeout.is_connected(_on_boss_hold_completed):
		boss_hold_timer.timeout.connect(_on_boss_hold_completed)


func _begin_boss_hold() -> bool:
	if _hold_active or _time_health == null:
		return false
	if _time_health.current_time < minimum_boss_entry_time:
		boss_start_blocked.emit(minimum_boss_entry_time)
		return false

	_hold_active = true
	boss_hold_progress_changed.emit(0.0)
	boss_hold_timer.start(boss_start_hold_duration)
	return true


func _cancel_boss_hold(emit_signal: bool = true) -> void:
	if not _hold_active:
		return
	_hold_active = false
	boss_hold_timer.stop()
	boss_hold_progress_changed.emit(0.0)
	if emit_signal:
		boss_hold_cancelled.emit()


func _on_display_tick() -> void:
	if not _hold_active:
		return
	var progress: float = 1.0 - (
		boss_hold_timer.time_left / maxf(boss_start_hold_duration, 0.001)
	)
	boss_hold_progress_changed.emit(clampf(progress, 0.0, 1.0))


func _on_boss_hold_completed() -> void:
	if not _hold_active:
		return
	_hold_active = false
	boss_hold_progress_changed.emit(1.0)
	finish_phase()


func _on_time_changed(current_time: float, _maximum_time: float) -> void:
	time_remaining_changed.emit(current_time)


func _on_critical_entered() -> void:
	warning_started.emit(_time_health.current_time)


func _on_critical_exited() -> void:
	warning_ended.emit()


func _on_time_depleted() -> void:
	if _finish_requested:
		return
	_finish_requested = true
	_cancel_boss_hold(false)
	display_tick_timer.stop()
	transition_timer.stop()
	_set_interactions_enabled(false)
	_set_state(PhaseState.COMPLETED)
	phase_completed.emit()
	if defeat_scene != null:
		get_tree().call_deferred(&"change_scene_to_packed", defeat_scene)


func _begin_transition() -> void:
	if current_state != PhaseState.FINISHING:
		return
	transition_timer.stop()
	_set_state(PhaseState.TRANSITIONING)
	if next_boss_scene == null:
		push_error("PreparationPhaseController requires next_boss_scene.")
		_time_health.resume_timer()
		_finish_requested = false
		_set_interactions_enabled(true)
		_set_state(PhaseState.LOOTING)
		return

	transition_started.emit(next_boss_scene)
	_set_state(PhaseState.COMPLETED)
	phase_completed.emit()
	var error: Error = get_tree().change_scene_to_packed(next_boss_scene)
	if error != OK:
		push_error("Boss scene transition failed: %s." % error_string(error))


func _capture_phase_result() -> void:
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state == null:
		push_warning("RunLoadout is unavailable; run state cannot persist.")
		return
	if player.weapon_component != null:
		run_state.capture_from(player.weapon_component)
	run_state.capture_time_from(_time_health)


func _set_interactions_enabled(enabled: bool) -> void:
	if interactions_enabled == enabled:
		return
	interactions_enabled = enabled
	interactions_enabled_changed.emit(enabled)


func _set_state(new_state: PhaseState) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func _validate_references() -> bool:
	var valid: bool = true
	if display_tick_timer == null:
		push_error("PreparationPhaseController requires DisplayTickTimer.")
		valid = false
	if transition_timer == null:
		push_error("PreparationPhaseController requires TransitionTimer.")
		valid = false
	if boss_hold_timer == null:
		push_error("PreparationPhaseController requires BossHoldTimer.")
		valid = false
	return valid
