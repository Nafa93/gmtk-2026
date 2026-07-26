class_name WallTorch
extends Node2D

@export var torch_sprite: Sprite2D
@export var torch_light: PointLight2D
@export_range(1.0, 30.0, 0.5, "or_greater") var animation_fps: float = 9.0
@export_range(0.0, 1.0, 0.01) var flicker_amount: float = 0.12

var _elapsed: float = 0.0
var _base_energy: float = 1.0
var _base_texture_scale: float = 1.0


func _ready() -> void:
	if torch_light != null:
		_base_energy = torch_light.energy
		_base_texture_scale = torch_light.texture_scale
		torch_light.texture = _create_light_texture()


func _process(delta: float) -> void:
	_elapsed += delta
	if torch_sprite != null:
		torch_sprite.frame = int(_elapsed * animation_fps) % 3
	if torch_light != null:
		var flicker: float = sin(_elapsed * 17.0) * 0.65
		flicker += sin(_elapsed * 31.0) * 0.35
		var brightness_multiplier: float = 1.0
		var time_lighting := get_node_or_null(
			"/root/TimeLighting"
		) as TimeLightingController
		if time_lighting != null:
			brightness_multiplier = time_lighting.get_brightness_multiplier()
			torch_light.texture_scale = (
				_base_texture_scale * time_lighting.get_size_multiplier()
			)
		torch_light.energy = (
			_base_energy
			* (1.0 + flicker * flicker_amount)
			* brightness_multiplier
		)


func _create_light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1.0, 0.72, 0.35, 1.0))
	gradient.set_color(1, Color(1.0, 0.35, 0.08, 0.0))
	gradient.set_offset(0, 0.0)
	gradient.set_offset(1, 1.0)

	var texture := GradientTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.gradient = gradient
	return texture
