extends Node2D

const UpgradeArt = preload("res://data/upgrade_art.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const DURATION := 0.46
var remaining := DURATION
var kind := ""
var direction := "s"
var body_scale := 1.0
var tint := Color(0.92, 0.78, 0.47)

func _process(delta: float) -> void:
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := 1.0 - remaining / DURATION
	var index := ActorMotion.frame_index(progress, UpgradeArt.frame_count(kind, direction, "dissolve"))
	var frame := UpgradeArt.frame(kind, direction, "dissolve", index)
	if frame != null:
		var size := Vector2(frame.get_size()) * body_scale
		draw_texture_rect(frame, Rect2(-UpgradeArt.FOOT * body_scale, size), false)
		return
	for i in range(8):
		var offset := Vector2.from_angle(TAU * i / 8.0) * (8.0 + progress * 25.0)
		draw_rect(Rect2(offset - Vector2(3, 3), Vector2(6, 6) * (1.0 - progress * 0.6)), Color(tint.r, tint.g, tint.b, 1.0 - progress))
