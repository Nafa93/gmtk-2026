class_name PreparationHUD
extends CanvasLayer

@export var timer_label: Label
@export var primary_weapon_label: Label
@export var secondary_weapon_label: Label
@export var warning_label: Label
@export var normal_timer_color: Color = Color.WHITE
@export var warning_timer_color: Color = Color(1.0, 0.25, 0.15)

var _weapon_component: WeaponComponent


func _ready() -> void:
	if warning_label != null:
		warning_label.visible = false


func bind_to_controller(controller: PreparationPhaseController) -> void:
	if controller == null:
		push_error("PreparationHUD cannot bind to a null controller.")
		return

	if not controller.time_remaining_changed.is_connected(
		_on_time_remaining_changed
	):
		controller.time_remaining_changed.connect(_on_time_remaining_changed)
	if not controller.warning_started.is_connected(_on_warning_started):
		controller.warning_started.connect(_on_warning_started)
	if not controller.player_resolved.is_connected(_on_player_resolved):
		controller.player_resolved.connect(_on_player_resolved)
	if not controller.phase_finishing.is_connected(_on_phase_finishing):
		controller.phase_finishing.connect(_on_phase_finishing)


func _on_player_resolved(player: PlayerController) -> void:
	if player == null:
		return

	_weapon_component = player.weapon_component
	if _weapon_component == null:
		push_warning("PreparationHUD found a player without WeaponComponent.")
		_refresh_weapon_labels()
		return

	if not _weapon_component.weapon_equipped.is_connected(_on_weapon_equipped):
		_weapon_component.weapon_equipped.connect(_on_weapon_equipped)
	if not _weapon_component.weapon_switched.is_connected(_on_weapon_switched):
		_weapon_component.weapon_switched.connect(_on_weapon_switched)
	_refresh_weapon_labels()


func _on_time_remaining_changed(seconds_remaining: float) -> void:
	if timer_label == null:
		return

	var whole_seconds: int = ceili(seconds_remaining)
	var minutes: int = whole_seconds / 60
	var seconds: int = whole_seconds % 60
	timer_label.text = "%02d:%02d" % [minutes, seconds]


func _on_warning_started(_seconds_remaining: float) -> void:
	if timer_label != null:
		timer_label.modulate = warning_timer_color
	if warning_label != null:
		warning_label.visible = true


func _on_phase_finishing() -> void:
	if warning_label != null:
		warning_label.text = "¡TIEMPO!"
		warning_label.visible = true


func _on_weapon_equipped(_slot: int, _weapon: Weapon) -> void:
	_refresh_weapon_labels()


func _on_weapon_switched(
	_active_weapon: Weapon,
	_secondary_weapon: Weapon
) -> void:
	_refresh_weapon_labels()


func _refresh_weapon_labels() -> void:
	if primary_weapon_label != null:
		primary_weapon_label.text = "Activa: %s" % _get_weapon_name(
			_weapon_component.get_active_weapon() if _weapon_component != null else null
		)
	if secondary_weapon_label != null:
		secondary_weapon_label.text = "Secundaria: %s" % _get_weapon_name(
			_weapon_component.get_secondary_weapon()
			if _weapon_component != null else null
		)


func _get_weapon_name(weapon: Weapon) -> String:
	if weapon == null or not is_instance_valid(weapon):
		return "Vacía"
	if weapon.data == null or weapon.data.weapon_name.is_empty():
		return weapon.name
	return weapon.data.weapon_name
