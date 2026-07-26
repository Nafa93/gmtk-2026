class_name ProceduralRoomGenerator
extends Node2D

signal generation_finished(room_count: int, used_seed: int)

@export_group("Generation")
@export_range(2, 100, 1, "or_greater") var room_count: int = 9
@export var random_seed: int = -1
@export var generate_on_ready: bool = true
@export var generation_origin: Node2D

@export_group("Room Geometry")
@export var room_size: Vector2 = Vector2(1650.0, 1200.0)
@export_range(1.0, 100.0, 1.0, "or_greater") var wall_thickness: float = 20.0
@export var floor_color: Color = Color(0.24, 0.125, 0.055, 1.0)
@export var alternate_floor_color: Color = Color(0.29, 0.16, 0.075, 1.0)
@export var wall_color: Color = Color(0.12, 0.055, 0.025, 1.0)
@export var obstacle_color: Color = Color(0.34, 0.17, 0.065, 1.0)
@export_range(40.0, 200.0, 5.0, "or_greater") var obstacle_thickness: float = 75.0
## Must remain larger than the player's collision diameter (currently ~124 px).
@export_range(140.0, 500.0, 5.0, "or_greater") var minimum_hallway_width: float = 280.0
@export var torch_scene: PackedScene
@export_range(200.0, 1000.0, 10.0, "or_greater") var torch_spacing: float = 420.0
@export_range(80.0, 300.0, 5.0, "or_greater") var loot_edge_margin: float = 120.0
@export_group("Saloon Dressing")
@export var plank_line_color: Color = Color(0.105, 0.045, 0.018, 0.72)
@export var rug_color: Color = Color(0.38, 0.075, 0.045, 0.9)
@export var rug_border_color: Color = Color(0.72, 0.48, 0.18, 0.9)
@export var furniture_color: Color = Color(0.31, 0.13, 0.04, 1.0)
@export var furniture_edge_color: Color = Color(0.095, 0.038, 0.015, 1.0)

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
		# The upper wall of the starting room is reserved for the boss entrance.
		if candidate == Vector2i.UP:
			continue
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
	_add_floor_planks(room, half_size, index)
	_add_saloon_rug(room, index)

	_add_boundary_wall(room, cell, Vector2i.UP, occupied)
	_add_boundary_wall(room, cell, Vector2i.DOWN, occupied)
	_add_boundary_wall(room, cell, Vector2i.LEFT, occupied)
	_add_boundary_wall(room, cell, Vector2i.RIGHT, occupied)

	var weapon_position: Vector2 = _build_puzzle_layout(room, index)
	_add_saloon_furniture(room, index)
	weapon_position = _clamp_loot_to_room(weapon_position)
	var spawn_point := LootSpawnPoint.new()
	spawn_point.name = "WeaponSpawn_%02d" % (index + 1)
	spawn_point.position = room.position + weapon_position
	spawn_points_container.add_child(spawn_point)


func _add_floor_planks(room: Node2D, half_size: Vector2, room_index: int) -> void:
	var wood_floor := SaloonWoodFloor.new()
	wood_floor.z_index = -9
	wood_floor.room_size = half_size * 2.0
	wood_floor.base_color = (
		floor_color if room_index % 2 == 0 else alternate_floor_color
	)
	wood_floor.room_index = room_index
	room.add_child(wood_floor)


func _add_saloon_rug(room: Node2D, room_index: int) -> void:
	var rug_size := Vector2(520.0, 310.0)
	var rug_center := Vector2(0.0, 250.0 if room_index % 2 == 0 else -250.0)
	var rug := Polygon2D.new()
	rug.z_index = -8
	var half_rug: Vector2 = rug_size * 0.5
	rug.polygon = PackedVector2Array([
		rug_center + Vector2(-half_rug.x, -half_rug.y),
		rug_center + Vector2(half_rug.x, -half_rug.y),
		rug_center + Vector2(half_rug.x, half_rug.y),
		rug_center + Vector2(-half_rug.x, half_rug.y),
	])
	rug.color = rug_color
	room.add_child(rug)

	var border := Line2D.new()
	border.z_index = -7
	border.width = 12.0
	border.default_color = rug_border_color
	border.closed = true
	border.points = rug.polygon
	room.add_child(border)


