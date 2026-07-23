class_name BossController
extends CharacterBody2D

signal phase_changed(new_phase: int)
signal boss_died
signal state_changed(new_state: State)

enum State {
	MOVE,
	TELEGRAPH,
	ATTACK,
	RECOVERY,
	DEAD,
}

@export_group("Required References")
@export var health_component: HealthComponent
@export var boss_sprite: CanvasItem
@export var collision_shape: CollisionShape2D
@export var projectile_origin: Marker2D
@export var projectile_scene: PackedScene
@export var direction_telegraph: Polygon2D
@export var radial_telegraph: Line2D

@export_group("Optional Presentation")
@export var animation_player: AnimationPlayer
@export var telegraph_audio: AudioStreamPlayer2D
@export var attack_audio: AudioStreamPlayer2D

@export_group("Movement")
@export_range(0.0, 10000.0, 1.0, "or_greater") var movement_speed: float = 115.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var preferred_minimum_distance: float = 260.0
@export_range(0.0, 10000.0, 1.0, "or_greater") var preferred_maximum_distance: float = 430.0
@export_range(0.05, 30.0, 0.05, "or_greater") var reposition_duration: float = 1.25

@export_group("Attacks")
@export var attacks: Array[BossAttack] = []

@export_group("Phase Two")
@export_range(0.01, 0.99, 0.01) var phase_two_health_ratio: float = 0.5
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_movement_speed_multiplier: float = 1.2
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_projectile_speed_multiplier: float = 1.2
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_telegraph_multiplier: float = 0.85
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_recovery_multiplier: float = 0.7
@export_range(0.01, 10.0, 0.01, "or_greater") var phase_two_cooldown_multiplier: float = 0.8

var current_state: State = State.MOVE
var current_phase: int = 1

var _target: Node2D
var _selected_attack: BossAttack
var _active_execution: BossAttackExecution
var _attack_cooldowns: Array[float] = []
var _state_time_remaining: float = 0.0
var _last_attack_index: int = -1
var _locked_attack_direction: Vector2 = Vector2.DOWN
var _is_dead: bool = false


func _ready() -> void:
	_target = get_tree().get_first_node_in_group(&"player") as Node2D
	_attack_cooldowns.resize(attacks.size())
	_attack_cooldowns.fill(0.0)

	if health_component == null:
		push_error("BossController requires a HealthComponent.")
		set_physics_process(false)
		return

	if not health_component.died.is_connected(_on_died):
		health_component.died.connect(_on_died)
	if not health_component.health_changed.is_connected(_on_health_changed):
		health_component.health_changed.connect(_on_health_changed)

	_enter_move()


func _physics_process(delta: float) -> void:
	if _is_dead:
		return

	_refresh_target()
	_update_attack_cooldowns(delta)

	match current_state:
		State.MOVE:
			_update_move(delta)
		State.TELEGRAPH:
			_update_telegraph(delta)
		State.ATTACK:
			_update_attack(delta)
		State.RECOVERY:
			_update_recovery(delta)
		State.DEAD:
			return

	move_and_slide()

	if current_state == State.ATTACK and _active_execution != null:
		_active_execution.after_move()
		if _active_execution.finished:
			_enter_recovery()


func spawn_boss_projectile(
	direction: Vector2,
	speed: float,
	damage: int
) -> bool:
	if _is_dead:
		return false
	if projectile_scene == null:
		push_warning("BossController has no projectile_scene assigned.")
		return false
	if direction.is_zero_approx():
		push_warning("BossController cannot spawn a projectile with zero direction.")
		return false

	var projectile_node: Node = projectile_scene.instantiate()
	var projectile: Projectile = projectile_node as Projectile
	if projectile == null:
		projectile_node.free()
		push_error("Boss projectile_scene root must extend Projectile.")
		return false

	var scene_root: Node = get_tree().current_scene
	if scene_root == null:
		projectile.free()
		push_error("BossController cannot spawn projectiles without a current scene.")
		return false

	projectile.initialize(direction.normalized(), speed, damage, self)
	scene_root.add_child(projectile)
	projectile.global_position = projectile_origin.global_position \
			if projectile_origin != null else global_position
	projectile.global_rotation = direction.angle()
	return true


