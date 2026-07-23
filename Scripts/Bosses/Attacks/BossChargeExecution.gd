class_name BossChargeExecution
extends BossAttackExecution

const WORLD_LAYER: int = 1

var _boss: BossController
var _direction: Vector2
var _speed: float
var _maximum_duration: float
var _maximum_distance: float
var _contact_damage: int
var _elapsed: float = 0.0
var _distance_travelled: float = 0.0
var _last_position: Vector2
var _damaged_targets: Dictionary = {}


func _init(
	boss: BossController,
	attack: BossChargeAttack,
	phase: int
) -> void:
	_boss = boss
	_direction = boss.get_locked_attack_direction()
	_speed = attack.charge_speed
	_maximum_duration = attack.maximum_duration
	_maximum_distance = attack.maximum_distance
	_contact_damage = attack.contact_damage
	_last_position = boss.global_position

	if phase >= 2:
		_speed *= attack.phase_two_speed_multiplier

	_boss.play_attack_effects()


func physics_update(delta: float) -> void:
	if finished or not is_instance_valid(_boss):
		finished = true
		return

	_elapsed += delta
	if _elapsed >= _maximum_duration or _distance_travelled >= _maximum_distance:
		_finish_charge()
		return

	_boss.velocity = _direction * _speed


func after_move() -> void:
	if finished or not is_instance_valid(_boss):
		return

	_distance_travelled += _last_position.distance_to(_boss.global_position)
	_last_position = _boss.global_position

	for collision_index: int in range(_boss.get_slide_collision_count()):
		var collision: KinematicCollision2D = _boss.get_slide_collision(collision_index)
		var collider: Node = collision.get_collider() as Node
		if collider == null:
			continue

		if collider.is_in_group(&"player"):
			_damage_target_once(collider)
			_finish_charge()
			return

		if collider is CollisionObject2D \
				and ((collider as CollisionObject2D).collision_layer & WORLD_LAYER) != 0:
			_finish_charge()
			return

	if _distance_travelled >= _maximum_distance:
		_finish_charge()


func cancel() -> void:
	_finish_charge()


func _damage_target_once(target: Node) -> void:
	var target_id: int = target.get_instance_id()
	if _damaged_targets.has(target_id):
		return

	_damaged_targets[target_id] = true
	var health: HealthComponent = _boss.find_health_component(target)
	if health != null:
		health.take_damage(_contact_damage)


func _finish_charge() -> void:
	if is_instance_valid(_boss):
		_boss.velocity = Vector2.ZERO
	finished = true