func _add_saloon_furniture(room: Node2D, room_index: int) -> void:
	var half_size: Vector2 = room_size * 0.5
	var side: float = -1.0 if room_index % 2 == 0 else 1.0

	# A long bar counter sits against a side wall, away from the central route.
	var bar_counter: StaticBody2D = _add_obstacle(
		room,
		Vector2(side * (half_size.x - 360.0), -half_size.y + 210.0),
		Vector2(460.0, 210.0),
		furniture_color
	)
	_add_rectangular_wood_grain(bar_counter, Vector2(460.0, 210.0), room_index)

	# Card tables and stools occupy the roomy corners created by the larger rooms.
	_add_card_table(room, Vector2(-half_size.x + 300.0, half_size.y - 300.0))
	_add_card_table(room, Vector2(half_size.x - 300.0, half_size.y - 300.0))
	_add_barrel_stack(
		room,
		Vector2(-side * (half_size.x - 180.0), -half_size.y + 180.0)
	)


func _add_card_table(room: Node2D, table_position: Vector2) -> void:
	var table := StaticBody2D.new()
	table.position = table_position
	table.collision_layer = 1
	table.collision_mask = 0
	room.add_child(table)

	var collision := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 72.0
	collision.shape = circle
	table.add_child(collision)

	var top := Polygon2D.new()
	top.polygon = _pixel_round_table_polygon()
	top.color = Color(0.48, 0.225, 0.085, 1.0)
	table.add_child(top)
	_add_round_table_grain(table)

	var rim := Line2D.new()
	rim.width = 10.0
	rim.closed = true
	rim.joint_mode = Line2D.LINE_JOINT_BEVEL
	rim.default_color = Color(0.075, 0.035, 0.055, 1.0)
	rim.points = top.polygon
	table.add_child(rim)

	for direction: Vector2 in [Vector2.UP, Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT]:
		_add_pixel_chair(table, direction)


func _add_pixel_chair(table: StaticBody2D, direction: Vector2) -> void:
	var chair := Node2D.new()
	chair.position = direction * 126.0
	chair.rotation = direction.angle() + PI * 0.5
	chair.z_index = -1
	table.add_child(chair)

	var seat_shape := PackedVector2Array([
		Vector2(-20.0, -16.0),
		Vector2(20.0, -16.0),
		Vector2(24.0, -12.0),
		Vector2(24.0, 12.0),
		Vector2(20.0, 16.0),
		Vector2(-20.0, 16.0),
		Vector2(-24.0, 12.0),
		Vector2(-24.0, -12.0),
	])
	var seat := Polygon2D.new()
	seat.polygon = seat_shape
	seat.color = Color(0.48, 0.225, 0.085, 1.0)
	chair.add_child(seat)

	var seat_grain := Polygon2D.new()
	seat_grain.polygon = PackedVector2Array([
		Vector2(-14.0, -3.0),
		Vector2(5.0, -3.0),
		Vector2(5.0, 1.0),
		Vector2(16.0, 1.0),
		Vector2(16.0, 5.0),
		Vector2(-14.0, 5.0),
	])
	seat_grain.color = Color(0.68, 0.35, 0.13, 0.5)
	chair.add_child(seat_grain)

	var seat_rim := Line2D.new()
	seat_rim.width = 6.0
	seat_rim.closed = true
	seat_rim.joint_mode = Line2D.LINE_JOINT_BEVEL
	seat_rim.default_color = Color(0.075, 0.035, 0.055, 1.0)
	seat_rim.points = seat_shape
	chair.add_child(seat_rim)

	var backrest_shape := PackedVector2Array([
		Vector2(-26.0, -34.0),
		Vector2(26.0, -34.0),
		Vector2(26.0, -24.0),
		Vector2(22.0, -20.0),
		Vector2(-22.0, -20.0),
		Vector2(-26.0, -24.0),
	])
	var backrest := Polygon2D.new()
	backrest.polygon = backrest_shape
	backrest.color = Color(0.39, 0.16, 0.055, 1.0)
	chair.add_child(backrest)

	var backrest_rim := Line2D.new()
	backrest_rim.width = 5.0
	backrest_rim.closed = true
	backrest_rim.joint_mode = Line2D.LINE_JOINT_BEVEL
	backrest_rim.default_color = Color(0.075, 0.035, 0.055, 1.0)
	backrest_rim.points = backrest_shape
	chair.add_child(backrest_rim)


