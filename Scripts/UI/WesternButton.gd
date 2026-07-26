class_name WesternButton
extends Button

@export_range(8, 100, 1, "or_greater") var display_font_size: int = 24
@export_range(-40.0, 40.0, 1.0) var text_vertical_offset: float = 14.0
@export_range(1.0, 1.3, 0.01) var hover_scale: float = 1.07
@export_range(0.01, 1.0, 0.01, "or_greater") var animation_duration: float = 0.12
@export var normal_text_color: Color = Color(0.94, 0.84, 0.63)
@export var hover_text_color: Color = Color(0.105, 0.075, 0.045)

var _display_label: Label
var _scale_tween: Tween


func _ready() -> void:
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

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_update_pivot)
	call_deferred(&"_update_pivot")


func _on_mouse_entered() -> void:
	z_index = 5
	_display_label.add_theme_color_override(&"font_color", hover_text_color)
	_animate_scale(Vector2.ONE * hover_scale)


func _on_mouse_exited() -> void:
	z_index = 0
	_display_label.add_theme_color_override(&"font_color", normal_text_color)
	_animate_scale(Vector2.ONE)


func _animate_scale(target_scale: Vector2) -> void:
	if _scale_tween != null and _scale_tween.is_valid():
		_scale_tween.kill()
	_scale_tween = create_tween()
	_scale_tween.set_trans(Tween.TRANS_BACK)
	_scale_tween.set_ease(Tween.EASE_OUT)
	_scale_tween.tween_property(self, ^"scale", target_scale, animation_duration)


func _update_pivot() -> void:
	pivot_offset = size * 0.5
