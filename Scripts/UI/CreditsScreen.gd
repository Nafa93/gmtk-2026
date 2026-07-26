extends Control

@export_file("*.tscn") var menu_scene_path: String = "res://Scenes/UI/StartMenu.tscn"
@export var back_button: Button


func _ready() -> void:
	if back_button != null:
		back_button.grab_focus()


func _on_back_pressed() -> void:
	var transition := get_node_or_null(
		"/root/SceneTransition"
	) as SceneTransitionController
	if transition != null:
		transition.transition_to_file(menu_scene_path)
	else:
		get_tree().change_scene_to_file(menu_scene_path)