func _pixel_round_table_polygon() -> PackedVector2Array:
	# Chunky oval based on the supplied pixel-art table reference.
	return PackedVector2Array([
		Vector2(-44.0, -68.0),
		Vector2(44.0, -68.0),
		Vector2(44.0, -64.0),
		Vector2(64.0, -64.0),
		Vector2(64.0, -56.0),
		Vector2(76.0, -56.0),
		Vector2(76.0, -44.0),
		Vector2(84.0, -44.0),
		Vector2(84.0, -24.0),
		Vector2(88.0, -24.0),
		Vector2(88.0, 24.0),
		Vector2(84.0, 24.0),
		Vector2(84.0, 44.0),
		Vector2(76.0, 44.0),
		Vector2(76.0, 56.0),
		Vector2(64.0, 56.0),
		Vector2(64.0, 64.0),
		Vector2(44.0, 64.0),
		Vector2(44.0, 68.0),
		Vector2(-44.0, 68.0),
		Vector2(-44.0, 64.0),
		Vector2(-64.0, 64.0),
		Vector2(-64.0, 56.0),
		Vector2(-76.0, 56.0),
		Vector2(-76.0, 44.0),
		Vector2(-84.0, 44.0),
		Vector2(-84.0, 24.0),
		Vector2(-88.0, 24.0),
		Vector2(-88.0, -24.0),
		Vector2(-84.0, -24.0),
		Vector2(-84.0, -44.0),
		Vector2(-76.0, -44.0),
		Vector2(-76.0, -56.0),
		Vector2(-64.0, -56.0),
		Vector2(-64.0, -64.0),
		Vector2(-44.0, -64.0),
	])


func _add_round_table_grain(table: StaticBody2D) -> void:
	var board_colors: Array[Color] = [
		Color(0.66, 0.31, 0.13, 1.0),
		Color(0.57, 0.255, 0.105, 1.0),
		Color(0.69, 0.345, 0.15, 1.0),
		Color(0.54, 0.23, 0.095, 1.0),
	]
	var boards: Array[PackedVector2Array] = [
		PackedVector2Array([
			Vector2(-76.0, -48.0), Vector2(-44.0, -64.0),
			Vector2(-8.0, -64.0), Vector2(-52.0, 52.0),
			Vector2(-72.0, 44.0), Vector2(-84.0, 20.0),
		])
		,
		PackedVector2Array([
			Vector2(-4.0, -64.0), Vector2(32.0, -64.0),
			Vector2(-8.0, 64.0), Vector2(-48.0, 52.0),
		])
		,
		PackedVector2Array([
			Vector2(36.0, -64.0), Vector2(64.0, -56.0),
			Vector2(76.0, -44.0), Vector2(32.0, 64.0),
			Vector2(-4.0, 64.0),
		])
		,
		PackedVector2Array([
			Vector2(80.0, -36.0), Vector2(84.0, 32.0),
			Vector2(64.0, 56.0), Vector2(36.0, 64.0),
			Vector2(76.0, -40.0),
		]),
	]
	for index: int in range(boards.size()):
		var board := Polygon2D.new()
		board.polygon = boards[index]
		board.color = board_colors[index]
		table.add_child(board)

	var seam_color := Color(0.25, 0.095, 0.07, 1.0)
	for seam_points: PackedVector2Array in [
		PackedVector2Array([Vector2(-8.0, -64.0), Vector2(-52.0, 52.0)]),
		PackedVector2Array([Vector2(32.0, -64.0), Vector2(-8.0, 64.0)]),
		PackedVector2Array([Vector2(76.0, -44.0), Vector2(32.0, 64.0)]),
	]:
		var seam := Line2D.new()
		seam.width = 6.0
		seam.default_color = seam_color
		seam.antialiased = false
		seam.points = seam_points
		table.add_child(seam)


