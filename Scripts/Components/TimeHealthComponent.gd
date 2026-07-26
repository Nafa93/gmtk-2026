class_name TimeHealthComponent
extends HealthComponent

signal time_changed(current_time: float, maximum_time: float)
signal time_lost(amount: float, source: StringName)
signal time_recovered(amount: float, source: StringName)
signal timer_started
signal timer_paused
signal timer_resumed
signal depleted
signal critical_entered
signal critical_exited
signal time_granted(amount: float, source: StringName)

@export_group("Time Health")
@export_range(1.0, 3600.0, 1.0, "or_greater") var initial_time: float = 60.0
@export_range(1.0, 3600.0, 1.0, "or_greater") var maximum_time: float = 60.0
@export_range(0.0, 10.0, 0.05, "or_greater") var drain_per_second: float = 1.0
@export_range(0.0, 300.0, 0.5, "or_greater") var critical_threshold: float = 30.0
@export var auto_start: bool = true

@export_group("Damage And Recovery")
@export_range(0.0, 5.0, 0.05, "or_greater") var damage_invulnerability: float = 0.35
@export var allow_overheal: bool = false
@export_range(0.0, 600.0, 1.0, "or_greater") var maximum_bonus_time: float = 0.0

@export_group("Debug")
@export var debug_freeze_timer: bool = false
@export var debug_ignore_death: bool = false
@export var debug_log_sources: bool = true

var current_time: float = 0.0
var is_timer_running: bool = false
var is_timer_paused: bool = false

var _is_depleted: bool = false
var _is_critical: bool = false
var _invulnerability_remaining: float = 0.0


func _ready() -> void:
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null and run_state.has_time_state():
		maximum_time = run_state.maximum_time
		current_time = run_state.current_time
	else:
		current_time = initial_time

	maximum_time = maxf(maximum_time, 1.0)
	current_time = clampf(current_time, 0.0, _get_time_cap())
	_sync_compatibility_health()
	_emit_time_state()

	if auto_start:
		start_timer()


func _physics_process(delta: float) -> void:
	_invulnerability_remaining = maxf(
		_invulnerability_remaining - delta,
		0.0
	)
	if not is_timer_running or is_timer_paused:
		return
	if OS.is_debug_build() and debug_freeze_timer:
		return
	if drain_per_second <= 0.0:
		return

	_apply_time_loss(drain_per_second * delta, &"drain")


func take_damage(amount: int) -> void:
	take_time_damage(float(amount), &"attack")


func take_time_damage(amount: float, source: StringName = &"attack") -> float:
	if _is_depleted or amount <= 0.0 or _invulnerability_remaining > 0.0:
		return 0.0

	_invulnerability_remaining = damage_invulnerability
	return _apply_time_loss(amount, source)


func grant_time(amount: float, source: StringName = &"unspecified") -> float:
	if _is_depleted or amount <= 0.0:
		return 0.0

	var previous_time: float = current_time
	current_time = minf(current_time + amount, _get_time_cap())
	var applied_amount: float = current_time - previous_time
	if applied_amount <= 0.0:
		return 0.0

	_sync_compatibility_health()
	time_recovered.emit(applied_amount, source)
	time_granted.emit(applied_amount, source)
	_emit_time_state()
	_record_recovery(applied_amount, source)
	if OS.is_debug_build() and debug_log_sources:
		print("Time granted: +%.2f [%s]" % [applied_amount, source])
	return applied_amount


func start_timer() -> void:
	if _is_depleted:
		return
	var was_running: bool = is_timer_running
	is_timer_running = true
	is_timer_paused = false
	if not was_running:
		timer_started.emit()
	else:
		timer_resumed.emit()


func pause_timer() -> void:
	if not is_timer_running or is_timer_paused:
		return
	is_timer_paused = true
	timer_paused.emit()


func resume_timer() -> void:
	if _is_depleted or not is_timer_running or not is_timer_paused:
		return
	is_timer_paused = false
	timer_resumed.emit()


func stop_timer() -> void:
	is_timer_running = false
	is_timer_paused = false


func set_current_time(value: float) -> void:
	if not OS.is_debug_build():
		return
	current_time = clampf(value, 0.0, _get_time_cap())
	_sync_compatibility_health()
	_emit_time_state()
	if current_time <= 0.0:
		_deplete(&"debug")


func get_health_ratio() -> float:
	if maximum_time <= 0.0:
		return 0.0
	return current_time / maximum_time


func is_dead() -> bool:
	return _is_depleted


func _apply_time_loss(
	amount: float,
	source: StringName
) -> float:
	if _is_depleted or amount <= 0.0:
		return 0.0

	var previous_time: float = current_time
	current_time = maxf(current_time - amount, 0.0)
	var applied_amount: float = previous_time - current_time
	if applied_amount <= 0.0:
		return 0.0

	_sync_compatibility_health()
	time_lost.emit(applied_amount, source)
	damaged.emit(ceili(applied_amount))
	_emit_time_state()
	_record_loss(applied_amount, source)

	if current_time <= 0.0:
		_deplete(source)
	return applied_amount


func _deplete(source: StringName) -> void:
	if _is_depleted:
		return
	if OS.is_debug_build() and debug_ignore_death:
		current_time = 0.01
		_sync_compatibility_health()
		_emit_time_state()
		return

	_is_depleted = true
	current_time = 0.0
	stop_timer()
	_sync_compatibility_health()
	_emit_time_state()
	depleted.emit()
	died.emit()

	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null:
		run_state.death_cause = source


func _emit_time_state() -> void:
	time_changed.emit(current_time, maximum_time)
	health_changed.emit(current_health, max_health)

	var should_be_critical: bool = (
		current_time > 0.0 and current_time <= critical_threshold
	)
	if should_be_critical == _is_critical:
		return
	_is_critical = should_be_critical
	if _is_critical:
		critical_entered.emit()
	else:
		critical_exited.emit()


func _sync_compatibility_health() -> void:
	max_health = ceili(maximum_time)
	current_health = ceili(current_time)


func _get_time_cap() -> float:
	return (
		maximum_time + maximum_bonus_time
		if allow_overheal
		else maximum_time
	)


func _record_loss(amount: float, source: StringName) -> void:
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null:
		run_state.record_time_lost(amount, source)


func _record_recovery(amount: float, source: StringName) -> void:
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null:
		run_state.record_time_recovered(amount, source)
