extends Node2D

const Art = preload("res://data/upgrade_art.gd")
const Cinematics = preload("res://scripts/run_cinematics.gd")

var stair_time := -1.0
var chest := Vector2.ZERO
var first_charge := false
var reduced := false
var ending := -1.0
var skyline: Texture2D
var clouds: Texture2D
var energy_atlas: Texture2D

func _ready() -> void:
	skyline = Art.prop("summit_skyline")
	clouds = Art.prop("summit_clouds")
	energy_atlas = Art.prop("boon_energy")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func show_stairs(time: float, player_anchor: Vector2, first: bool, low_motion: bool) -> void:
	ending = -1.0
	stair_time = time
	chest = player_anchor
	first_charge = first
	reduced = low_motion
	queue_redraw()

func show_ending(time: float, crystal_anchor: Vector2, low_motion: bool) -> void:
	stair_time = -1.0
	ending = time
	chest = crystal_anchor
	reduced = low_motion
	queue_redraw()

func clear() -> void:
	stair_time = -1.0
	ending = -1.0
	queue_redraw()

func _draw() -> void:
	if ending >= Cinematics.SKY_TIME:
		_draw_sky()
	elif ending >= Cinematics.TOUCH_TIME:
		_draw_tremor()
	elif stair_time >= 0.0:
		_draw_charge()

func _draw_charge() -> void:
	var start := 0.70 if first_charge else 0.09
	var finish := 0.95 if first_charge else 0.37
	var flight := inverse_lerp(start, finish, stair_time)
	if flight < 0.0:
		return
	var violet := Color("c58be4")
	if flight <= 1.0 and not reduced:
		var points := PackedVector2Array()
		for i in range(10):
			var t := clampf(flight - float(i) * 0.043, 0.0, 1.0)
			var point := chest + Vector2(-24.0 * sin(t * PI), -101.0 * (1.0 - t))
			points.append(point)
		draw_polyline(points, Color(violet, 0.36), 7.0, true)
		draw_polyline(points, Color("e1b9f2"), 2.0, true)
		if energy_atlas != null:
			var frame := clampi(int(flight * 8), 0, 7)
			draw_texture_rect_region(energy_atlas, Rect2(points[0] - Vector2.ONE * 12, Vector2.ONE * 24),
				Rect2(frame * 24, 0, 24, 24))
		return
	var fade := 1.0 - smoothstep(finish, finish + 0.51, stair_time)
	if fade <= 0.0:
		return
	if energy_atlas != null and flight >= 1.0 and not reduced:
		var frame := clampi(int((1.0 - fade) * 6), 0, 5)
		draw_texture_rect_region(energy_atlas, Rect2(chest - Vector2.ONE * 12, Vector2.ONE * 24),
			Rect2(frame * 24, 24, 24, 24), Color(1, 1, 1, fade))
	for i in range(5 if reduced else 9):
		var heading := Vector2.from_angle(i * TAU / 9.0)
		var point := chest + heading * lerpf(23.0, 2.0, fade)
		draw_rect(Rect2(point, Vector2(2, 3)), Color(violet, fade * 0.73))

func _draw_tremor() -> void:
	var progress := smoothstep(Cinematics.TOUCH_TIME, Cinematics.SKY_TIME, ending)
	var fade := 1.0 - progress
	draw_circle(chest, 80.0 * progress + 5.0, Color(0.58, 0.29, 0.74, 0.12 * fade))
	for i in range(17):
		var drift := Vector2(sin(i * 39.81) * 102.0, cos(i * 59.67) * 64.0)
		var point := chest + drift * (0.3 + progress) + Vector2.DOWN * (progress * 58.0)
		draw_rect(Rect2(point, Vector2(2.0 + i % 4, 2.0)), Color(0.65, 0.54, 0.60, 0.48 * fade))

func _draw_sky() -> void:
	var rect := Rect2(Vector2.ZERO, get_viewport_rect().size)
	var change := smoothstep(Cinematics.SKY_TIME + 0.17, Cinematics.CREDITS_TIME, ending)
	for row in range(14):
		var y := float(row) / 14.0
		var color := Color("494a58").lerp(Color("89817e"), y)
		color = color.lerp(Color("110b1c").lerp(Color("392139"), y), change)
		draw_rect(Rect2(0, rect.size.y * y, rect.size.x, rect.size.y / 14.0 + 1.0), color)
	if clouds != null:
		var shift := (ending - Cinematics.SKY_TIME) * (0.0 if reduced else 17.0)
		for i in [-1, 0, 1]:
			draw_texture_rect(clouds, Rect2(rect.position + Vector2(shift + i * rect.size.x, 0), rect.size),
				false, Color(0.80, 0.78, 0.91).lerp(Color("41314f"), change))
	if skyline != null:
		draw_texture_rect(skyline, rect, false, Color.WHITE.lerp(Color("83718d"), change))
	var fade := smoothstep(Cinematics.CREDITS_TIME - 0.45, Cinematics.CREDITS_TIME + 0.22, ending)
	draw_rect(rect, Color(0.045, 0.036, 0.065, fade))