func _add_rectangular_wood_grain(
	furniture: StaticBody2D,
	furniture_size: Vector2,
	variation_seed: int
) -> void:
	# Replace the generator's plain obstacle rectangle with the styled tabletop.
	for child: Node in furniture.get_children():
		if child is Polygon2D:
			child.visible = false

	var half_size: Vector2 = furniture_size * 0.5
	var corner: float = 16.0
	var tabletop_shape := PackedVector2Array([
		Vector2(-half_size.x + corner, -half_size.y),
		Vector2(half_size.x - corner, -half_size.y),
		Vector2(half_size.x - corner, -half_size.y + 4.0),
		Vector2(half_size.x, -half_size.y + 4.0),
		Vector2(half_size.x, half_size.y - 4.0),
		Vector2(half_size.x - corner, half_size.y - 4.0),
		Vector2(half_size.x - corner, half_size.y),
		Vector2(-half_size.x + corner, half_size.y),
		Vector2(-half_size.x + corner, half_size.y - 4.0),
		Vector2(-half_size.x, half_size.y - 4.0),
		Vector2(-half_size.x, -half_size.y + 4.0),
		Vector2(-half_size.x + corner, -half_size.y + 4.0),
	])
	var tabletop := Polygon2D.new()
	tabletop.polygon = tabletop_shape
	tabletop.color = Color(0.56, 0.29, 0.14, 1.0)
	furniture.add_child(tabletop)

	var board_colors: Array[Color] = [
		Color(0.58, 0.30, 0.145, 1.0),
		Color(0.63, 0.34, 0.17, 1.0),
		Color(0.55, 0.275, 0.13, 1.0),
	]
	var board_height: float = furniture_size.y / 3.0
	for board_index: int in range(3):
		var board := Polygon2D.new()
		var top_y: float = (
			-half_size.y + float(board_index) * board_height
			+ float([5, 2, 7][board_index])
		)
		var bottom_y: float = minf(
			-half_size.y + float(board_index + 1) * board_height
			- float([3, 7, 4][board_index]),
			half_size.y - 4.0
		)
		var left_offset: float = float([7, 3, 12][board_index])
		var right_offset: float = float([13, 5, 8][board_index])
		board.polygon = PackedVector2Array([
			Vector2(-half_size.x + left_offset + 4.0, top_y),
			Vector2(half_size.x - right_offset, top_y),
			Vector2(half_size.x - right_offset, bottom_y - 4.0),
			Vector2(half_size.x - right_offset - 5.0, bottom_y),
			Vector2(-half_size.x + left_offset, bottom_y),
			Vector2(-half_size.x + left_offset, top_y + 4.0),
		])
		board.color = board_colors[board_index]
		furniture.add_child(board)

	for seam_index: int in range(1, 3):
		var seam := Line2D.new()
		var seam_y: float = -half_size.y + float(seam_index) * board_height
		seam.width = 5.0
		seam.default_color = Color(0.22, 0.095, 0.065, 0.9)
		seam.antialiased = false
		seam.points = PackedVector2Array([
			Vector2(-half_size.x + 6.0, seam_y),
			Vector2(half_size.x - 6.0, seam_y),
		])
		furniture.add_child(seam)

	var grain_colors: Array[Color] = [
		Color(0.34, 0.15, 0.07, 0.55),
		Color(0.74, 0.43, 0.22, 0.34),
	]
	for index: int in range(12):
		var board_index: int = index % 3
		var board_top: float = -half_size.y + float(board_index) * board_height
		var y: float = board_top + 14.0 + float((index / 3) * 11)
		var start_x: float = (
			-half_size.x
			+ 16.0
			+ float(posmod(index * 67 + variation_seed * 29, 96))
		)
		var length: float = 48.0 + float(posmod(index * 43 + variation_seed, 110))
		var end_x: float = minf(start_x + length, half_size.x - 16.0)
		var grain := Polygon2D.new()
		grain.polygon = PackedVector2Array([
			Vector2(start_x, y),
			Vector2(start_x + (end_x - start_x) * 0.55, y),
			Vector2(start_x + (end_x - start_x) * 0.55, y + 3.0),
			Vector2(end_x, y + 3.0),
			Vector2(end_x, y + 6.0),
			Vector2(start_x, y + 6.0),
		])
		grain.color = grain_colors[index % grain_colors.size()]
		furniture.add_child(grain)

	var rim := Line2D.new()
	rim.width = 8.0
	rim.closed = true
	rim.joint_mode = Line2D.LINE_JOINT_BEVEL
	rim.default_color = Color(0.075, 0.035, 0.055, 1.0)
	rim.points = tabletop_shape
	furniture.add_child(rim)


