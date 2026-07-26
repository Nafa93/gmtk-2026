extends Node

@export var player: PlayerController
@export var boss: BossController
@export var time_hud: PreparationHUD
@export_file("*.tscn") var defeat_scene_path: String
@export_file("*.tscn") var victory_scene_path: String

var _result_requested: bool = false

func _ready() -> void:
	if player == null or player.health_component == null or boss == null:
		push_error("BossEncounterController requires player and boss references.")
		return
	if not player.health_component.died.is_connected(_on_player_died):
		player.health_component.died.connect(_on_player_died)
	if not boss.boss_died.is_connected(_on_boss_died):
		boss.boss_died.connect(_on_boss_died)

	var time_health := player.health_component as TimeHealthComponent
	if time_health != null:
		time_health.start_timer()
		time_health.resume_timer()
		var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
		if run_state != null:
			run_state.mark_boss_started(time_health)
	if time_hud != null:
		time_hud.bind_player(player, false)

func _on_player_died() -> void:
	_request_result(defeat_scene_path)

func _on_boss_died() -> void:
	var time_health := player.health_component as TimeHealthComponent
	if time_health != null:
		time_health.pause_timer()
	_request_result(victory_scene_path)


func pause_player_time() -> void:
	var time_health := player.health_component as TimeHealthComponent
	if time_health != null:
		time_health.pause_timer()


func resume_player_time() -> void:
	var time_health := player.health_component as TimeHealthComponent
	if time_health != null:
		time_health.resume_timer()

func _request_result(result_scene_path: String) -> void:
	if _result_requested:
		return
	_result_requested = true
	var run_state := get_node_or_null("/root/RunLoadout") as RunLoadoutState
	if run_state != null:
		run_state.print_time_summary()
	if not result_scene_path.is_empty():
		get_tree().call_deferred(&"change_scene_to_file", result_scene_path)