func lock_attack_direction_to_target() -> void:
	if _is_target_valid():
		_locked_attack_direction = global_position.direction_to(_target.global_position)

	if _locked_attack_direction.is_zero_approx():
		_locked_attack_direction = Vector2.DOWN

	rotation = _locked_attack_direction.angle() + PI / 2.0


func get_locked_attack_direction() -> Vector2:
	return _locked_attack_direction


func show_direction_telegraph(
	direction: Vector2,
	length: float,
	width: float,
	color: Color
) -> void:
	hide_telegraphs()
	if direction_telegraph == null:
		return

	rotation = direction.angle() + PI / 2.0
	var half_width: float = width * 0.5
	direction_telegraph.polygon = PackedVector2Array([
		Vector2(-half_width, 0.0),
		Vector2(half_width, 0.0),
		Vector2(half_width, -length),
		Vector2(-half_width, -length),
	])
	direction_telegraph.color = color
	direction_telegraph.visible = true
	_play_telegraph_presentation()


func show_radial_telegraph(radius: float, color: Color) -> void:
	hide_telegraphs()
	if radial_telegraph == null:
		return

	var points := PackedVector2Array()
	var segment_count: int = 48
	for segment: int in range(segment_count + 1):
		var angle: float = TAU * float(segment) / float(segment_count)
		points.append(Vector2.RIGHT.rotated(angle) * radius)

	radial_telegraph.points = points
	radial_telegraph.default_color = color
	radial_telegraph.visible = true
	_play_telegraph_presentation()


func hide_telegraphs() -> void:
	if direction_telegraph != null:
		direction_telegraph.visible = false
	if radial_telegraph != null:
		radial_telegraph.visible = false


func play_attack_effects() -> void:
	if attack_audio != null and attack_audio.stream != null:
		attack_audio.play()
	if animation_player != null and animation_player.has_animation(&"attack"):
		animation_player.play(&"attack")


func find_health_component(start_node: Node) -> HealthComponent:
	var current_node: Node = start_node
	while current_node != null:
		if current_node is HealthComponent:
			return current_node as HealthComponent
		for child: Node in current_node.get_children():
			if child is HealthComponent:
				return child as HealthComponent
		current_node = current_node.get_parent()
	return null


func _update_move(delta: float) -> void:
	_state_time_remaining -= delta
	if not _is_target_valid():
		velocity = Vector2.ZERO
		if _state_time_remaining <= 0.0:
			_state_time_remaining = 0.25
		return

	var to_target: Vector2 = global_position.direction_to(_target.global_position)
	var distance_to_target: float = global_position.distance_to(_target.global_position)
	var move_direction: Vector2

	if distance_to_target > preferred_maximum_distance:
		move_direction = to_target
	elif distance_to_target < preferred_minimum_distance:
		move_direction = -to_target
	else:
		move_direction = to_target.rotated(PI / 2.0)

	var speed: float = movement_speed
	if current_phase >= 2:
		speed *= phase_two_movement_speed_multiplier

	velocity = move_direction * speed
	rotation = to_target.angle() + PI / 2.0

	if _state_time_remaining <= 0.0:
		_select_next_attack(distance_to_target)