func _add_wooden_obstacle_style(
	obstacle: StaticBody2D,
	obstacle_size: Vector2
) -> void:
	for child: Node in obstacle.get_children():
		if child is Polygon2D:
			child.color = Color(0.12, 0.045, 0.022, 1.0)

	var horizontal: bool = obstacle_size.x >= obstacle_size.y
	var long_size: float = obstacle_size.x if horizontal else obstacle_size.y
	var short_size: float = obstacle_size.y if horizontal else obstacle_size.x
	var half_long: float = long_size * 0.5
	var half_short: float = short_size * 0.5
	var board_count: int = (
		1 if short_size < 50.0
		else clampi(roundi(short_size / 58.0), 2, 6)
	)
	var board_span: float = short_size / float(board_count)
	var seed: int = absi(
		roundi(obstacle.position.x * 0.31)
		+ roundi(obstacle.position.y * 0.47)
	)
	var board_colors: Array[Color] = [
		Color(0.43, 0.205, 0.085, 1.0),
		Color(0.51, 0.255, 0.105, 1.0),
		Color(0.47, 0.225, 0.09, 1.0),
		Color(0.56, 0.29, 0.125, 1.0),
	]

	for board_index: int in range(board_count):
		# Boards meet cleanly; the backing reads as a seam instead of empty floor.
		var start_short: float = -half_short + float(board_index) * board_span
		var end_short: float = -half_short + float(board_index + 1) * board_span
		var start_inset: float = 5.0 + float(posmod(seed + board_index * 11, 13))
		var end_inset: float = 5.0 + float(posmod(seed + board_index * 17, 15))
		var plank_points := PackedVector2Array([
			Vector2(-half_long + start_inset + 4.0, start_short),
			Vector2(half_long - end_inset, start_short),
			Vector2(half_long - end_inset, end_short - 4.0),
			Vector2(half_long - end_inset - 4.0, end_short),
			Vector2(-half_long + start_inset, end_short),
			Vector2(-half_long + start_inset, start_short + 4.0),
		])
		if not horizontal:
			for point_index: int in range(plank_points.size()):
				var point: Vector2 = plank_points[point_index]
				plank_points[point_index] = Vector2(point.y, point.x)

		var plank := Polygon2D.new()
		plank.polygon = plank_points
		plank.color = board_colors[
			posmod(seed + board_index, board_colors.size())
		]
		obstacle.add_child(plank)

		var grain_start: float = -half_long + start_inset + 18.0
		var grain_end: float = minf(
			grain_start + 36.0 + float(posmod(seed + board_index * 37, 90)),
			half_long - end_inset - 12.0
		)
		if grain_end > grain_start:
			var grain_short: float = lerpf(start_short, end_short, 0.55)
			var grain_points := PackedVector2Array([
				Vector2(grain_start, grain_short),
				Vector2(grain_start + (grain_end - grain_start) * 0.6, grain_short),
				Vector2(grain_start + (grain_end - grain_start) * 0.6, grain_short + 4.0),
				Vector2(grain_end, grain_short + 4.0),
			])
			if not horizontal:
				for point_index: int in range(grain_points.size()):
					var point: Vector2 = grain_points[point_index]
					grain_points[point_index] = Vector2(point.y, point.x)
			var grain := Line2D.new()
			grain.width = 4.0
			grain.default_color = Color(0.27, 0.11, 0.045, 0.62)
			grain.antialiased = false
			grain.points = grain_points
			obstacle.add_child(grain)

	var outline_points := PackedVector2Array([
		Vector2(-obstacle_size.x * 0.5 + 8.0, -obstacle_size.y * 0.5),
		Vector2(obstacle_size.x * 0.5 - 8.0, -obstacle_size.y * 0.5),
		Vector2(obstacle_size.x * 0.5, -obstacle_size.y * 0.5 + 8.0),
		Vector2(obstacle_size.x * 0.5, obstacle_size.y * 0.5 - 8.0),
		Vector2(obstacle_size.x * 0.5 - 8.0, obstacle_size.y * 0.5),
		Vector2(-obstacle_size.x * 0.5 + 8.0, obstacle_size.y * 0.5),
		Vector2(-obstacle_size.x * 0.5, obstacle_size.y * 0.5 - 8.0),
		Vector2(-obstacle_size.x * 0.5, -obstacle_size.y * 0.5 + 8.0),
	])
	var outline := Line2D.new()
	outline.width = 8.0
	outline.closed = true
	outline.joint_mode = Line2D.LINE_JOINT_BEVEL
	outline.default_color = Color(0.075, 0.035, 0.055, 1.0)
	outline.points = outline_points
	obstacle.add_child(outline)


