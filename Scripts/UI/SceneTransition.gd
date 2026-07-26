class_name SceneTransitionController
extends CanvasLayer

@export var overlay: ColorRect
@export_range(0.05, 2.0, 0.05, "or_greater") var close_duration: float = 0.45
@export_range(0.05, 2.0, 0.05, "or_greater") var open_duration: float = 0.5

var _busy: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if overlay != null:
		overlay.visible = false


func transition_to_packed(
	next_scene: PackedScene,
	screen_center: Vector2 = Vector2(0.5, 0.5)
) -> void:
	if _busy or next_scene == null or overlay == null:
		return
	_busy = true
	overlay.visible = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_set_shader_parameter(&"center", screen_center)
	_set_shader_parameter(&"aspect_ratio", _get_aspect_ratio())
	_set_radius(1.5)

	var close_tween: Tween = create_tween()
	close_tween.set_trans(Tween.TRANS_QUAD)
	close_tween.set_ease(Tween.EASE_IN)
	close_tween.tween_method(_set_radius, 1.5, 0.0, close_duration)
	await close_tween.finished

	var error: Error = get_tree().change_scene_to_packed(next_scene)
	if error != OK:
		push_error("Scene transition failed: %s." % error_string(error))
		_finish_transition()
		return

	await get_tree().process_frame
	_set_shader_parameter(&"center", Vector2(0.5, 0.5))
	_set_shader_parameter(&"aspect_ratio", _get_aspect_ratio())
	var open_tween: Tween = create_tween()
	open_tween.set_trans(Tween.TRANS_QUAD)
	open_tween.set_ease(Tween.EASE_OUT)
	open_tween.tween_method(_set_radius, 0.0, 1.5, open_duration)
	await open_tween.finished
	_finish_transition()


func transition_to_file(
	scene_path: String,
	screen_center: Vector2 = Vector2(0.5, 0.5)
) -> void:
	if scene_path.is_empty():
		return
	var next_scene: PackedScene = load(scene_path) as PackedScene
	if next_scene == null:
		push_error("Could not load transition scene: %s." % scene_path)
		return
	transition_to_packed(next_scene, screen_center)


func _set_radius(value: float) -> void:
	_set_shader_parameter(&"radius", value)


func _set_shader_parameter(parameter: StringName, value: Variant) -> void:
	var shader_material := overlay.material as ShaderMaterial
	if shader_material != null:
		shader_material.set_shader_parameter(parameter, value)


func _get_aspect_ratio() -> float:
	var viewport_size: Vector2 = get_viewport().get_visible_rect().size
	return viewport_size.x / maxf(viewport_size.y, 1.0)


func _finish_transition() -> void:
	overlay.visible = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_busy = false
