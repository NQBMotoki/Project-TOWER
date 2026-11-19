extends Node2D

var floor_number := 1
var lore_active := false
var lore_position := Vector2.ZERO
var clock := 0.0

func _process(delta: float) -> void:
	clock += delta
	if lore_active:
		queue_redraw()

func _draw() -> void:
	var colors := [Color("303a40"), Color("39393a"), Color("34364a"), Color("403338"), Color("342e3d")]
	var base: Color = colors[clampi(floor_number - 1, 0, 4)]
	draw_rect(Rect2(0, 0, 1280, 720), Color("151b22"))
	draw_rect(Rect2(94, 106, 1092, 508), Color("161a20"))
	draw_rect(Rect2(100, 112, 1080, 496), Color("65594c"))
	draw_rect(Rect2(108, 120, 1064, 480), Color("252930"))
	draw_rect(Rect2(112, 124, 1056, 472), base)
	for row in range(12):
		for col in range(27):
			var x := 112.0 + col * 40.0
			var y := 124.0 + row * 40.0
			var w := minf(39.0, 1168.0 - x)
			var h := minf(39.0, 596.0 - y)
			if w <= 0.0 or h <= 0.0:
				continue
			var variation := float((row * 19 + col * 13) % 7) * 0.008
			draw_rect(Rect2(x + 1, y + 1, w - 1, h - 1), base.lightened(variation))
			if (row * 11 + col * 17) % 19 == 0:
				draw_line(Vector2(x + 9, y + 12), Vector2(x + 18, y + 12), base.darkened(0.16), 1.0)
	for x in [180.0, 420.0, 660.0, 900.0, 1100.0]:
		draw_rect(Rect2(x, 109, 36, 12), Color("81705a"))
		draw_rect(Rect2(x, 596, 36, 12), Color("51493f"))
	for p in [Vector2(145, 152), Vector2(1135, 152), Vector2(145, 567), Vector2(1135, 567)]:
		draw_circle(p, 18, Color(0.95, 0.64, 0.30, 0.05))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("e3ac63"))
	if lore_active:
		var p := lore_position
		var glow := 0.13 + 0.04 * sin(clock * 3.0)
		draw_circle(p, 28, Color(0.95, 0.81, 0.52, glow))
		draw_rect(Rect2(p + Vector2(-12, -8), Vector2(24, 18)), Color("b49770"))
		draw_rect(Rect2(p + Vector2(-10, -11), Vector2(20, 16)), Color("e9d6ae"))
		draw_line(p + Vector2(-7, -6), p + Vector2(6, -6), Color("9b8165"), 1.0)
		draw_line(p + Vector2(-7, -2), p + Vector2(4, -2), Color("9b8165"), 1.0)
