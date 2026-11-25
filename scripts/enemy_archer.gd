extends "res://scripts/enemy_base.gd"

# Archers keep their distance, then lock a separate aim guide for each shot.
# Close targets get a blade swing after the bow has recovered.
var draw_time := 0.8
var draw_timer := 0.0
var current_draw_duration := 0.8
var shots_left := 1
var aim_dir := Vector2.RIGHT
var band_min := 240.0
var band_max := 360.0
var backpedal := 1.15
var reach := 640.0

var melee_range := 70.0
var melee_reach := 100.0
var melee_windup_time := 0.7
var melee_half_angle := deg_to_rad(35.0)
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
	melee_half_angle = float(config.get("melee_arc", melee_half_angle))
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
	if distance <= melee_range and sees_player():
		# The bow's recovery leaves the player a chance to close in safely.
		if melee_timer <= 0.0 and attack_timer <= 0.0 and can_begin_attack():
			melee_windup = melee_windup_time
			melee_dir = aim_at_player()
			sound_requested.emit("archer_melee_warn")
		return
	if not sees_player(ArenaLayout.PROJECTILE_RADIUS):
		move_to_sight((band_min + band_max) * 0.5, speed * delta)
		return
	if distance < band_min:
		var step := -direction * speed * backpedal * delta
		if layout.is_walkable(global_position + step, hit_radius):
			move_by(step)
		else:
			move_to_sight((band_min + band_max) * 0.5, speed * delta)
	elif distance > band_max:
		move_towards(player.global_position, speed * delta)
	if attack_timer <= 0.0 and can_begin_attack() and distance >= band_min and distance < reach:
		shots_left = config.burst_shots
		_begin_draw(draw_time)

func _begin_draw(duration: float) -> void:
	_attack_art = "volley" if kind == "corrupted_archer" else ""
	current_draw_duration = duration
	draw_timer = duration
	aim_dir = aim_at_player()
	sound_requested.emit("archer_draw")

func _release() -> void:
	show_attack_release()
	projectile_requested.emit(global_position, aim_dir, damage)
	sound_requested.emit("archer_release")
	shots_left -= 1
	if shots_left > 0:
		_begin_draw(config.burst_draw)
	else:
		attack_timer = cooldown

func _melee_strike() -> void:
	_attack_art = "melee"
	show_attack_release()
	melee_timer = melee_cooldown
	attack_timer = maxf(attack_timer, 0.40)
	if target_in_sector(melee_dir, melee_reach, melee_half_angle):
		player.take_damage(melee_damage, "enemy")
	sound_requested.emit("archer_melee")

func holding_attack_slot() -> bool:
	return draw_timer > 0.0 or melee_windup > 0.0

func _prepare_action_pose() -> void:
	if melee_windup > 0.0:
		_attack_art = "melee"
		set_action_pose(ActorMotion.Phase.WINDUP, melee_windup, melee_windup_time)
	elif draw_timer > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, draw_timer, current_draw_duration)

func _draw_warning() -> void:
	super._draw_warning()
	if melee_windup > 0.0:
		draw_sector(melee_dir, melee_reach, melee_half_angle,
			1.0 - melee_windup / melee_windup_time, Color("ff9a71"))
		return
	if draw_timer <= 0.0:
		return
	var progress := 1.0 - draw_timer / current_draw_duration
	var alpha := lerpf(0.47, 0.94, progress)
	var color := Color(1.0, 0.76, 0.40, alpha)
	var extent := clear_reach(aim_dir, reach, ArenaLayout.PROJECTILE_RADIUS)
	_warning.draw_dashed_line(Vector2.ZERO, aim_dir * extent, color, 2.3, 12.0)
	_warning.draw_line(aim_dir * minf(20.0, extent), aim_dir * minf(34.0, extent), Color(0.98, 0.93, 0.82, alpha), 3.0)
	_warning.draw_arc(Vector2.ZERO, 22.0 + 6.0 * progress, 0.0, TAU, 24, Color(color, alpha * 0.75), 2.0)
	for i in range(shots_left):
		_warning.draw_rect(Rect2((i - (shots_left - 1) * 0.5) * 7.0 - 2.0, 23.0, 4.0, 4.0), color)
