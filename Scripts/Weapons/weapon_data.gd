class_name WeaponData
extends Resource

@export var weapon_name: String

@export var attack_behavior: AttackBehavior

@export_range(1, 1000000, 1, "or_greater") var damage: int = 1
@export_range(0.01, 1000.0, 0.01, "or_greater") var attacks_per_second: float = 5.0
@export var automatic: bool = false

@export var projectile_scene: PackedScene
@export_range(0.01, 100000.0, 0.01, "or_greater") var projectile_speed: float = 600.0
@export_range(1, 128, 1, "or_greater") var projectile_count: int = 1
@export_range(0.0, 360.0, 0.1, "or_greater") var spread_degrees: float = 0.0
