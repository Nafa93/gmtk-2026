class_name ProceduralRoomGenerator
extends Node2D

signal generation_finished(room_count: int, used_seed: int)

@export_group("Generation")
@export_range(2, 100, 1, "or_greater") var room_count: int = 9
@export var random_seed: int = -1
@export var generate_on_ready: bool = true
@export var generation_origin: Node2D

@export_group("Room Geometry")
@export var room_size: Vector2 = Vector2(2200.0, 1600.0)
@export_range(1.0, 100.0, 1.0, "or_greater") var wall_thickness: float = 20.0
@export var floor_color: Color = Color(0.12, 0.14, 0.18, 1.0)
@export var alternate_floor_color: Color = Color(0.16, 0.18, 0.23, 1.0)
@export var wall_color: Color = Color(0.36, 0.4, 0.48, 1.0)
@export var obstacle_color: Color = Color(0.28, 0.32, 0.4, 1.0)
@export_range(40.0, 200.0, 5.0, "or_greater") var obstacle_thickness: float = 75.0
## Must remain larger than the player's collision diameter (currently ~124 px).
@export_range(140.0, 500.0, 5.0, "or_greater") var minimum_hallway_width: float = 280.0
@export var torch_scene: PackedScene
@export_range(200.0, 1000.0, 10.0, "or_greater") var torch_spacing: float = 420.0
@export_range(80.0, 300.0, 5.0, "or_greater") var loot_edge_margin: float = 120.0

@export_group("Output")
@export var rooms_container: Node2D
@export var spawn_points_container: Node2D
@export var loot_distributor: LootDistributor

var used_seed: int = 0
var generated_cells: Array[Vector2i] = []

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	if generate_on_ready:
		call_deferred(&"generate")


func generate() -> void:
	clear_generated_rooms()
	_configure_rng()

	if rooms_container == null or spawn_points_container == null:
		push_error("ProceduralRoomGenerator requires both output containers.")
		return

	generated_cells = _generate_connected_cells(maxi(room_count, 2))
	var occupied: Dictionary = {}
	for cell: Vector2i in generated_cells:
		occupied[cell] = true

	for index: int in range(generated_cells.size()):
		_build_room(generated_cells[index], index, occupied)

	if loot_distributor != null:
		loot_distributor.total_weapon_count = (
			loot_distributor.loot_pool.get_valid_weapon_scenes().size()
			if loot_distributor.loot_pool != null
			else 0
		)
		loot_distributor.distance_origin = generation_origin
		loot_distributor.distribute()

	generation_finished.emit(generated_cells.size(), used_seed)


func clear_generated_rooms() -> void:
	if loot_distributor != null:
		loot_distributor.clear_generated_loot()
	if rooms_container != null:
		for child: Node in rooms_container.get_children():
			child.free()
	if spawn_points_container != null:
		for child: Node in spawn_points_container.get_children():
			child.free()
	generated_cells.clear()


func _configure_rng() -> void:
	if random_seed == -1:
		_rng.randomize()
		used_seed = _rng.seed
	else:
		used_seed = random_seed
		_rng.seed = used_seed

	if OS.is_debug_build():
		print("ProceduralRoomGenerator seed: %d" % used_seed)


func _generate_connected_cells(target_count: int) -> Array[Vector2i]:
	var cells: Array[Vector2i] = [Vector2i.ZERO]
	var occupied: Dictionary = {Vector2i.ZERO: true}
	var directions: Array[Vector2i] = [
		Vector2i.RIGHT,
		Vector2i.LEFT,
		Vector2i.DOWN,
		Vector2i.UP,
	]

	while cells.size() < target_count:
		var anchor: Vector2i = cells[_rng.randi_range(0, cells.size() - 1)]
		var direction: Vector2i = directions[
			_rng.randi_range(0, directions.size() - 1)
		]
		var candidate: Vector2i = anchor + direction
		if occupied.has(candidate):
			continue
		occupied[candidate] = true
		cells.append(candidate)

	return cells


