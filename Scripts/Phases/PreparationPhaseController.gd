class_name PreparationPhaseController
extends Node

signal state_changed(new_state: PhaseState)
signal player_resolved(player: PlayerController)
signal time_remaining_changed(seconds_remaining: float)
signal warning_started(seconds_remaining: float)
signal interactions_enabled_changed(enabled: bool)
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

@export_group("Phase Configuration")
## Duración disponible para explorar y recoger armas.
@export_range(1.0, 3600.0, 1.0, "or_greater") var total_duration: float = 60.0
## Segundos finales durante los que se activa la advertencia del HUD.
@export_range(0.0, 300.0, 0.5, "or_greater") var warning_duration: float = 10.0
## Espera entre el fin del looteo y el cambio a la escena del jefe.
@export_range(0.0, 30.0, 0.1, "or_greater") var transition_delay: float = 1.5
## Escena que se cargará cuando termine la fase de preparación.
@export var next_boss_scene: PackedScene
## Si está activo, el jugador comienza esta fase sin armas.
@export var start_with_empty_loadout: bool = true

@export_group("References")
## Referencia opcional al jugador. Si está vacía, se busca el primer nodo del grupo "player".
@export var player: PlayerController
@export var countdown_timer: Timer
@export var display_tick_timer: Timer
@export var transition_timer: Timer

var current_state: PhaseState = PhaseState.INITIALIZING
var interactions_enabled: bool = false

var _warning_emitted: bool = false
var _finish_requested: bool = false


func _ready() -> void:
	add_to_group(&"preparation_phase_controller")
	if not _validate_references():
		return

	_connect_timers()
	call_deferred(&"_initialize_phase")


func finish_phase() -> void:
	if _finish_requested or current_state != PhaseState.LOOTING:
		return

	_finish_requested = true
	countdown_timer.stop()
	display_tick_timer.stop()
	_emit_time_remaining(0.0)
	_set_interactions_enabled(false)
	_set_state(PhaseState.FINISHING)
	phase_finishing.emit()

	# Hook for the future loadout persistence system.
	_capture_phase_result()

	if transition_delay <= 0.0:
		_begin_transition()
		return

	transition_timer.start(transition_delay)


func can_interact() -> bool:
	return interactions_enabled and current_state == PhaseState.LOOTING


func get_time_remaining() -> float:
	if current_state != PhaseState.LOOTING:
		return 0.0
	return countdown_timer.time_left


func _initialize_phase() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as PlayerController

	if player == null:
		push_error(
			"PreparationPhaseController could not find a PlayerController. "
			+ "Assign player or add it to the 'player' group."
		)
		return

	if start_with_empty_loadout and player.weapon_component != null:
		player.weapon_component.clear_all_weapons()
		var run_loadout := get_node_or_null(
			"/root/RunLoadout"
		) as RunLoadoutState
		if run_loadout != null:
			run_loadout.clear_loadout()

	player_resolved.emit(player)
	_warning_emitted = false
	_finish_requested = false
	_emit_time_remaining(total_duration)
	_set_interactions_enabled(true)
	_set_state(PhaseState.LOOTING)
	countdown_timer.start(total_duration)
	display_tick_timer.start()

	if warning_duration >= total_duration:
		_start_warning(total_duration)


func _connect_timers() -> void:
	if not countdown_timer.timeout.is_connected(finish_phase):
		countdown_timer.timeout.connect(finish_phase)
	if not display_tick_timer.timeout.is_connected(_on_display_tick):
		display_tick_timer.timeout.connect(_on_display_tick)
	if not transition_timer.timeout.is_connected(_begin_transition):
		transition_timer.timeout.connect(_begin_transition)


func _on_display_tick() -> void:
	var seconds_remaining: float = countdown_timer.time_left
	_emit_time_remaining(seconds_remaining)

	if not _warning_emitted and seconds_remaining <= warning_duration:
		_start_warning(seconds_remaining)


func _start_warning(seconds_remaining: float) -> void:
	if _warning_emitted:
		return

	_warning_emitted = true
	warning_started.emit(maxf(seconds_remaining, 0.0))


func _begin_transition() -> void:
	if current_state != PhaseState.FINISHING:
		return

	transition_timer.stop()
	_set_state(PhaseState.TRANSITIONING)

	if next_boss_scene == null:
		push_error(
			"PreparationPhaseController cannot transition without next_boss_scene."
		)
		_complete_without_scene_change()
		return

	transition_started.emit(next_boss_scene)
	_set_state(PhaseState.COMPLETED)
	phase_completed.emit()
	var change_error: Error = get_tree().change_scene_to_packed(next_boss_scene)
	if change_error != OK:
		push_error(
			"PreparationPhaseController failed to change scene: %s."
			% error_string(change_error)
		)


func _complete_without_scene_change() -> void:
	_set_state(PhaseState.COMPLETED)
	phase_completed.emit()


func _capture_phase_result() -> void:
	if player == null or player.weapon_component == null:
		push_warning("Preparation phase finished without a player loadout to capture.")
		return

	var run_loadout := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_loadout == null:
		push_warning("RunLoadout autoload is unavailable; weapons cannot persist.")
		return
	run_loadout.capture_from(player.weapon_component)


func _emit_time_remaining(seconds_remaining: float) -> void:
	time_remaining_changed.emit(maxf(seconds_remaining, 0.0))


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
	var is_valid: bool = true
	if countdown_timer == null:
		push_error("PreparationPhaseController requires a CountdownTimer.")
		is_valid = false
	if display_tick_timer == null:
		push_error("PreparationPhaseController requires a DisplayTickTimer.")
		is_valid = false
	if transition_timer == null:
		push_error("PreparationPhaseController requires a TransitionTimer.")
		is_valid = false
	return is_valid