func _update_telegraph(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_time_remaining -= delta
	if _state_time_remaining <= 0.0:
		_begin_attack_execution()


func _update_attack(delta: float) -> void:
	if _active_execution == null:
		_enter_recovery()
		return

	_active_execution.physics_update(delta)
	if _active_execution.finished:
		_enter_recovery()


func _update_recovery(delta: float) -> void:
	velocity = Vector2.ZERO
	_state_time_remaining -= delta
	if _state_time_remaining <= 0.0:
		_enter_move()


func _select_next_attack(distance_to_target: float) -> void:
	var candidates: Array[int] = _get_valid_attack_indices(
		distance_to_target,
		true
	)
	if candidates.is_empty():
		candidates = _get_valid_attack_indices(distance_to_target, false)
	if candidates.is_empty():
		velocity = Vector2.ZERO
		_state_time_remaining = 0.25
		return

	var selected_index: int = _pick_weighted_index(candidates)
	_selected_attack = attacks[selected_index]
	_last_attack_index = selected_index
	var cooldown_multiplier: float = phase_two_cooldown_multiplier \
			if current_phase >= 2 else 1.0
	_attack_cooldowns[selected_index] = _selected_attack.cooldown \
			* cooldown_multiplier
	_enter_telegraph()


func _get_valid_attack_indices(
	distance_to_target: float,
	exclude_last: bool
) -> Array[int]:
	var valid_indices: Array[int] = []
	for attack_index: int in range(attacks.size()):
		var attack: BossAttack = attacks[attack_index]
		if attack == null:
			continue
		if _attack_cooldowns[attack_index] > 0.0:
			continue
		if exclude_last and attack_index == _last_attack_index:
			continue
		if not attack.is_valid_for_distance(distance_to_target):
			continue
		valid_indices.append(attack_index)
	return valid_indices


func _pick_weighted_index(candidates: Array[int]) -> int:
	var total_weight: float = 0.0
	for attack_index: int in candidates:
		total_weight += maxf(attacks[attack_index].selection_weight, 0.0)

	if total_weight <= 0.0:
		return candidates[0]

	var roll: float = randf() * total_weight
	for attack_index: int in candidates:
		roll -= maxf(attacks[attack_index].selection_weight, 0.0)
		if roll <= 0.0:
			return attack_index
	return candidates.back()


func _enter_move() -> void:
	_selected_attack = null
	_active_execution = null
	_state_time_remaining = reposition_duration
	_set_state(State.MOVE)


func _enter_telegraph() -> void:
	velocity = Vector2.ZERO
	var duration_multiplier: float = phase_two_telegraph_multiplier \
			if current_phase >= 2 else 1.0
	_state_time_remaining = _selected_attack.telegraph_duration \
			* duration_multiplier
	_set_state(State.TELEGRAPH)
	_selected_attack.begin_telegraph(self, current_phase)


func _begin_attack_execution() -> void:
	hide_telegraphs()
	_active_execution = _selected_attack.create_execution(self, current_phase)
	if _active_execution == null:
		_enter_recovery()
		return
	_set_state(State.ATTACK)


func _enter_recovery() -> void:
	if current_state == State.DEAD:
		return
	velocity = Vector2.ZERO
	hide_telegraphs()
	if _active_execution != null:
		_active_execution.cancel()
	_active_execution = null

	var recovery_multiplier: float = phase_two_recovery_multiplier \
			if current_phase >= 2 else 1.0
	_state_time_remaining = _selected_attack.recovery_duration \
			* recovery_multiplier if _selected_attack != null else 0.25
	_set_state(State.RECOVERY)


func _set_state(new_state: State) -> void:
	if current_state == new_state:
		return
	current_state = new_state
	state_changed.emit(new_state)


func _update_attack_cooldowns(delta: float) -> void:
	for attack_index: int in range(_attack_cooldowns.size()):
		_attack_cooldowns[attack_index] = maxf(
			_attack_cooldowns[attack_index] - delta,
			0.0
		)


func _refresh_target() -> void:
	if _is_target_valid():
		return
	_target = get_tree().get_first_node_in_group(&"player") as Node2D


func _is_target_valid() -> bool:
	return _target != null and is_instance_valid(_target) \
			and _target.is_inside_tree()


func _play_telegraph_presentation() -> void:
	if telegraph_audio != null and telegraph_audio.stream != null:
		telegraph_audio.play()
	if animation_player != null and animation_player.has_animation(&"telegraph"):
		animation_player.play(&"telegraph")


func _on_health_changed(current_health: int, max_health: int) -> void:
	if _is_dead or current_phase >= 2 or max_health <= 0:
		return

	var health_ratio: float = float(current_health) / float(max_health)
	if health_ratio > phase_two_health_ratio:
		return

	current_phase = 2
	if boss_sprite != null:
		boss_sprite.modulate = Color(1.0, 0.35, 0.65, 1.0)
	phase_changed.emit(current_phase)


func _on_died() -> void:
	if _is_dead:
		return

	_is_dead = true
	velocity = Vector2.ZERO
	hide_telegraphs()
	if _active_execution != null:
		_active_execution.cancel()
		_active_execution = null
	if telegraph_audio != null:
		telegraph_audio.stop()
	if attack_audio != null:
		attack_audio.stop()
	if animation_player != null:
		if animation_player.has_animation(&"dead"):
			animation_player.play(&"dead")
		else:
			animation_player.stop()
	if collision_shape != null:
		collision_shape.set_deferred(&"disabled", true)
	collision_layer = 0
	collision_mask = 0
	_set_state(State.DEAD)
	set_physics_process(false)
	boss_died.emit()
