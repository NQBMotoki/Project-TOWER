extends Node2D

var remaining := 0.32
var tint := Color(0.92, 0.78, 0.47)

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := 1.0 - remaining / 0.32
	for i in range(8):
		var offset := Vector2.from_angle(TAU * i / 8.0) * (8.0 + progress * 25.0)
		draw_rect(Rect2(offset - Vector2(3, 3), Vector2(6, 6) * (1.0 - progress * 0.6)), Color(tint.r, tint.g, tint.b, 1.0 - progress))
