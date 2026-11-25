extends "res://scripts/enemy_base.gd"

var telegraph := 0.0
var telegraph_time := 0.55
var aim_dir := Vector2.RIGHT
var reach := 510.0
var prefers_zone := true
var zone_time := 0.0
var reposition_time := 0.0
var reposition_dir := Vector2.ZERO
var side := 1.0

func _ready() -> void:
	super._ready()
	telegraph_time = config.telegraph
	reach = config.reach

func _behavior(delta: float) -> void:
	if zone_time > 0.0:
		zone_time -= delta
		if zone_time <= 0.0:
			show_attack_release()
			attack_timer = cooldown
		return
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			_fire()
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if reposition_time > 0.0:
		reposition_time -= delta
		move_by(reposition_dir * speed * delta)
		return
	if not sees_player(ArenaLayout.PROJECTILE_RADIUS):
		move_to_sight((config.band_min + config.band_max) * 0.5, speed * delta)
		return
	if attack_timer <= 0.0 and can_begin_attack() and prefers_zone and config.has("zone_reach") and distance < config.zone_reach:
		_attack_art = "zone"
		aim_at_player()
		zone_time = config.zone_delay
		add_hazard(player.global_position, player.global_position, config.zone_radius,
			zone_time, 0.26, config.zone_damage)
		prefers_zone = false
		sound_requested.emit("skeleton_zone_warn")
		return
	if attack_timer <= 0.0 and can_begin_attack() and distance < reach:
		aim_dir = aim_at_player()
		_attack_art = ""
		telegraph = telegraph_time
		sound_requested.emit("skeleton_chant")
	elif distance < config.band_min:
		move_by(-to_player.normalized() * speed * delta)
	elif distance > config.band_max:
		move_towards(player.global_position, speed * delta)

func _fire() -> void:
	attack_timer = cooldown
	prefers_zone = true
	fire_fan(aim_dir, config.shots, config.get("spread", 0.0))
	side = -side
	reposition_dir = aim_dir.orthogonal() * side
	reposition_time = 0.40

func holding_attack_slot() -> bool:
	return telegraph > 0.0 or zone_time > 0.0

func _prepare_action_pose() -> void:
	if telegraph > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, telegraph, telegraph_time)
	elif zone_time > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, zone_time, config.zone_delay)

func _draw_warning() -> void:
	super._draw_warning()
	if telegraph <= 0.0:
		return
	var progress := 1.0 - telegraph / telegraph_time
	var shots: int = config.shots
	var spread: float = config.get("spread", 0.0)
	if shots > 1:
		var half_angle := (shots - 1) * spread * 0.5 + 0.04
		draw_sector(aim_dir, reach, half_angle, progress, Color("e36f60"))
	draw_magic_guides(aim_dir, reach, shots, spread, progress)
