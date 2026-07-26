class_name WesternPointingSign
extends PanelContainer

@export var face_color: Color = Color(0.48, 0.225, 0.085, 1.0)
@export var edge_color: Color = Color(0.22, 0.08, 0.035, 1.0)
@export var shadow_color: Color = Color(0.075, 0.035, 0.055, 1.0)


func _ready() -> void:
	var empty_style := StyleBoxEmpty.new()
	empty_style.content_margin_left = 12.0
	empty_style.content_margin_top = 11.0
	empty_style.content_margin_right = 28.0
	empty_style.content_margin_bottom = 2.0
	add_theme_stylebox_override(&"panel", empty_style)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	draw_colored_polygon(_arrow_polygon(width, height - 8.0, 8.0), shadow_color)
	draw_colored_polygon(_arrow_polygon(width, height - 8.0, 0.0), edge_color)

	var face := _arrow_polygon(width - 10.0, height - 18.0, 5.0)
	for index: int in range(face.size()):
		face[index].x += 4.0
	draw_colored_polygon(face, face_color)

	# Two restrained pixel-grain marks keep the sign visibly wooden.
	draw_rect(Rect2(Vector2(18.0, 15.0), Vector2(38.0, 4.0)), Color(0.68, 0.36, 0.13, 0.35))
	draw_rect(Rect2(Vector2(78.0, height - 21.0), Vector2(31.0, 4.0)), Color(0.28, 0.11, 0.045, 0.48))


func _arrow_polygon(
	width: float,
	height: float,
	y_offset: float
) -> PackedVector2Array:
	var point_width: float = 30.0
	var body_end: float = width - point_width
	var middle_y: float = y_offset + height * 0.5
	return PackedVector2Array([
		Vector2(8.0, y_offset),
		Vector2(body_end, y_offset),
		Vector2(body_end, y_offset + 6.0),
		Vector2(body_end + 10.0, y_offset + 6.0),
		Vector2(body_end + 10.0, y_offset + 12.0),
		Vector2(width - 10.0, middle_y - 6.0),
		Vector2(width - 10.0, middle_y - 3.0),
		Vector2(width, middle_y),
		Vector2(width - 10.0, middle_y + 3.0),
		Vector2(width - 10.0, middle_y + 6.0),
		Vector2(body_end + 10.0, y_offset + height - 12.0),
		Vector2(body_end + 10.0, y_offset + height - 6.0),
		Vector2(body_end, y_offset + height - 6.0),
		Vector2(body_end, y_offset + height),
		Vector2(8.0, y_offset + height),
		Vector2(8.0, y_offset + height - 4.0),
		Vector2(0.0, y_offset + height - 4.0),
		Vector2(0.0, y_offset + 4.0),
		Vector2(8.0, y_offset + 4.0),
	])
