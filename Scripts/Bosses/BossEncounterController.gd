extends Node

@export var player: PlayerController
@export var boss: BossController
@export var time_hud: PreparationHUD
@export var floating_time_text_scene: PackedScene
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
		time_health.time_lost.connect(_on_player_time_lost)
		time_health.time_recovered.connect(_on_player_time_recovered)
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


func _on_player_time_lost(amount: float, source: StringName) -> void:
	if source != &"drain":
		_spawn_time_text(player.global_position + Vector2(0, -80), "-%.1fs" % amount, Color(0.66, 0.29, 0.18))


func _on_player_time_recovered(amount: float, _source: StringName) -> void:
	_spawn_time_text(
		boss.global_position + Vector2(0, -105),
		"+%.1fs" % amount,
		Color(0.84, 0.64, 0.28)
	)


func _spawn_time_text(world_position: Vector2, value: String, color: Color) -> void:
	if floating_time_text_scene == null:
		return
	var floating_text := floating_time_text_scene.instantiate() as FloatingTimeText
	if floating_text == null:
		return
	get_tree().current_scene.add_child(floating_text)
	floating_text.global_position = world_position
	floating_text.setup(value, color)


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
