class_name WesternButton
extends Button

@export_range(8, 100, 1, "or_greater") var display_font_size: int = 24
@export_range(-40.0, 40.0, 1.0) var text_vertical_offset: float = 14.0
@export_range(1.0, 1.3, 0.01) var hover_scale: float = 1.07
@export_range(0.01, 1.0, 0.01, "or_greater") var animation_duration: float = 0.12
@export var normal_text_color: Color = Color(0.105, 0.075, 0.045)
@export var hover_text_color: Color = Color(0.105, 0.075, 0.045)

var _display_label: Label
var _display_label_base_position: Vector2 = Vector2.ZERO
var _scale_tween: Tween
var _press_tween: Tween
var _press_amount: float = 0.0


func _ready() -> void:
	_clear_native_button_styles()
	var display_text: String = text
	text = ""
	_display_label = Label.new()
	_display_label.text = display_text
	_display_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_display_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_display_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_display_label.add_theme_font_size_override(&"font_size", display_font_size)
	_display_label.add_theme_color_override(&"font_color", normal_text_color)
	add_child(_display_label)
	_display_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_display_label.offset_top += text_vertical_offset
	_display_label.offset_bottom += text_vertical_offset
	_display_label_base_position = _display_label.position

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	resized.connect(_update_pivot)
	call_deferred(&"_update_pivot")
	queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	var pressed_offset: float = roundf(_press_amount * 6.0)
	var shadow_color := Color(0.16, 0.075, 0.04, 0.98)
	var edge_color := Color(0.48, 0.22, 0.13, 1.0)
	var face_color := Color(0.84, 0.64, 0.28, 1.0)

	var shadow := _button_polygon(width, height - 8.0, 8.0)
	draw_colored_polygon(shadow, shadow_color)
	var edge := _button_polygon(width, height - 9.0, pressed_offset)
	draw_colored_polygon(edge, edge_color)
	var face := _button_polygon(width - 8.0, height - 17.0, pressed_offset + 4.0)
	for index: int in range(face.size()):
		face[index].x += 4.0
	draw_colored_polygon(face, face_color)


func _on_mouse_entered() -> void:
	z_index = 5
	_display_label.add_theme_color_override(&"font_color", hover_text_color)
	_animate_scale(Vector2.ONE * hover_scale)


func _on_mouse_exited() -> void:
	z_index = 0
	_display_label.add_theme_color_override(&"font_color", normal_text_color)
	_animate_scale(Vector2.ONE)


func _on_button_down() -> void:
	_animate_press(1.0)


func _on_button_up() -> void:
	_animate_press(0.0)


func _animate_scale(target_scale: Vector2) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_BACK)
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, ^"scale", target_scale, animation_duration)


func _update_pivot() -> void:
	pivot_offset = size * 0.5


func _animate_press(target: float) -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_QUAD)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_method(_set_press_amount, _press_amount, target, 0.07)


func _set_press_amount(value: float) -> void:
	_press_amount = value
	if _display_label != null:
		_display_label.position = _display_label_base_position + Vector2(
			0.0,
			roundf(value * 6.0)
		)
		_display_label.scale = Vector2.ONE.lerp(Vector2(0.97, 0.86), value)
	queue_redraw()


func _clear_native_button_styles() -> void:
	var empty_style := StyleBoxEmpty.new()
	for style_name: StringName in [
		&"normal",
		&"hover",
		&"pressed",
		&"hover_pressed",
		&"disabled",
		&"focus",
	]:
		add_theme_stylebox_override(style_name, empty_style)


func _button_polygon(
	width: float,
	height: float,
	y_offset: float
) -> PackedVector2Array:
	var step: float = 4.0
	return PackedVector2Array([
		Vector2(step * 2.0, y_offset),
		Vector2(width - step * 2.0, y_offset),
		Vector2(width - step * 2.0, y_offset + step),
		Vector2(width - step, y_offset + step),
		Vector2(width - step, y_offset + step * 2.0),
		Vector2(width, y_offset + step * 2.0),
		Vector2(width, y_offset + height - step * 2.0),
		Vector2(width - step, y_offset + height - step * 2.0),
		Vector2(width - step, y_offset + height - step),
		Vector2(width - step * 2.0, y_offset + height - step),
		Vector2(width - step * 2.0, y_offset + height),
		Vector2(step * 2.0, y_offset + height),
		Vector2(step * 2.0, y_offset + height - step),
		Vector2(step, y_offset + height - step),
		Vector2(step, y_offset + height - step * 2.0),
		Vector2(0.0, y_offset + height - step * 2.0),
		Vector2(0.0, y_offset + step * 2.0),
		Vector2(step, y_offset + step * 2.0),
		Vector2(step, y_offset + step),
		Vector2(step * 2.0, y_offset + step),
	])
