class_name BossArena
extends Node2D

@export var arena_size: Vector2 = Vector2(3000.0, 1800.0)
@export_range(10.0, 100.0, 1.0, "or_greater") var wall_thickness: float = 30.0
@export var floor_color: Color = Color(0.09, 0.105, 0.135, 1.0)
@export var wall_color: Color = Color(0.3, 0.33, 0.4, 1.0)
@export var torch_scene: PackedScene
@export_range(200.0, 1000.0, 10.0, "or_greater") var torch_spacing: float = 420.0


func _ready() -> void:
	_build_floor()
	_build_wall(Vector2(0.0, -arena_size.y * 0.5), Vector2(
		arena_size.x + wall_thickness,
		wall_thickness
	), Vector2.DOWN)
	_build_wall(Vector2(0.0, arena_size.y * 0.5), Vector2(
		arena_size.x + wall_thickness,
		wall_thickness
	), Vector2.UP)
	_build_wall(Vector2(-arena_size.x * 0.5, 0.0), Vector2(
		wall_thickness,
		arena_size.y + wall_thickness
	), Vector2.RIGHT)
	_build_wall(Vector2(arena_size.x * 0.5, 0.0), Vector2(
		wall_thickness,
		arena_size.y + wall_thickness
	), Vector2.LEFT)


func _build_floor() -> void:
	var floor := Polygon2D.new()
	var half_size: Vector2 = arena_size * 0.5
	floor.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	floor.color = floor_color
	floor.z_index = -10
	add_child(floor)


func _build_wall(
	wall_position: Vector2,
	wall_size: Vector2,
	inward_direction: Vector2
) -> void:
	var body := StaticBody2D.new()
	body.position = wall_position
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = wall_size
	shape.shape = rectangle
	body.add_child(shape)

	var visual := Polygon2D.new()
	var half_size: Vector2 = wall_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	visual.color = wall_color
	body.add_child(visual)
	_add_torches(body, wall_size, inward_direction)


func _add_torches(
	wall: StaticBody2D,
	wall_size: Vector2,
	inward_direction: Vector2
) -> void:
	if torch_scene == null:
		return

	var is_horizontal: bool = wall_size.x > wall_size.y
	var wall_length: float = wall_size.x if is_horizontal else wall_size.y
	var torch_count: int = maxi(1, floori(wall_length / torch_spacing))
	var inward_offset: Vector2 = inward_direction * (wall_thickness * 0.5 + 10.0)

	for index: int in range(torch_count):
		var ratio: float = float(index + 1) / float(torch_count + 1)
		var along_wall: float = lerpf(-wall_length * 0.5, wall_length * 0.5, ratio)
		var torch := torch_scene.instantiate() as Node2D
		if torch == null:
			push_error("BossArena torch_scene root must be Node2D.")
			return

		wall.add_child(torch)
		torch.position = (
			Vector2(along_wall, 0.0)
			if is_horizontal
			else Vector2(0.0, along_wall)
		) + inward_offset
