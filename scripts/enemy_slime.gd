extends "res://scripts/enemy_base.gd"

# Creep -> coil -> lunge -> recover. Only the recovery phase cannot hurt the player.
const CONTACT_RANGE := 24.0
const PHASE_CREEP := 0
const PHASE_COIL := 1
const PHASE_LUNGE := 2
const PHASE_RECOVER := 3

var phase := PHASE_CREEP
var phase_timer := 0.0
var lunge_timer := 0.0
var lunge_dir := Vector2.RIGHT
var creep_speed := 38.0
var lunge_range := 150.0
var coil_time := 0.75
var lunge_speed := 400.0
var lunge_time := 0.2
var recover_time := 0.55
var lunge_cooldown := 1.6
var clock := 0.0

func _ready() -> void:
	super._ready()
	creep_speed = float(config.get("creep_speed", creep_speed))
	lunge_range = float(config.get("lunge_range", lunge_range))
	coil_time = float(config.get("coil_time", coil_time))
	lunge_speed = float(config.get("lunge_speed", lunge_speed))
	lunge_time = float(config.get("lunge_time", lunge_time))
	recover_time = float(config.get("recover", recover_time))
	lunge_cooldown = float(config.get("lunge_cooldown", lunge_cooldown))

func _behavior(delta: float) -> void:
	clock += delta
	lunge_timer = maxf(0.0, lunge_timer - delta)
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if phase == PHASE_RECOVER:
		body_scale = Vector2(1.30, 0.60)
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_CREEP
			lunge_timer = lunge_cooldown
		return
	if spawn_delay <= 0.0 and attack_timer <= 0.0 and distance <= CONTACT_RANGE:
		player.take_damage(damage)
		attack_timer = cooldown
	if phase == PHASE_CREEP:
		var breath := sin(clock * 5.0) * 0.05
		body_scale = Vector2(1.0 + breath, 1.0 - breath)
		if distance > CONTACT_RANGE * 0.7:
			position += to_player.normalized() * creep_speed * delta
		if spawn_delay <= 0.0 and lunge_timer <= 0.0 and distance > CONTACT_RANGE and distance <= lunge_range:
			lunge_dir = to_player.normalized()
			phase = PHASE_COIL
			phase_timer = coil_time
	elif phase == PHASE_COIL:
		body_scale = Vector2(1.25, 0.72)
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_LUNGE
			phase_timer = lunge_time
	elif phase == PHASE_LUNGE:
		body_scale = Vector2(0.82, 1.22)
		position += lunge_dir * lunge_speed * delta
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_RECOVER
			phase_timer = recover_time

func _draw() -> void:
	super._draw()
	if phase == PHASE_COIL:
		var progress := 1.0 - phase_timer / maxf(0.01, coil_time)
		var alpha := lerpf(0.06, 0.30, progress)
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(9):
			var angle := lunge_dir.angle() - 0.42 + 0.84 * float(i) / 8.0
			points.append(Vector2.from_angle(angle) * lunge_range)
		draw_colored_polygon(points, Color(0.55, 0.95, 0.65, alpha))
		draw_arc(Vector2.ZERO, 10.0 + 6.0 * progress, 0.0, TAU, 18, Color(0.62, 0.95, 0.70, 0.30 + 0.45 * progress), 2.0)