func _add_barrel_stack(room: Node2D, stack_position: Vector2) -> void:
	var offsets: Array[Vector2] = [
		Vector2(-42.0, 22.0),
		Vector2(42.0, 22.0),
		Vector2(0.0, -38.0),
	]
	for index: int in range(offsets.size()):
		_add_pixel_barrel(room, stack_position + offsets[index], index)


func _add_pixel_barrel(room: Node2D, barrel_position: Vector2, variant: int) -> void:
	var barrel := Node2D.new()
	barrel.position = barrel_position
	room.add_child(barrel)

	var barrel_shape := PackedVector2Array([
		Vector2(-20.0, -40.0),
		Vector2(20.0, -40.0),
		Vector2(20.0, -36.0),
		Vector2(32.0, -36.0),
		Vector2(32.0, -28.0),
		Vector2(40.0, -28.0),
		Vector2(40.0, -16.0),
		Vector2(44.0, -16.0),
		Vector2(44.0, 16.0),
		Vector2(40.0, 16.0),
		Vector2(40.0, 28.0),
		Vector2(32.0, 28.0),
		Vector2(32.0, 36.0),
		Vector2(20.0, 36.0),
		Vector2(20.0, 40.0),
		Vector2(-20.0, 40.0),
		Vector2(-20.0, 36.0),
		Vector2(-32.0, 36.0),
		Vector2(-32.0, 28.0),
		Vector2(-40.0, 28.0),
		Vector2(-40.0, 16.0),
		Vector2(-44.0, 16.0),
		Vector2(-44.0, -16.0),
		Vector2(-40.0, -16.0),
		Vector2(-40.0, -28.0),
		Vector2(-32.0, -28.0),
		Vector2(-32.0, -36.0),
		Vector2(-20.0, -36.0),
	])
	var lid := Polygon2D.new()
	lid.polygon = barrel_shape
	lid.color = [
		Color(0.48, 0.225, 0.075, 1.0),
		Color(0.53, 0.265, 0.09, 1.0),
		Color(0.44, 0.19, 0.06, 1.0),
	][variant % 3]
	barrel.add_child(lid)

	# Broad lid boards make the object read as wood from the top-down camera.
	for seam_y: float in [-16.0, 12.0]:
		var seam := Line2D.new()
		seam.width = 5.0
		seam.default_color = Color(0.22, 0.075, 0.035, 0.92)
		seam.antialiased = false
		seam.points = PackedVector2Array([
			Vector2(-38.0, seam_y),
			Vector2(38.0, seam_y),
		])
		barrel.add_child(seam)

	for grain_data: Vector4 in [
		Vector4(-25.0, -27.0, 28.0, 4.0),
		Vector4(4.0, -5.0, 25.0, 4.0),
		Vector4(-18.0, 26.0, 31.0, 4.0),
	]:
		var grain := Polygon2D.new()
		grain.polygon = PackedVector2Array([
			Vector2(grain_data.x, grain_data.y),
			Vector2(grain_data.x + grain_data.z * 0.55, grain_data.y),
			Vector2(grain_data.x + grain_data.z * 0.55, grain_data.y + 4.0),
			Vector2(grain_data.x + grain_data.z, grain_data.y + 4.0),
			Vector2(grain_data.x + grain_data.z, grain_data.y + grain_data.w),
			Vector2(grain_data.x, grain_data.y + grain_data.w),
		])
		grain.color = Color(0.68, 0.36, 0.12, 0.52)
		barrel.add_child(grain)

	var inner_ring := Line2D.new()
	inner_ring.width = 5.0
	inner_ring.closed = true
	inner_ring.joint_mode = Line2D.LINE_JOINT_BEVEL
	inner_ring.default_color = Color(0.29, 0.12, 0.055, 0.9)
	inner_ring.points = PackedVector2Array([
		Vector2(-18.0, -32.0), Vector2(18.0, -32.0),
		Vector2(32.0, -18.0), Vector2(32.0, 18.0),
		Vector2(18.0, 32.0), Vector2(-18.0, 32.0),
		Vector2(-32.0, 18.0), Vector2(-32.0, -18.0),
	])
	barrel.add_child(inner_ring)

	var rim := Line2D.new()
	rim.width = 8.0
	rim.closed = true
	rim.joint_mode = Line2D.LINE_JOINT_BEVEL
	rim.default_color = Color(0.075, 0.035, 0.055, 1.0)
	rim.points = barrel_shape
	barrel.add_child(rim)


