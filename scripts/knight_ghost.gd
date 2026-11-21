extends Node2D

const DURATION := 3.8
var targets: Array[Vector2] = []
var elapsed := 0.0
var gather := 0.0
var fade := 1.0
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	show_at(0.0)

func show_at(time: float) -> void:
	elapsed = time
	gather = smoothstep(0.0, 0.95, elapsed)
	fade = 1.0 - smoothstep(2.9, DURATION, elapsed)
	sprite.modulate.a = gather * fade
	queue_redraw()

func _draw() -> void:
	for i in range(26):
		var angle := i * TAU / 26.0 + elapsed * 0.7
		var radius := lerpf(58.0 + (i % 6) * 7.0, 10.0 + i % 7, gather * fade)
		draw_circle(Vector2.from_angle(angle) * radius + Vector2(0, -10), 1.0 + i % 3,
			Color(0.36, 0.77, 1.0, fade * (0.25 + 0.32 * (1.0 - gather * fade))))
	var opacity := gather * fade
	var hand := Vector2(14, -13)
	for i in range(targets.size()):
		var start := 1.0 + float(i) * 0.88
		var gesture := smoothstep(start, start + 0.27, elapsed)
		if gesture <= 0.0:
			continue
		var direction := (targets[i] - global_position).normalized()
		hand = Vector2(0, -12) + direction * (14.0 + gesture * 28.0)
		var end := targets[i] - global_position
		var tip := end - direction * 23.0
		draw_dashed_line(direction * 50.0, tip, Color(0.50, 0.83, 1.0, opacity * gesture * 0.5), 2.0, 7.0)
		draw_polyline(PackedVector2Array([
			tip - direction * 9.0 + direction.orthogonal() * 5.0, tip,
			tip - direction * 9.0 - direction.orthogonal() * 5.0,
		]), Color(0.64, 0.89, 1.0, opacity * gesture), 2.0, true)
	if sprite.texture != null:
		return
	draw_circle(Vector2(0, -10), 32.0, Color(0.22, 0.66, 1.0, opacity * 0.17))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-15, -16), Vector2(15, -16), Vector2(18, 10), Vector2(11, 26), Vector2(-17, 18),
	]), Color(0.29, 0.58, 0.83, opacity * 0.86))
	draw_rect(Rect2(-12, -34, 24, 18), Color(0.64, 0.85, 1.0, opacity))
	draw_rect(Rect2(-10, -27, 20, 4), Color(0.16, 0.38, 0.63, opacity))
	draw_rect(Rect2(-3, -31, 6, 13), Color(0.34, 0.69, 0.91, opacity))
	draw_line(Vector2(0, -12), hand, Color(0.64, 0.85, 1.0, opacity), 6.0, true)
	draw_circle(hand, 4.0, Color(0.80, 0.94, 1.0, opacity))
