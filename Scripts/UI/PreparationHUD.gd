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
@export var pause_button: Button
@export var pause_overlay: Control
@export var resume_button: Button
@export var main_menu_button: Button
@export var music_volume_slider: HSlider
@export var sfx_volume_slider: HSlider
@export_file("*.tscn") var main_menu_scene_path: String = "res://Scenes/UI/StartMenu.tscn"
@export var show_time_feedback: bool = true
@export var normal_timer_color: Color = Color(0.94, 0.84, 0.63)
@export var warning_timer_color: Color = Color(0.78, 0.16, 0.09)
@export_range(0.0, 0.2, 0.005) var pulse_intensity: float = 0.025
@export_range(0.1, 10.0, 0.1, "or_greater") var pulse_frequency: float = 1.4

var _weapon_component: WeaponComponent
var _time_health: TimeHealthComponent
var _time_urgency_level: int = 0
var _feedback_generation: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if warning_label != null:
		warning_label.visible = false
	if feedback_label != null:
		feedback_label.visible = false
	if boss_hold_progress != null:
		boss_hold_progress.value = 0.0
	if pause_overlay != null:
		pause_overlay.visible = false
	if pause_button != null and not pause_button.pressed.is_connected(_pause_game):
		pause_button.pressed.connect(_pause_game)
	if resume_button != null and not resume_button.pressed.is_connected(_resume_game):
		resume_button.pressed.connect(_resume_game)
	if (
		main_menu_button != null
		and not main_menu_button.pressed.is_connected(_return_to_main_menu)
	):
		main_menu_button.pressed.connect(_return_to_main_menu)
	_initialize_volume_slider(music_volume_slider, &"Music")
	_initialize_volume_slider(sfx_volume_slider, &"SFX")


func _unhandled_input(event: InputEvent) -> void:
	if (
		event is InputEventKey
		and event.pressed
		and not event.echo
		and event.keycode == KEY_ESCAPE
	):
		get_viewport().set_input_as_handled()
		if get_tree().paused:
			_resume_game()
		else:
			_pause_game()


func _pause_game() -> void:
	if get_tree().paused:
		return
	get_tree().paused = true
	if pause_overlay != null:
		pause_overlay.visible = true
	if resume_button != null:
		resume_button.grab_focus()


func _resume_game() -> void:
	if pause_overlay != null:
		pause_overlay.visible = false
	get_tree().paused = false
	if pause_button != null:
		pause_button.grab_focus()


func _return_to_main_menu() -> void:
	get_tree().paused = false
	if not main_menu_scene_path.is_empty():
		get_tree().change_scene_to_file(main_menu_scene_path)


func _initialize_volume_slider(slider: HSlider, bus_name: StringName) -> void:
	if slider == null:
		return
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		push_warning("Audio bus '%s' is unavailable." % bus_name)
		return
	slider.value = db_to_linear(
		AudioServer.get_bus_volume_db(bus_index)
	) * 100.0
	slider.value_changed.connect(
		func(new_value: float) -> void:
			_set_bus_volume(bus_name, new_value)
	)


func _set_bus_volume(bus_name: StringName, percent: float) -> void:
	var bus_index: int = AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	var normalized: float = clampf(percent / 100.0, 0.0, 1.0)
	AudioServer.set_bus_mute(bus_index, normalized <= 0.001)
	AudioServer.set_bus_volume_db(
		bus_index,
		linear_to_db(maxf(normalized, 0.001))
	)


func _process(_delta: float) -> void:
	if timer_label == null or _time_urgency_level <= 0:
		return
	var urgency: float = float(_time_urgency_level)
	var wave: float = (sin(
		Time.get_ticks_msec() / 1000.0
		* TAU
		* (pulse_frequency + urgency * 0.25)
	) + 1.0) * 0.5
	var band_intensity: float = pulse_intensity * urgency
	timer_label.scale = Vector2.ONE * (1.0 + band_intensity * wave)


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
	_update_timer_urgency(current_time)


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
	if warning_label != null:
		warning_label.text = "CRITICAL TIME"
		warning_label.visible = true
	if warning_audio != null and warning_audio.stream != null:
		warning_audio.play()


func _on_warning_ended() -> void:
	if _time_health != null:
		_update_timer_urgency(_time_health.current_time)
	if warning_label != null:
		warning_label.visible = false
	if warning_audio != null:
		warning_audio.stop()


func _update_timer_urgency(current_time: float) -> void:
	if current_time <= 15.0:
		_time_urgency_level = 3
	elif current_time <= 30.0:
		_time_urgency_level = 2
	elif current_time <= 45.0:
		_time_urgency_level = 1
	else:
		_time_urgency_level = 0

	if timer_label == null:
		return
	var color_progress: float = float(_time_urgency_level) / 3.0
	timer_label.modulate = normal_timer_color.lerp(
		warning_timer_color,
		color_progress
	)
	if _time_urgency_level == 0:
		timer_label.scale = Vector2.ONE


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
	_update_weapon_icon(primary_weapon_icon, primary_weapon)
	_update_weapon_icon(secondary_weapon_icon, secondary_weapon)


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


func _update_weapon_icon(icon: TextureRect, weapon: Weapon) -> void:
	if icon == null:
		return
	icon.texture = _get_weapon_texture(weapon)
	icon.pivot_offset = icon.size * 0.5
	var icon_scale: float = 1.0
	var weapon_name: String = _get_weapon_name(weapon).to_lower()
	if weapon_name == "rifle":
		icon_scale = 1.65
	elif weapon_name == "shotgun":
		icon_scale = 1.5
	icon.scale = Vector2.ONE * icon_scale


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