func _build_room(cell: Vector2i, index: int, occupied: Dictionary) -> void:
	var room := Node2D.new()
	room.name = "Room_%02d" % (index + 1)
	room.position = _origin_position() + Vector2(cell) * room_size
	rooms_container.add_child(room)

	var floor := Polygon2D.new()
	var half_size: Vector2 = room_size * 0.5
	floor.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y),
		Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y),
		Vector2(-half_size.x, half_size.y),
	])
	floor.color = floor_color if index % 2 == 0 else alternate_floor_color
	floor.z_index = -10
	room.add_child(floor)

	_add_boundary_wall(room, cell, Vector2i.UP, occupied)
	_add_boundary_wall(room, cell, Vector2i.DOWN, occupied)
	_add_boundary_wall(room, cell, Vector2i.LEFT, occupied)
	_add_boundary_wall(room, cell, Vector2i.RIGHT, occupied)

	var weapon_position: Vector2 = _build_puzzle_layout(room, index)
	weapon_position = _clamp_loot_to_room(weapon_position)
	var spawn_point := LootSpawnPoint.new()
	spawn_point.name = "WeaponSpawn_%02d" % (index + 1)
	spawn_point.position = room.position + weapon_position
	spawn_points_container.add_child(spawn_point)


func _clamp_loot_to_room(local_position: Vector2) -> Vector2:
	var half_size: Vector2 = room_size * 0.5
	var safe_half_extents := Vector2(
		maxf(half_size.x - loot_edge_margin, 0.0),
		maxf(half_size.y - loot_edge_margin, 0.0)
	)
	return Vector2(
		clampf(local_position.x, -safe_half_extents.x, safe_half_extents.x),
		clampf(local_position.y, -safe_half_extents.y, safe_half_extents.y)
	)


func _add_boundary_wall(
	room: Node2D,
	cell: Vector2i,
	direction: Vector2i,
	occupied: Dictionary
) -> void:
	if occupied.has(cell + direction):
		return

	var half_size: Vector2 = room_size * 0.5
	var wall_size: Vector2
	var wall_position: Vector2
	if direction.x == 0:
		wall_size = Vector2(room_size.x + wall_thickness, wall_thickness)
		wall_position = Vector2(0.0, direction.y * half_size.y)
	else:
		wall_size = Vector2(wall_thickness, room_size.y + wall_thickness)
		wall_position = Vector2(direction.x * half_size.x, 0.0)

	var wall: StaticBody2D = _add_obstacle(
		room,
		wall_position,
		wall_size,
		wall_color
	)
	_add_torches_to_wall(wall, wall_size, direction)


func _build_puzzle_layout(room: Node2D, room_index: int) -> Vector2:
	# The starting room stays relatively open so the player can orient themselves.
	if room_index == 0:
		_add_obstacle(room, Vector2(-180.0, 0.0), Vector2(90.0, 260.0))
		_add_obstacle(room, Vector2(180.0, 0.0), Vector2(90.0, 260.0))
		return Vector2(0.0, -210.0)

	var pattern: int = room_index % 4
	match pattern:
		0:
			return _build_slalom_layout(room)
		1:
			return _build_pillar_layout(room)
		2:
			return _build_spiral_layout(room)
		_:
			return _build_gate_layout(room)


func _build_slalom_layout(room: Node2D) -> Vector2:
	var length: float = room_size.x * 0.58
	# Two alternating barriers fit this room while retaining enough vertical
	# turning space for the player's complete collision circle. Three did not.
	_add_obstacle(
		room,
		Vector2(-room_size.x * 0.16, -180.0),
		Vector2(length, obstacle_thickness)
	)
	_add_obstacle(
		room,
		Vector2(room_size.x * 0.16, 180.0),
		Vector2(length, obstacle_thickness)
	)
	return Vector2(-room_size.x * 0.35, room_size.y * 0.36)


func _build_pillar_layout(room: Node2D) -> Vector2:
	var pillar_size := Vector2(70.0, 70.0)
	for x: float in [-320.0, 0.0, 320.0]:
		for y: float in [-190.0, 190.0]:
			_add_obstacle(room, Vector2(x, y), pillar_size)
	return Vector2(440.0, -290.0)


