extends Control

@export_file("*.tscn") var menu_scene_path: String
@export var retry_button: Button

func _ready() -> void:
	if retry_button != null:
		retry_button.grab_focus()

func _on_retry_pressed() -> void:
	var run_loadout := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_loadout != null:
		run_loadout.reset_run()
	if not menu_scene_path.is_empty():
		get_tree().change_scene_to_file(menu_scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
