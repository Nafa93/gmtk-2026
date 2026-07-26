class_name FloatingHealthBar
extends Node2D

@export var health_bar: ProgressBar
@export var follow_offset: Vector2 = Vector2(0.0, -105.0)
@export var bar_color: Color = Color(0.2, 0.9, 0.3, 1.0)
@export_range(1, 20, 1, "or_greater") var section_count: int = 1
@export var section_color: Color = Color(0.02, 0.02, 0.03, 1.0)
@export_range(1.0, 8.0, 0.5, "or_greater") var section_line_width: float = 3.0

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
		_build_section_dividers()
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


func _build_section_dividers() -> void:
	if health_bar == null or section_count <= 1:
		return
	var bar_left: float = health_bar.position.x
	var bar_top: float = health_bar.position.y
	var bar_width: float = health_bar.size.x
	var bar_height: float = health_bar.size.y
	for section: int in range(1, section_count):
		var divider := Line2D.new()
		var divider_x: float = bar_left + bar_width * (
			float(section) / float(section_count)
		)
		divider.points = PackedVector2Array([
			Vector2(divider_x, bar_top + 2.0),
			Vector2(divider_x, bar_top + bar_height - 2.0),
		])
		divider.width = section_line_width
		divider.default_color = section_color
		divider.z_index = 1
		add_child(divider)


func _find_health_component(actor: Node) -> HealthComponent:
	for child: Node in actor.get_children():
		if child is HealthComponent:
			return child as HealthComponent
	return null
