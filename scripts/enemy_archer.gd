extends "res://scripts/enemy_base.gd"

# Keeps its distance, draws for 0.8 s, then releases a fast arrow.
# Sprinting away does not work: the arrow is roughly three times the player's speed.
# `reach` is both the firing gate and the length of the aim guide.
# When the player gets inside `melee_range` it stops backing off and swings a
# short blade instead, so hugging the archer is a trade rather than a free kill.
var draw_time := 0.8
var draw_timer := 0.0
var aim_dir := Vector2.RIGHT
var band_min := 240.0
var band_max := 360.0
var backpedal := 1.15
var reach := 640.0

var melee_range := 70.0
var melee_reach := 100.0
var melee_windup_time := 0.45
var melee_damage := 9.0
var melee_cooldown := 1.3
var melee_windup := 0.0
var melee_timer := 0.0
var melee_dir := Vector2.RIGHT

func _ready() -> void:
	super._ready()
	draw_time = float(config.get("draw", draw_time))
	band_min = float(config.get("band_min", band_min))
	band_max = float(config.get("band_max", band_max))
	backpedal = float(config.get("backpedal", backpedal))
	shot_speed = float(config.get("shot_speed", 560.0))
	reach = float(config.get("reach", reach))
	melee_range = float(config.get("melee_range", melee_range))
	melee_reach = float(config.get("melee_reach", melee_reach))
	melee_windup_time = float(config.get("melee_windup", melee_windup_time))
	melee_damage = float(config.get("melee_damage", melee_damage))
	melee_cooldown = float(config.get("melee_cooldown", melee_cooldown))

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	var direction := to_player.normalized() if distance > 1.0 else Vector2.RIGHT
	melee_timer = maxf(0.0, melee_timer - delta)
	if melee_windup > 0.0:
		melee_windup -= delta
		if melee_windup <= 0.0:
			_melee_strike()
		return
	if draw_timer > 0.0:
		draw_timer -= delta
		if draw_timer <= 0.0:
			_release()
		return
	if distance <= melee_range:
		# Hold ground here instead of retreating forever. The swing waits for the
		# bow to finish recovering: slashing during that window would take away
		# the opening the Floor 3 tip promises after the string sounds.
		if spawn_delay <= 0.0 and melee_timer <= 0.0 and attack_timer <= 0.0:
			melee_windup = melee_windup_time
			melee_dir = direction
			sound_requested.emit("enemy_chant")
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

func _melee_strike() -> void:
	melee_timer = melee_cooldown
	if spawn_delay > 0.0:
		return
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > melee_reach:
		return
	if to_player.length() > 1.0 and absf(melee_dir.angle_to(to_player)) > deg_to_rad(55.0):
		return
	player.take_damage(melee_damage)

func _draw() -> void:
	super._draw()
	if melee_windup > 0.0:
		# Same shape as the strike: a filled sector drawn at the distance it can hit.
		var t := 1.0 - melee_windup / maxf(0.01, melee_windup_time)
		var melee_alpha := lerpf(0.12, 0.9, t)
		var melee_color := Color(1.0, 0.52, 0.34, melee_alpha)
		var arc := deg_to_rad(55.0)
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(9):
			var a := melee_dir.angle() - arc + 2.0 * arc * float(i) / 8.0
			points.append(Vector2.from_angle(a) * melee_reach)
		draw_colored_polygon(points, Color(1.0, 0.45, 0.30, 0.07 + 0.13 * t))
		draw_arc(Vector2.ZERO, melee_reach, melee_dir.angle() - arc, melee_dir.angle() + arc, 18, melee_color, 3.0)
		draw_line(Vector2.ZERO, melee_dir * melee_reach, Color(melee_color.r, melee_color.g, melee_color.b, melee_alpha * 0.30), 2.0)
		return
	if draw_timer <= 0.0:
		return
	var progress := 1.0 - draw_timer / maxf(0.01, draw_time)
	var alpha := lerpf(0.15, 0.85, progress)
	var color := Color(1.0, 0.72, 0.35, alpha)
	draw_dashed_line(Vector2.ZERO, aim_dir * reach, color, 2.0, 12.0)
	draw_line(aim_dir * 20.0, aim_dir * 34.0, Color(0.98, 0.93, 0.82, alpha), 3.0)
	draw_arc(Vector2.ZERO, 22.0 + 6.0 * progress, 0.0, TAU, 16, Color(color.r, color.g, color.b, alpha * 0.5), 2.0)
