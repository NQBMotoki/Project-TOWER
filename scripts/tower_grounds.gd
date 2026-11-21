extends Node2D

const BOUNDS := Rect2(112, 124, 1056, 472)
var high_quality := true
var clock := 0.0

func pickups() -> Dictionary:
	return {
		"START_SWORD": $StarterSword.position, "START_STAFF": $StarterStaff.position,
		"MUSHROOM": $Mushroom.position, "WATER": $Water.position,
		"LORE_KIT": $KitList.position, "LORE_ORDER": $GarrisonOrder.position,
	}

func _process(delta: float) -> void:
	if visible and high_quality:
		clock += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(BOUNDS.grow(8), Color("4c5346"))
	draw_rect(BOUNDS, Color("293e38"))
	var path := PackedVector2Array([
		Vector2(585, 124), Vector2(699, 124), Vector2(682, 305), Vector2(742, 426),
		Vector2(698, 596), Vector2(583, 596), Vector2(620, 433), Vector2(568, 312),
	])
	draw_colored_polygon(path, Color("57554a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(578, 308), Vector2(634, 354), Vector2(351, 443), Vector2(235, 418), Vector2(267, 373),
	]), Color("504e40"))
	for i in range(150):
		var p := BOUNDS.position + Vector2(12 + (i * 227) % 1032, 8 + (i * 109) % 453)
		var earth := Geometry2D.is_point_in_polygon(p, path)
		draw_line(p, p + Vector2(4 + i % 7, -3), Color("6b6755") if earth else Color("405748"), 1.0)
	for i in range(10):
		var p := Vector2(129 + i * 111, 570 + i % 3 * 5)
		draw_circle(p, 10 + i % 3, Color("25332d"))
		draw_rect(Rect2(p + Vector2(-8, -8), Vector2(13, 9)), Color("405147"))
	_draw_gate()
	_draw_camp()
	if high_quality:
		for i in range(15):
			var p := BOUNDS.position + Vector2(35 + fposmod(i * 197.0 + clock * 5.0, 989.0),
				34 + fposmod(i * 83.0 - clock * 9.0, 395.0))
			draw_circle(p, 1.5, Color(0.82, 0.85, 0.55, 0.20 + 0.12 * sin(clock * 2.0 + i)))

func _draw_gate() -> void:
	draw_rect(Rect2(512, 124, 256, 47), Color("383b3a"))
	for row in range(2):
		for col in range(6):
			draw_rect(Rect2(515 + col * 42, 126 + row * 21, 38, 17), Color("64645a"))
	draw_rect(Rect2(586, 124, 108, 59), Color("7e7460"))
	draw_rect(Rect2(600, 124, 80, 64), Color("171c22"))
	draw_rect(Rect2(603, 177, 74, 12), Color("48433c"))
	draw_rect(Rect2(593, 190, 94, 7), Color("635d50"))
	draw_rect(Rect2(591, 199, 98, 4), Color("77705c"))
	for x in [568, 712]:
		var light := Vector2(x, 154)
		if high_quality:
			draw_circle(light, 31, Color(1.0, 0.72, 0.39, 0.07 + 0.02 * sin(clock * 6.0)))
			draw_circle(light, 19, Color(1.0, 0.61, 0.28, 0.09))
		draw_rect(Rect2(light - Vector2(3, 6), Vector2(6, 12)), Color("dca45e"))

func _draw_camp() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(214, 384), Vector2(259, 318), Vector2(313, 332), Vector2(286, 388),
	]), Color("a18e63"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(259, 318), Vector2(286, 388), Vector2(313, 332),
	]), Color("72684e"))
	draw_line(Vector2(223, 392), Vector2(258, 318), Color("d2bd84"), 2.0)
	draw_rect(Rect2(353, 338, 52, 20), Color("6c5240"))
	draw_rect(Rect2(353, 337, 52, 4), Color("9a7755"))
	var fire := Vector2(344, 393)
	if high_quality:
		draw_circle(fire, 41, Color(1.0, 0.57, 0.24, 0.11 + 0.025 * sin(clock * 8.0)))
	draw_circle(fire, 15, Color("7c7764"))
	draw_circle(fire, 10, Color("382e29"))
	draw_colored_polygon(PackedVector2Array([
		fire + Vector2(-6, 4), fire + Vector2(-4, -4), fire + Vector2(2, -14),
		fire + Vector2(7, 0), fire + Vector2(4, 5),
	]), Color("ef9d5f"))
