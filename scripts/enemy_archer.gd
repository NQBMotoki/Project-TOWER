extends "res://scripts/enemy_base.gd"

# Keeps its distance, draws for 0.8 s, then releases a fast arrow.
# Sprinting away does not work: the arrow is roughly three times the player's speed.
# `reach` is both the firing gate and the length of the aim guide.
var draw_time := 0.8
var draw_timer := 0.0
var aim_dir := Vector2.RIGHT
var band_min := 240.0
var band_max := 360.0
var backpedal := 1.15
var reach := 640.0

func _ready() -> void:
	super._ready()
	draw_time = float(config.get("draw", draw_time))
	band_min = float(config.get("band_min", band_min))
	band_max = float(config.get("band_max", band_max))
	backpedal = float(config.get("backpedal", backpedal))
	shot_speed = float(config.get("shot_speed", 560.0))
	reach = float(config.get("reach", reach))

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 1.0 else Vector2.RIGHT
	if draw_timer > 0.0:
		draw_timer -= delta
		if draw_timer <= 0.0:
			_release()
		return
	if distance < band_min:
		position -= direction * speed * backpedal * delta
	elif distance > band_max:
		position += direction * speed * delta
	if spawn_delay <= 0.0 and attack_timer <= 0.0 and distance >= band_min and distance < reach:
		draw_timer = draw_time
		aim_dir = direction
		sound_requested.emit("enemy_chant")

func _release() -> void:
	attack_timer = cooldown
	projectile_requested.emit(global_position + aim_dir * 18.0, aim_dir, damage)
	sound_requested.emit("enemy_arrow")

func _draw() -> void:
	super._draw()
	if draw_timer <= 0.0:
		return
	var progress := 1.0 - draw_timer / maxf(0.01, draw_time)
	var alpha := lerpf(0.15, 0.85, progress)
	var color := Color(1.0, 0.72, 0.35, alpha)
	draw_dashed_line(Vector2.ZERO, aim_dir * reach, color, 2.0, 12.0)
	draw_line(aim_dir * 20.0, aim_dir * 34.0, Color(0.98, 0.93, 0.82, alpha), 3.0)
	draw_arc(Vector2.ZERO, 22.0 + 6.0 * progress, 0.0, TAU, 16, Color(color.r, color.g, color.b, alpha * 0.5), 2.0)
