class_name ResponsiveLabel
extends Label

@export_range(8, 200, 1, "or_greater") var minimum_font_size: int = 16
@export_range(8, 200, 1, "or_greater") var maximum_font_size: int = 72
@export_range(0.1, 1.0, 0.01) var maximum_viewport_width_ratio: float = 0.88


func _ready() -> void:
	if not get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.connect(_fit_to_viewport)
	call_deferred(&"_fit_to_viewport")


func _exit_tree() -> void:
	if get_viewport().size_changed.is_connected(_fit_to_viewport):
		get_viewport().size_changed.disconnect(_fit_to_viewport)


func _fit_to_viewport() -> void:
	var font: Font = get_theme_font(&"font")
	if font == null:
		return
	var available_width: float = (
		get_viewport_rect().size.x * maximum_viewport_width_ratio
	)
	var selected_size: int = maximum_font_size
	while selected_size > minimum_font_size:
		var text_width: float = font.get_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			selected_size
		).x
		if text_width <= available_width:
			break
		selected_size -= 1
	add_theme_font_size_override(&"font_size", selected_size)
