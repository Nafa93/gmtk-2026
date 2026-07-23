class_name AttackBehavior
extends Resource


func attack(
	_owner: Node2D,
	_weapon: WeaponData,
	_attack_position: Vector2,
	_attack_direction: Vector2
) -> void:
	push_warning("AttackBehavior.attack() must be implemented by a concrete behavior.")
