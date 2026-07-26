class_name WesternKeyPanel
extends PanelContainer

@export var face_color: Color = Color(0.84, 0.64, 0.28)
@export var edge_color: Color = Color(0.48, 0.22, 0.13)
@export var shadow_color: Color = Color(0.16, 0.075, 0.04, 0.98)
@export_range(0.0, 40.0, 1.0) var horizontal_content_padding: float = 4.0
@export_range(0.0, 40.0, 1.0) var top_content_padding: float = 8.0


func _ready() -> void:
	var content_inset := StyleBoxEmpty.new()
	content_inset.content_margin_left = horizontal_content_padding
	content_inset.content_margin_top = top_content_padding
	content_inset.content_margin_right = horizontal_content_padding
	content_inset.content_margin_bottom = 0.0
	add_theme_stylebox_override(&"panel", content_inset)
	resized.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	draw_colored_polygon(_panel_polygon(width, height - 8.0, 8.0), shadow_color)
	draw_colored_polygon(_panel_polygon(width, height - 9.0, 0.0), edge_color)
	var face := _panel_polygon(width - 8.0, height - 17.0, 4.0)
	for index: int in range(face.size()):
		face[index].x += 4.0
	draw_colored_polygon(face, face_color)


func _panel_polygon(
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
