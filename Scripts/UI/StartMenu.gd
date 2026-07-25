extends Control

@export_file("*.tscn") var start_scene_path: String
@export var start_button: Button

func _ready() -> void:
	if start_button != null:
		start_button.grab_focus()

func _on_start_pressed() -> void:
	if not start_scene_path.is_empty():
		get_tree().change_scene_to_file(start_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