func _circle_polygon(radius: float, point_count: int) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index: int in range(point_count):
		points.append(
			Vector2.RIGHT.rotated(TAU * float(index) / float(point_count)) * radius
		)
	return points


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
	if cell == Vector2i.ZERO and direction == Vector2i.UP:
		_add_boss_entrance_wall(room, half_size)
		return

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
	_add_wooden_obstacle_style(wall, wall_size)
	_add_torches_to_wall(wall, wall_size, direction)


func _add_boss_entrance_wall(room: Node2D, half_size: Vector2) -> void:
	var entrance_width: float = 190.0
	var segment_width: float = (room_size.x - entrance_width) * 0.5
	var segment_offset: float = entrance_width * 0.5 + segment_width * 0.5
	var segment_size := Vector2(segment_width, wall_thickness)

	for x_direction: float in [-1.0, 1.0]:
		var wall := _add_obstacle(
			room,
			Vector2(x_direction * segment_offset, -half_size.y),
			segment_size,
			wall_color
		)
		_add_wooden_obstacle_style(wall, segment_size)


func _build_puzzle_layout(room: Node2D, room_index: int) -> Vector2:
	# The starting room stays relatively open so the player can orient themselves.
	if room_index == 0:
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
	# Keep loot away from the side bar, whose lower edge reaches y = -285
	# after the room was reduced to 75% of its former dimensions.
	return Vector2(520.0, 40.0)


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
	if color == Color.TRANSPARENT:
		_add_wooden_obstacle_style(body, obstacle_size)
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
