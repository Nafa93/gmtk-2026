extends Node

@export var player: PlayerController
@export var boss: BossController
@export_file("*.tscn") var defeat_scene_path: String
@export_file("*.tscn") var victory_scene_path: String

var _result_requested: bool = false

func _ready() -> void:
	if player == null or player.health_component == null or boss == null:
		push_error("BossEncounterController requires player and boss references.")
		return
	player.health_component.died.connect(_on_player_died)
	boss.boss_died.connect(_on_boss_died)

func _on_player_died() -> void:
	_request_result(defeat_scene_path)

func _on_boss_died() -> void:
	_request_result(victory_scene_path)

func _request_result(result_scene_path: String) -> void:
	if _result_requested:
		return
	_result_requested = true
	if not result_scene_path.is_empty():
		get_tree().call_deferred(&"change_scene_to_file", result_scene_path)
