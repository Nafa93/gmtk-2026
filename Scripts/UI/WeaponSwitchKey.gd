class_name WeaponSwitchKey
extends PanelContainer

@export var key_label: Label
@export_range(1.0, 10.0, 1.0) var press_depth: float = 6.0
@export_range(0.01, 0.3, 0.01, "or_greater") var press_duration: float = 0.07
@export_range(-20.0, 20.0, 1.0) var text_center_correction: float = 3.0

var _press_amount: float = 0.0
var _press_tween: Tween
var _label_base_position: Vector2 = Vector2.ZERO
var _label_correction_applied: bool = false


func _ready() -> void:
	set_process(true)
	if key_label != null:
		call_deferred(&"_initialize_label_layout")
	queue_redraw()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed(&"CHANGE_WEAPON"):
		_animate_press()
	if _label_correction_applied:
		_apply_label_transform()


func _draw() -> void:
	var width: float = size.x
	var height: float = size.y
	var pressed_offset: float = roundf(_press_amount * press_depth)
	var shadow_color := Color(0.025, 0.018, 0.012, 0.96)
	var edge_color := Color(0.48, 0.22, 0.13, 1.0)
	var face_color := Color(0.84, 0.64, 0.28, 1.0)

	var shadow := PackedVector2Array([
		Vector2(8, 8), Vector2(width - 8, 8),
		Vector2(width - 8, 11), Vector2(width - 4, 11),
		Vector2(width - 4, 15), Vector2(width, 15),
		Vector2(width, height - 8), Vector2(width - 4, height - 8),
		Vector2(width - 4, height - 4), Vector2(width - 8, height - 4),
		Vector2(width - 8, height), Vector2(8, height),
		Vector2(8, height - 4), Vector2(4, height - 4),
		Vector2(4, height - 8), Vector2(0, height - 8),
		Vector2(0, 15), Vector2(4, 15),
		Vector2(4, 11), Vector2(8, 11),
	])
	draw_colored_polygon(shadow, shadow_color)

	var edge := _key_polygon(width, height - 9, pressed_offset)
	draw_colored_polygon(edge, edge_color)
	var face := _key_polygon(width - 8, height - 17, pressed_offset + 4.0)
	for index: int in range(face.size()):
		face[index].x += 4.0
	draw_colored_polygon(face, face_color)


func _key_polygon(width: float, height: float, y_offset: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(8, y_offset), Vector2(width - 8, y_offset),
		Vector2(width - 8, y_offset + 4), Vector2(width - 4, y_offset + 4),
		Vector2(width - 4, y_offset + 8), Vector2(width, y_offset + 8),
		Vector2(width, y_offset + height - 8),
		Vector2(width - 4, y_offset + height - 8),
		Vector2(width - 4, y_offset + height - 4),
		Vector2(width - 8, y_offset + height - 4),
		Vector2(width - 8, y_offset + height), Vector2(8, y_offset + height),
		Vector2(8, y_offset + height - 4),
		Vector2(4, y_offset + height - 4),
		Vector2(4, y_offset + height - 8),
		Vector2(0, y_offset + height - 8),
		Vector2(0, y_offset + 8), Vector2(4, y_offset + 8),
		Vector2(4, y_offset + 4), Vector2(8, y_offset + 4),
	])


func _animate_press() -> void:
	if _press_tween != null and _press_tween.is_valid():
		_press_tween.kill()
	_press_tween = create_tween()
	_press_tween.set_trans(Tween.TRANS_QUAD)
	_press_tween.set_ease(Tween.EASE_OUT)
	_press_tween.tween_method(_set_press_amount, _press_amount, 1.0, press_duration)
	_press_tween.tween_method(_set_press_amount, 1.0, 0.0, press_duration * 1.6)


func _set_press_amount(value: float) -> void:
	_press_amount = value
	_apply_label_transform()
	queue_redraw()


func _initialize_label_layout() -> void:
	if key_label != null:
		_label_base_position = key_label.position
		_label_correction_applied = true
		key_label.pivot_offset = key_label.size * 0.5
		key_label.position = _label_base_position + Vector2(
			0.0,
			text_center_correction + roundf(_press_amount * press_depth)
		)


func _apply_label_transform() -> void:
	if key_label == null or not _label_correction_applied:
		return
	key_label.position = _label_base_position + Vector2(
		0.0,
		text_center_correction + roundf(_press_amount * press_depth)
	)
	key_label.scale = Vector2.ONE.lerp(Vector2(0.9, 0.82), _press_amount)
