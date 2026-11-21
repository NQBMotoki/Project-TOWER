extends Node2D

var floor_number := 1
var layout := ArenaLayout.new()
var high_quality := true
var clock := 0.0

func _process(delta: float) -> void:
	if visible and high_quality:
		clock += delta
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
		if high_quality:
			draw_circle(p, 32, Color(0.95, 0.64, 0.30, 0.05 + sin(clock * 5.0 + p.x) * 0.01))
			draw_circle(p, 18, Color(0.95, 0.64, 0.30, 0.08))
		draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color("e3ac63"))
	if high_quality:
		for i in range(13):
			var p := Vector2(138.0 + fposmod(i * 153.0 + clock * 7.0, 1004.0),
				146.0 + fposmod(i * 107.0 - clock * 5.0, 426.0))
			draw_circle(p, 1.2, Color(0.95, 0.79, 0.61, 0.22 + 0.08 * sin(clock * 2.0 + i)))
	for entry in layout.obstacles:
		_draw_obstacle(entry.rect, entry.kind == "pillar")

func _draw_obstacle(rect: Rect2, pillar: bool) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0.08, 0.07, 0.09, 0.56))
	draw_rect(rect, Color("23252a"))
	draw_rect(rect.grow(-2), Color("777264") if pillar else Color("6f6861"))
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 9)), Color("9b9080"))
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 8), Vector2(rect.size.x - 4, 6)), Color("504c48"))
	if pillar:
		draw_rect(rect.grow(-9), Color("8b8173"))
		draw_rect(rect.grow(-9), Color("605d55"), false, 2.0)
	else:
		for offset in [0.26, 0.61, 0.85]:
			var x: float = rect.position.x + rect.size.x * offset
			draw_line(Vector2(x + 3, rect.position.y + 5), Vector2(x - 5, rect.end.y - 6), Color("4d4947"), 2.0)
