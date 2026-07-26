class_name PreparationHUD
extends CanvasLayer

@export var timer_label: Label
@export var feedback_label: Label
@export var primary_weapon_label: Label
@export var secondary_weapon_label: Label
@export var primary_weapon_icon: TextureRect
@export var secondary_weapon_icon: TextureRect
@export var warning_label: Label
@export var boss_prompt_label: Label
@export var boss_hold_progress: ProgressBar
@export var warning_audio: AudioStreamPlayer
@export var show_time_feedback: bool = true
@export var normal_timer_color: Color = Color(0.94, 0.84, 0.63)
@export var warning_timer_color: Color = Color(0.66, 0.29, 0.18)
@export_range(0.0, 1.0, 0.05) var pulse_intensity: float = 0.25
@export_range(0.1, 10.0, 0.1, "or_greater") var pulse_frequency: float = 3.0

var _weapon_component: WeaponComponent
var _time_health: TimeHealthComponent
var _critical: bool = false
var _feedback_generation: int = 0


func _ready() -> void:
	if warning_label != null:
		warning_label.visible = false
	if feedback_label != null:
		feedback_label.visible = false
	if boss_hold_progress != null:
		boss_hold_progress.value = 0.0


func _process(_delta: float) -> void:
	if timer_label == null or not _critical:
		return
	var wave: float = (sin(
		Time.get_ticks_msec() / 1000.0 * TAU * pulse_frequency
	) + 1.0) * 0.5
	timer_label.scale = Vector2.ONE * (1.0 + pulse_intensity * wave)


func bind_to_controller(controller: PreparationPhaseController) -> void:
	if controller == null:
		return
	_connect_once(controller.player_resolved, _on_player_resolved)
	_connect_once(controller.warning_started, _on_warning_started)
	_connect_once(controller.warning_ended, _on_warning_ended)
	_connect_once(
		controller.boss_hold_progress_changed,
		_on_boss_hold_progress_changed
	)
	_connect_once(controller.boss_start_blocked, _on_boss_start_blocked)
	_connect_once(
		controller.boss_interaction_availability_changed,
		_on_boss_interaction_availability_changed
	)
	_connect_once(controller.phase_finishing, _on_phase_finishing)
	if boss_prompt_label != null:
		boss_prompt_label.visible = false
	if boss_hold_progress != null:
		boss_hold_progress.visible = false


func bind_player(player: PlayerController, show_boss_prompt: bool = false) -> void:
	if player == null:
		return
	_on_player_resolved(player)
	if boss_prompt_label != null:
		boss_prompt_label.visible = show_boss_prompt
	if boss_hold_progress != null:
		boss_hold_progress.visible = show_boss_prompt


func _on_player_resolved(player: PlayerController) -> void:
	_weapon_component = player.weapon_component
	_time_health = player.health_component as TimeHealthComponent
	if _weapon_component != null:
		_connect_once(_weapon_component.weapon_equipped, _on_weapon_equipped)
		_connect_once(_weapon_component.weapon_switched, _on_weapon_switched)
		_connect_once(_weapon_component.loadout_changed, _on_loadout_changed)
	if _time_health != null:
		_connect_once(_time_health.time_changed, _on_time_changed)
		_connect_once(_time_health.time_lost, _on_time_lost)
		_connect_once(_time_health.time_recovered, _on_time_recovered)
		_connect_once(_time_health.critical_entered, _on_time_critical)
		_connect_once(_time_health.critical_exited, _on_warning_ended)
		_on_time_changed(_time_health.current_time, _time_health.maximum_time)
	_refresh_weapon_labels()


func _on_time_changed(current_time: float, _maximum_time: float) -> void:
	if timer_label == null:
		return
	timer_label.text = "TIME  %s" % _format_time(current_time)


func _on_time_lost(amount: float, source: StringName) -> void:
	if not show_time_feedback or source == &"drain":
		return
	_show_feedback("-%.1fs" % amount, warning_timer_color)


