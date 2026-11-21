extends Node2D

var reveal := 0.0

func show_at(progress: float) -> void:
	reveal = progress
	$Sprite2D.modulate.a = progress
	queue_redraw()

func _draw() -> void:
	if $Sprite2D.texture != null:
		return
	var gold := Color(0.66, 0.51, 0.32, reveal * 0.85)
	draw_line(Vector2(-190 * reveal, 0), Vector2(190 * reveal, 0), gold, 2)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-5, 0), Vector2(0, -5), Vector2(5, 0), Vector2(0, 5),
	]), gold)
