extends "res://scripts/enemy_base.gd"

# Creep -> coil -> lunge -> recover. Damage is confined to the warned lunge.
const PHASE_CREEP := 0
const PHASE_COIL := 1
const PHASE_LUNGE := 2
const PHASE_RECOVER := 3

var phase := PHASE_CREEP
var phase_timer := 0.0
var lunge_timer := 0.0
var lunge_dir := Vector2.RIGHT
var creep_speed := 38.0
var lunge_reach := 104.0
var coil_time := 0.75
var lunge_speed := 400.0
var lunge_time := 0.2
var recover_time := 0.55
var lunge_cooldown := 1.6
var clock := 0.0
var contact_range := 24.0
var lunge_origin := Vector2.ZERO

func _ready() -> void:
	super._ready()
	creep_speed = float(config.get("creep_speed", creep_speed))
	coil_time = float(config.get("coil_time", coil_time))
	lunge_speed = float(config.get("lunge_speed", lunge_speed))
	lunge_time = float(config.get("lunge_time", lunge_time))
	recover_time = float(config.get("recover", recover_time))
	lunge_cooldown = float(config.get("lunge_cooldown", lunge_cooldown))
	# The coil trigger and the drawn path both use the distance the lunge can
	# really cover, so the warning never promises a hit the lunge cannot land.
	contact_range = float(config.get("contact_range", contact_range))
	lunge_reach = lunge_speed * lunge_time + contact_range

func _behavior(delta: float) -> void:
	clock += delta
	lunge_timer = maxf(0.0, lunge_timer - delta)
	var distance := global_position.distance_to(player.global_position)
	if phase == PHASE_RECOVER:
		body_scale = Vector2(1.30, 0.60)
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_CREEP
			lunge_timer = lunge_cooldown
		return
	if phase == PHASE_CREEP:
		var breath := sin(clock * 5.0) * 0.05
		body_scale = Vector2(1.0 + breath, 1.0 - breath)
		if lunge_timer <= 0.0 and distance <= lunge_reach and sees_player():
			lunge_dir = aim_at_player()
			phase = PHASE_COIL
			phase_timer = coil_time
			sound_requested.emit("enemy_telegraph")
		elif distance > contact_range * 0.7 or not sees_player():
			move_towards(player.global_position, creep_speed * delta)
	elif phase == PHASE_COIL:
		body_scale = Vector2(1.25, 0.72)
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_LUNGE
			phase_timer = lunge_time
			lunge_origin = global_position
			sound_requested.emit("enemy_rush")
	elif phase == PHASE_LUNGE:
		body_scale = Vector2(0.82, 1.22)
		var previous := global_position
		move_straight(lunge_dir, lunge_speed * minf(delta, phase_timer))
		_check_lunge_hit(previous)
		phase_timer -= delta
		if phase_timer <= 0.0:
			phase = PHASE_RECOVER
			phase_timer = recover_time
			if config.has("trail_radius"):
				add_hazard(lunge_origin, global_position, config.trail_radius, 0.0, config.trail_time, config.trail_damage)
				sound_requested.emit("enemy_zone_burst")

func _check_lunge_hit(previous: Vector2) -> void:
	if attack_timer > 0.0:
		return
	var closest := global_position
	if not previous.is_equal_approx(global_position):
		closest = Geometry2D.get_closest_point_to_segment(player.global_position, previous, global_position)
	if closest.distance_to(player.global_position) <= contact_range and layout.has_clear_line(closest, player.global_position):
		player.take_damage(damage)
		attack_timer = cooldown

func _prepare_action_pose() -> void:
	match phase:
		PHASE_COIL:
			set_action_pose(ActorMotion.Phase.WINDUP, phase_timer, coil_time)
		PHASE_LUNGE:
			set_action_pose(ActorMotion.Phase.STRIKE, phase_timer, lunge_time)
		PHASE_RECOVER:
			set_action_pose(ActorMotion.Phase.RECOVERY, phase_timer, recover_time)

func _draw() -> void:
	super._draw()
	if phase != PHASE_COIL:
		return
	var progress := 1.0 - phase_timer / maxf(0.01, coil_time)
	var travel := clear_reach(lunge_dir, lunge_reach - contact_range, hit_radius)
	var endpoint := lunge_dir * travel
	var color := Color("abf39a") if config.has("trail_radius") else Color("dcf89d")
	draw_line(Vector2.ZERO, endpoint, Color(color, 0.12 + 0.18 * progress), contact_range * 2.0)
	draw_circle(Vector2.ZERO, contact_range, Color(color, 0.12 + 0.18 * progress))
	draw_circle(endpoint, contact_range, Color(color, 0.12 + 0.18 * progress))
	draw_arc(endpoint, contact_range, 0.0, TAU, 22, Color(color, 0.46 + 0.44 * progress), 2.0)
	draw_line(lunge_dir * 14.0, endpoint, Color(color, 0.53 + 0.42 * progress), 2.0)
	draw_arc(Vector2.ZERO, 10.0 + 6.0 * progress, 0.0, TAU, 18, Color(color, 0.56 + 0.44 * progress), 2.0)
