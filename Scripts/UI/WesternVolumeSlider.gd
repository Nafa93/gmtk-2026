class_name WesternVolumeSlider
extends HSlider

const SHADOW_COLOR := Color(0.16, 0.075, 0.04, 1.0)
const EDGE_COLOR := Color(0.48, 0.22, 0.13, 1.0)
const FACE_COLOR := Color(0.84, 0.64, 0.28, 1.0)
const EMPTY_COLOR := Color(0.105, 0.075, 0.045, 1.0)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	min_value = 0.0
	max_value = 100.0
	step = 1.0
	var empty_style := StyleBoxEmpty.new()
	add_theme_stylebox_override(&"slider", empty_style)
	add_theme_stylebox_override(&"grabber_area", empty_style)
	add_theme_stylebox_override(&"grabber_area_highlight", empty_style)
	var transparent_icon := GradientTexture1D.new()
	var transparent_gradient := Gradient.new()
	transparent_gradient.colors = PackedColorArray([
		Color.TRANSPARENT,
		Color.TRANSPARENT,
	])
	transparent_icon.gradient = transparent_gradient
	add_theme_icon_override(&"grabber", transparent_icon)
	add_theme_icon_override(&"grabber_highlight", transparent_icon)
	add_theme_icon_override(&"grabber_disabled", transparent_icon)
	value_changed.connect(func(_new_value: float) -> void: queue_redraw())
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var center_y: float = size.y * 0.5
	var track_left: float = 14.0
	var track_width: float = maxf(size.x - 28.0, 1.0)
	var ratio: float = inverse_lerp(min_value, max_value, value)
	draw_rect(Rect2(Vector2(track_left, center_y - 7.0), Vector2(track_width, 18.0)), SHADOW_COLOR)
	draw_rect(Rect2(Vector2(track_left, center_y - 9.0), Vector2(track_width, 14.0)), EDGE_COLOR)
	draw_rect(Rect2(Vector2(track_left + 4.0, center_y - 5.0), Vector2(track_width - 8.0, 6.0)), EMPTY_COLOR)
	draw_rect(Rect2(Vector2(track_left + 4.0, center_y - 5.0), Vector2((track_width - 8.0) * ratio, 6.0)), FACE_COLOR)

	var handle_x: float = lerpf(track_left + 4.0, track_left + track_width - 4.0, ratio)
	var handle := PackedVector2Array([
		Vector2(handle_x - 10.0, center_y - 17.0),
		Vector2(handle_x + 10.0, center_y - 17.0),
		Vector2(handle_x + 10.0, center_y - 13.0),
		Vector2(handle_x + 14.0, center_y - 13.0),
		Vector2(handle_x + 14.0, center_y + 11.0),
		Vector2(handle_x + 10.0, center_y + 11.0),
		Vector2(handle_x + 10.0, center_y + 15.0),
		Vector2(handle_x - 10.0, center_y + 15.0),
		Vector2(handle_x - 10.0, center_y + 11.0),
		Vector2(handle_x - 14.0, center_y + 11.0),
		Vector2(handle_x - 14.0, center_y - 13.0),
		Vector2(handle_x - 10.0, center_y - 13.0),
	])
	draw_colored_polygon(handle, EDGE_COLOR)
	var face := handle.duplicate()
	for index: int in range(face.size()):
		face[index] = face[index].lerp(Vector2(handle_x, center_y), 0.24)
	draw_colored_polygon(
		face,
		FACE_COLOR.lightened(0.08) if has_focus() else FACE_COLOR
	)
