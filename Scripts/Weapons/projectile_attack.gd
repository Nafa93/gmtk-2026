class_name ProjectileAttack
extends AttackBehavior


func attack(
	owner: Node2D,
	weapon: WeaponData,
	attack_position: Vector2,
	attack_direction: Vector2
) -> void:
	if owner == null:
		push_error("ProjectileAttack requires a valid attacking owner.")
		return

	if weapon == null:
		push_error("ProjectileAttack requires valid WeaponData.")
		return

	if weapon.projectile_scene == null:
		push_error("WeaponData '%s' has no projectile_scene assigned." % weapon.weapon_name)
		return

	if weapon.projectile_count < 1:
		push_warning(
			"WeaponData '%s' has projectile_count below 1; no projectiles were fired."
			% weapon.weapon_name
		)
		return

	var scene_root: Node = owner.get_tree().current_scene
	if scene_root == null:
		push_error("ProjectileAttack cannot fire because the SceneTree has no current scene.")
		return

	var aim_direction: Vector2 = attack_direction.normalized()
	if aim_direction.is_zero_approx():
		push_error("ProjectileAttack received a zero-length attack direction.")
		return

	for _index: int in range(weapon.projectile_count):
		var projectile_node: Node = weapon.projectile_scene.instantiate()
		var projectile: Projectile = projectile_node as Projectile

		if projectile == null:
			projectile_node.free()
			push_error(
				"WeaponData '%s' projectile_scene root must extend Projectile."
				% weapon.weapon_name
			)
			return

		var spread_offset_degrees: float = randf_range(
			-weapon.spread_degrees * 0.5,
			weapon.spread_degrees * 0.5
		)
		var projectile_direction: Vector2 = aim_direction.rotated(
			deg_to_rad(spread_offset_degrees)
		)

		projectile.initialize(
			projectile_direction,
			weapon.projectile_speed,
			weapon.damage,
			owner
		)
		scene_root.add_child(projectile)
		projectile.global_position = attack_position
		projectile.global_rotation = projectile_direction.angle()