func _on_time_recovered(amount: float, _source: StringName) -> void:
	if not show_time_feedback:
		return
	_show_feedback("+%.1fs" % amount, Color(0.84, 0.64, 0.28))


func _on_time_critical() -> void:
	_on_warning_started(_time_health.current_time if _time_health != null else 0.0)


func _on_warning_started(_seconds_remaining: float) -> void:
	_critical = true
	if timer_label != null:
		timer_label.modulate = warning_timer_color
	if warning_label != null:
		warning_label.text = "CRITICAL TIME"
		warning_label.visible = true
	if warning_audio != null and warning_audio.stream != null:
		warning_audio.play()


func _on_warning_ended() -> void:
	_critical = false
	if timer_label != null:
		timer_label.modulate = normal_timer_color
		timer_label.scale = Vector2.ONE
	if warning_label != null:
		warning_label.visible = false
	if warning_audio != null:
		warning_audio.stop()


func _on_boss_hold_progress_changed(progress: float) -> void:
	if boss_hold_progress != null:
		boss_hold_progress.value = progress * 100.0


func _on_boss_interaction_availability_changed(available: bool) -> void:
	if boss_prompt_label != null:
		boss_prompt_label.text = "Hold [E] to face the boss"
		boss_prompt_label.visible = available
	if boss_hold_progress != null:
		boss_hold_progress.visible = available
		if not available:
			boss_hold_progress.value = 0.0


func _on_boss_start_blocked(minimum_time: float) -> void:
	_show_feedback(
		"Need at least %.0fs to enter the boss" % minimum_time,
		warning_timer_color
	)


func _on_phase_finishing() -> void:
	if boss_prompt_label != null:
		boss_prompt_label.text = "Entering boss..."
	if boss_hold_progress != null:
		boss_hold_progress.value = 100.0


func _on_weapon_equipped(_slot: int, _weapon: Weapon) -> void:
	_refresh_weapon_labels()


func _on_weapon_switched(_active: Weapon, _secondary: Weapon) -> void:
	_refresh_weapon_labels()


func _on_loadout_changed(_active: Weapon, _secondary: Weapon) -> void:
	_refresh_weapon_labels()


func _refresh_weapon_labels() -> void:
	var primary_weapon: Weapon = (
		_weapon_component.get_active_weapon() if _weapon_component != null else null
	)
	var secondary_weapon: Weapon = (
		_weapon_component.get_secondary_weapon()
		if _weapon_component != null
		else null
	)
	if primary_weapon_label != null:
		primary_weapon_label.text = _get_weapon_name(primary_weapon)
	if secondary_weapon_label != null:
		secondary_weapon_label.text = _get_weapon_name(secondary_weapon)
	if primary_weapon_icon != null:
		primary_weapon_icon.texture = _get_weapon_texture(primary_weapon)
	if secondary_weapon_icon != null:
		secondary_weapon_icon.texture = _get_weapon_texture(secondary_weapon)


func _get_weapon_name(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return "EMPTY"
	if weapon.data == null or weapon.data.weapon_name.is_empty():
		return weapon.name
	return weapon.data.weapon_name


func _get_weapon_texture(weapon: Weapon) -> Texture2D:
	if (
		weapon == null
		or not is_instance_valid(weapon)
		or weapon.weapon_sprite == null
	):
		return null
	return weapon.weapon_sprite.texture


func _format_time(value: float) -> String:
	var total_seconds: int = ceili(maxf(value, 0.0))
	return "%02d:%02d" % [total_seconds / 60, total_seconds % 60]


func _show_feedback(text_value: String, color: Color) -> void:
	if feedback_label == null:
		return
	_feedback_generation += 1
	var generation: int = _feedback_generation
	feedback_label.text = text_value
	feedback_label.modulate = color
	feedback_label.visible = true
	await get_tree().create_timer(0.8).timeout
	if generation == _feedback_generation and is_instance_valid(feedback_label):
		feedback_label.visible = false


func _connect_once(signal_value: Signal, callable: Callable) -> void:
	if not signal_value.is_connected(callable):
		signal_value.connect(callable)
