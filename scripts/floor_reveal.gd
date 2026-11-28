extends Node2D

const UpgradeArt = preload("res://data/upgrade_art.gd")
const MAP_RECT := Rect2(-254, -288, 508, 576)
const CUTAWAY_CROP := Rect2(155, 0, 330, 360)
const CAMP_MARKER := Vector2(318, 337) / Vector2(640, 360)

var reveal := 0.0
var destination := -1
var travel := 0.0

func show_at(progress: float, target_floor := -1, marker_progress := 0.0) -> void:
	reveal = progress
	destination = target_floor
	travel = marker_progress
	queue_redraw()

func _draw() -> void:
	if destination < 0:
		var gold := Color(0.66, 0.51, 0.32, reveal * 0.85)
		draw_line(Vector2(-190 * reveal, 0), Vector2(190 * reveal, 0), gold, 2)
		return
	var map := UpgradeArt.prop("tower_cutaway")
	if map == null:
		return
	draw_texture_rect_region(map, MAP_RECT, CUTAWAY_CROP, Color(1.0, 1.0, 1.0, reveal))
	var start := CAMP_MARKER if destination == 1 else UpgradeArt.floor_marker(destination - 1)
	var marker := start.lerp(UpgradeArt.floor_marker(destination), travel)
	var source := marker * map.get_size()
	var lamp := MAP_RECT.position + (source - CUTAWAY_CROP.position) / CUTAWAY_CROP.size * MAP_RECT.size
	for radius in [16.0, 10.0, 6.0]:
		draw_circle(lamp, radius, Color(1.0, 0.58, 0.24, reveal * 0.13))
	draw_rect(Rect2(lamp - Vector2(2, 4), Vector2(4, 7)), Color(1.0, 0.84, 0.49, reveal))
