extends Node2D

const UpgradeArt = preload("res://data/upgrade_art.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const Cinematics = preload("res://scripts/run_cinematics.gd")
const DURATION := Cinematics.KNIGHT_TIME
const FIRST_POINT := 1.05
const SECOND_POINT := 2.55
const FADE_START := 4.10
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
	fade = 1.0 - smoothstep(FADE_START, DURATION, elapsed)
	var phase := "appear"
	var progress := elapsed / FIRST_POINT
	if elapsed >= FADE_START:
		phase = "fade"
		progress = inverse_lerp(FADE_START, DURATION, elapsed)
	elif elapsed >= SECOND_POINT:
		phase = "point_staff"
		progress = minf(1.0, (elapsed - SECOND_POINT) / 0.62)
	elif elapsed >= FIRST_POINT:
		phase = "point_sword"
		progress = minf(1.0, (elapsed - FIRST_POINT) / 0.62)
	var facing := ActorMotion.direction_name(global_position.direction_to(look_target()))
	var index := ActorMotion.frame_index(progress, UpgradeArt.frame_count("knight", facing, phase))
	sprite.texture = UpgradeArt.frame("knight", facing, phase, index)
	sprite.position = Vector2(0, -24)
	sprite.modulate.a = gather * fade
	queue_redraw()

func look_target() -> Vector2:
	if elapsed < FIRST_POINT or elapsed >= FADE_START or targets.is_empty():
		return global_position + Vector2.UP * 16.0
	return targets[mini(1 if elapsed >= SECOND_POINT else 0, targets.size() - 1)]

func _draw() -> void:
	for i in range(26):
		var angle := i * TAU / 26.0 + elapsed * 0.7
		var radius := lerpf(58.0 + (i % 6) * 7.0, 10.0 + i % 7, gather * fade)
		draw_circle(Vector2.from_angle(angle) * radius + Vector2(0, -10), 1.0 + i % 3,
			Color(0.36, 0.77, 1.0, fade * (0.25 + 0.32 * (1.0 - gather * fade))))
	var opacity := gather * fade
	var hand := Vector2(14, -13)
	if elapsed >= FIRST_POINT and elapsed < FADE_START and not targets.is_empty():
		var start := FIRST_POINT if elapsed < SECOND_POINT else SECOND_POINT
		var gesture := smoothstep(start, start + 0.58, elapsed)
		var direction := global_position.direction_to(look_target())
		hand = Vector2(0, -12) + direction * (14.0 + gesture * 28.0)
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
