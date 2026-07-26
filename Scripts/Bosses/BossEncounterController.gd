extends Node

@export var player: PlayerController
@export var boss: BossController
@export var time_hud: PreparationHUD
@export var boss_dialog: CanvasItem
@export var boss_dialog_label: Label
@export var floating_time_text_scene: PackedScene
@export_file("*.tscn") var defeat_scene_path: String
@export_file("*.tscn") var victory_scene_path: String

var _result_requested: bool = false
var _victory_dialogue_playing: bool = false

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
	if boss_dialog != null:
		boss_dialog.visible = false
	_play_intro_dialogue(time_health)


func _play_intro_dialogue(time_health: TimeHealthComponent) -> void:
	boss.process_mode = Node.PROCESS_MODE_DISABLED
	player.process_mode = Node.PROCESS_MODE_DISABLED
	if time_health != null:
		time_health.pause_timer()

	player.show_dialog(
		"By midnight, there will be a new sheriff in town.",
		2.8
	)
	await get_tree().create_timer(2.8).timeout
	if player.opening_dialog != null and is_instance_valid(player.opening_dialog):
		player.opening_dialog.visible = false
	if not is_instance_valid(boss) or _result_requested:
		return

	if boss_dialog_label != null:
		boss_dialog_label.text = "We will see."
	if boss_dialog != null:
		boss_dialog.visible = true
	await get_tree().create_timer(1.8).timeout
	if boss_dialog != null and is_instance_valid(boss_dialog):
		boss_dialog.visible = false
	if not is_instance_valid(boss) or _result_requested:
		return

	boss.process_mode = Node.PROCESS_MODE_INHERIT
	player.process_mode = Node.PROCESS_MODE_INHERIT
	if time_health != null:
		time_health.resume_timer()

func _on_player_died() -> void:
	if _victory_dialogue_playing:
		return
	_request_result(defeat_scene_path)

func _on_boss_died() -> void:
	if _result_requested or _victory_dialogue_playing:
		return
	_victory_dialogue_playing = true
	var time_health := player.health_component as TimeHealthComponent
	if time_health != null:
		time_health.pause_timer()
	player.process_mode = Node.PROCESS_MODE_DISABLED
	var dialogue_duration: float = 2.0
	player.show_dialog("I told you so.", dialogue_duration)
	await get_tree().create_timer(dialogue_duration).timeout
	if not is_instance_valid(player):
		return
	if player.opening_dialog != null and is_instance_valid(player.opening_dialog):
		player.opening_dialog.visible = false
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
		var transition := get_node_or_null(
			"/root/SceneTransition"
		) as SceneTransitionController
		if transition != null:
			transition.transition_to_file(result_scene_path)
		else:
			get_tree().call_deferred(&"change_scene_to_file", result_scene_path)
