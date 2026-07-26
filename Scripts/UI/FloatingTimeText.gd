class_name FloatingTimeText
extends Label

@export_range(0.1, 5.0, 0.1, "or_greater") var lifetime: float = 0.9
@export_range(0.0, 300.0, 1.0, "or_greater") var rise_speed: float = 55.0

var _elapsed: float = 0.0


func setup(value: String, color: Color) -> void:
	text = value
	modulate = color


func _process(delta: float) -> void:
	_elapsed += delta
	position.y -= rise_speed * delta
	modulate.a = 1.0 - clampf(_elapsed / lifetime, 0.0, 1.0)
	if _elapsed >= lifetime:
		queue_free()
