class_name FloatingHealthBar
extends Node2D

@export var health_bar: ProgressBar
@export var follow_offset: Vector2 = Vector2(0.0, -105.0)
@export var bar_color: Color = Color(0.2, 0.9, 0.3, 1.0)

var _actor: Node2D
var _health_component: HealthComponent


func _ready() -> void:
	_actor = get_parent() as Node2D
	if _actor == null:
		push_error("FloatingHealthBar must be a child of a Node2D actor.")
		return

	_health_component = _find_health_component(_actor)
	if _health_component == null:
		push_error("FloatingHealthBar could not find a HealthComponent.")
		return

	top_level = true
	if health_bar != null:
		var fill_style := health_bar.get_theme_stylebox(&"fill") as StyleBoxFlat
		if fill_style != null:
			var colored_fill := fill_style.duplicate() as StyleBoxFlat
			colored_fill.bg_color = bar_color
			health_bar.add_theme_stylebox_override(&"fill", colored_fill)
	if not _health_component.health_changed.is_connected(_on_health_changed):
		_health_component.health_changed.connect(_on_health_changed)
	_on_health_changed(_health_component.current_health, _health_component.max_health)
	_update_position()


func _process(_delta: float) -> void:
	_update_position()


func _on_health_changed(current_health: int, max_health: int) -> void:
	if health_bar == null:
		return
	health_bar.max_value = max_health
	health_bar.value = current_health


func _update_position() -> void:
	if _actor != null and is_instance_valid(_actor):
		global_position = _actor.global_position + follow_offset
		global_rotation = 0.0


func _find_health_component(actor: Node) -> HealthComponent:
	for child: Node in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