func _build_spiral_layout(room: Node2D) -> Vector2:
	# A wide, squared spiral. Every turn is at least minimum_hallway_width wide.
	var horizontal_length: float = room_size.x - minimum_hallway_width * 1.35
	var vertical_length: float = room_size.y - minimum_hallway_width * 1.25
	_add_obstacle(
		room,
		Vector2(-minimum_hallway_width * 0.18, -room_size.y * 0.23),
		Vector2(horizontal_length, obstacle_thickness)
	)
	_add_obstacle(
		room,
		Vector2(room_size.x * 0.28, 0.0),
		Vector2(obstacle_thickness, vertical_length)
	)
	_add_obstacle(
		room,
		Vector2(-minimum_hallway_width * 0.22, room_size.y * 0.22),
		# Extend through the vertical segment so the corner is visibly and
		# physically sealed instead of leaving an unusable player-sized gap.
		Vector2(horizontal_length, obstacle_thickness)
	)
	return Vector2(70.0, 25.0)


func _build_gate_layout(room: Node2D) -> Vector2:
	var segment_height: float = (
		room_size.y - minimum_hallway_width
	) * 0.5
	var vertical_size := Vector2(obstacle_thickness, segment_height)
	var segment_center_y: float = (
		minimum_hallway_width + segment_height
	) * 0.5
	_add_obstacle(room, Vector2(-320.0, -segment_center_y), vertical_size)
	_add_obstacle(room, Vector2(-320.0, segment_center_y), vertical_size)
	_add_obstacle(room, Vector2(40.0, -segment_center_y), vertical_size)
	_add_obstacle(room, Vector2(40.0, segment_center_y), vertical_size)
	_add_obstacle(room, Vector2(400.0, -segment_center_y), vertical_size)
	_add_obstacle(room, Vector2(400.0, segment_center_y), vertical_size)
	return Vector2(460.0, 0.0)


func _add_obstacle(
	parent: Node2D,
	obstacle_position: Vector2,
	obstacle_size: Vector2,
	color: Color = Color.TRANSPARENT
) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.position = obstacle_position
	body.collision_layer = 1
	body.collision_mask = 0
	parent.add_child(body)

	var shape := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = obstacle_size
	shape.shape = rectangle
	body.add_child(shape)

	var visual := Polygon2D.new()
	var obstacle_half: Vector2 = obstacle_size * 0.5
	visual.polygon = PackedVector2Array([
		Vector2(-obstacle_half.x, -obstacle_half.y),
		Vector2(obstacle_half.x, -obstacle_half.y),
		Vector2(obstacle_half.x, obstacle_half.y),
		Vector2(-obstacle_half.x, obstacle_half.y),
	])
	visual.color = obstacle_color if color == Color.TRANSPARENT else color
	body.add_child(visual)
	return body


func _add_torches_to_wall(
	wall: StaticBody2D,
	wall_size: Vector2,
	outward_direction: Vector2i
) -> void:
	if torch_scene == null:
		return

	var wall_length: float = wall_size.x if outward_direction.y != 0 else wall_size.y
	var torch_count: int = maxi(1, floori(wall_length / torch_spacing))
	var inward_offset: Vector2 = -Vector2(outward_direction) * (
		wall_thickness * 0.5 + 10.0
	)

	for index: int in range(torch_count):
		var ratio: float = float(index + 1) / float(torch_count + 1)
		var along_wall: float = lerpf(-wall_length * 0.5, wall_length * 0.5, ratio)
		var torch_node: Node = torch_scene.instantiate()
		var torch := torch_node as Node2D
		if torch == null:
			torch_node.free()
			push_error("ProceduralRoomGenerator torch_scene root must be Node2D.")
			return

		wall.add_child(torch)
		if outward_direction.y != 0:
			torch.position = Vector2(along_wall, 0.0) + inward_offset
		else:
			torch.position = Vector2(0.0, along_wall) + inward_offset


func _origin_position() -> Vector2:
	if generation_origin != null:
		return generation_origin.position
	return Vector2.ZERO
