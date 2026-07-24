class_name PreparationFogOfWar
extends Node

@export var player: Node2D
@export var darkness_color: Color = Color(0.015, 0.02, 0.035, 1.0)
@export_range(100.0, 1200.0, 10.0, "or_greater") var vision_radius: float = 360.0
@export_range(0.1, 4.0, 0.05, "or_greater") var light_energy: float = 1.15

var _canvas_modulate: CanvasModulate
var _vision_light: PointLight2D


func _ready() -> void:
	if player == null:
		player = get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		push_error("PreparationFogOfWar requires a player.")
		return

	_canvas_modulate = CanvasModulate.new()
	_canvas_modulate.name = "FogDarkness"
	_canvas_modulate.color = darkness_color
	add_child(_canvas_modulate)

	_vision_light = PointLight2D.new()
	_vision_light.name = "PlayerVision"
	_vision_light.energy = light_energy
	_vision_light.texture = _create_vision_texture()
	_vision_light.texture_scale = vision_radius / 256.0
	_vision_light.range_z_min = -1024
	_vision_light.range_z_max = 1024
	player.add_child(_vision_light)


func _create_vision_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	gradient.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	gradient.set_offset(0, 0.15)
	gradient.set_offset(1, 1.0)

	var texture := GradientTexture2D.new()
	texture.width = 512
	texture.height = 512
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
