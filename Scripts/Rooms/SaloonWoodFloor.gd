class_name SaloonWoodFloor
extends Node2D

var room_size: Vector2 = Vector2(1650.0, 1200.0)
var base_color: Color = Color(0.24, 0.125, 0.055, 1.0)
var room_index: int = 0

const PLANK_HEIGHT: float = 72.0
const PLANK_LENGTH: float = 280.0
const SEAM_WIDTH: float = 4.0

const PLANK_COLORS: Array[Color] = [
	Color(0.55, 0.34, 0.16, 1.0),
	Color(0.61, 0.39, 0.19, 1.0),
	Color(0.66, 0.43, 0.22, 1.0),
	Color(0.58, 0.36, 0.17, 1.0),
	Color(0.63, 0.40, 0.20, 1.0),
]
const SEAM_COLOR := Color(0.26, 0.14, 0.075, 0.92)
const GRAIN_COLORS: Array[Color] = [
	Color(0.40, 0.235, 0.12, 0.58),
	Color(0.47, 0.285, 0.145, 0.52),
	Color(0.76, 0.53, 0.29, 0.48),
	Color(0.70, 0.46, 0.235, 0.52),
]
const PIXEL_SIZE: float = 4.0


func _ready() -> void:
	queue_redraw()


func _draw() -> void:
	var half_size: Vector2 = room_size * 0.5
	var row_count: int = ceili(room_size.y / PLANK_HEIGHT)
	var column_count: int = ceili(room_size.x / PLANK_LENGTH) + 1

	for row: int in range(row_count):
		var top: float = -half_size.y + float(row) * PLANK_HEIGHT
		var height: float = minf(PLANK_HEIGHT, half_size.y - top)
		var stagger: float = -PLANK_LENGTH * 0.5 if row % 2 != 0 else 0.0

		for column: int in range(-1, column_count):
			var left: float = -half_size.x + float(column) * PLANK_LENGTH + stagger
			var right: float = minf(left + PLANK_LENGTH, half_size.x)
			var clipped_left: float = maxf(left, -half_size.x)
			if right <= clipped_left:
				continue

			var color_index: int = posmod(
				row * 7 + column * 3 + room_index * 11,
				PLANK_COLORS.size()
			)
			var plank_color: Color = PLANK_COLORS[color_index].lerp(base_color, 0.08)
			draw_rect(
				Rect2(
					Vector2(clipped_left, top),
					Vector2(right - clipped_left, height)
				),
				plank_color
			)
			_draw_grain(clipped_left, right, top, height, row, column)

		draw_line(
			Vector2(-half_size.x, top),
			Vector2(half_size.x, top),
			SEAM_COLOR,
			SEAM_WIDTH
		)

	draw_line(
		Vector2(-half_size.x, half_size.y),
		Vector2(half_size.x, half_size.y),
		SEAM_COLOR,
		SEAM_WIDTH
	)


func _draw_grain(
	left: float,
	right: float,
	top: float,
	height: float,
	row: int,
	column: int
) -> void:
	var width: float = right - left
	if width < 64.0:
		return

	var grain_seed: int = abs(row * 97 + column * 53 + room_index * 131)
	var band_count: int = 11
	for band_index: int in range(band_count):
		var band_seed: int = grain_seed + band_index * 43
		var band_y: float = snappedf(
			top + 8.0 + fmod(float(band_seed * 17), maxf(height - 16.0, 1.0)),
			PIXEL_SIZE
		)
		var start_x: float = snappedf(
			left + 8.0 + fmod(float(band_seed * 29), maxf(width * 0.34, 1.0)),
			PIXEL_SIZE
		)
		var band_length: float = snappedf(
			52.0 + fmod(float(band_seed * 31), maxf(width * 0.62, 56.0)),
			PIXEL_SIZE
		)
		var end_x: float = minf(start_x + band_length, right - 8.0)
		var color: Color = GRAIN_COLORS[posmod(band_seed, GRAIN_COLORS.size())]
		_draw_stepped_band(start_x, end_x, band_y, band_seed, color)

		# Shorter companion bands fill the empty pockets without becoming noise.
		if band_index % 2 == 0:
			var companion_x: float = snappedf(
				left + 8.0 + fmod(float(band_seed * 47), maxf(width * 0.72, 1.0)),
				PIXEL_SIZE
			)
			var companion_end: float = minf(
				companion_x + 28.0 + float(band_seed % 8) * PIXEL_SIZE,
				right - 8.0
			)
			_draw_stepped_band(
				companion_x,
				companion_end,
				band_y + PIXEL_SIZE * 2.0,
				band_seed + 17,
				GRAIN_COLORS[posmod(band_seed + 1, GRAIN_COLORS.size())]
			)


func _draw_stepped_band(
	start_x: float,
	end_x: float,
	y: float,
	band_seed: int,
	color: Color
) -> void:
	var cursor: float = start_x
	var step_index: int = 0
	while cursor < end_x:
		var segment_width: float = minf(
			24.0 + float(posmod(band_seed + step_index * 13, 9)) * PIXEL_SIZE,
			end_x - cursor
		)
		if segment_width < PIXEL_SIZE:
			break
		var vertical_step: float = float(posmod(band_seed + step_index * 7, 3) - 1)
		draw_rect(
			Rect2(
				Vector2(cursor, y + vertical_step * PIXEL_SIZE),
				Vector2(segment_width, PIXEL_SIZE)
			),
			color
		)
		cursor += segment_width
		step_index += 1


func _snap_to_pixel(point: Vector2) -> Vector2:
	return Vector2(
		snappedf(point.x, PIXEL_SIZE),
		snappedf(point.y, PIXEL_SIZE)
	)
