extends "res://scripts/enemy_base.gd"

var telegraph := 0.0
var telegraph_time := 0.55
var aim_dir := Vector2.RIGHT
var reach := 510.0
var prefers_zone := true

func _ready() -> void:
	super._ready()
	telegraph_time = config.telegraph
	reach = config.reach

func _behavior(delta: float) -> void:
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			_fire()
		return
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if attack_timer <= 0.0 and prefers_zone and config.has("zone_reach") and distance < config.zone_reach:
		show_attack_release()
		add_hazard(player.global_position, player.global_position, config.zone_radius,
			config.zone_delay, 0.24, config.zone_damage)
		prefers_zone = false
		attack_timer = cooldown
		sound_requested.emit("enemy_zone_warning")
		return
	if not sees_player(ArenaLayout.PROJECTILE_RADIUS):
		move_to_sight((config.band_min + config.band_max) * 0.5, speed * delta)
		return
	if attack_timer <= 0.0 and distance < reach:
		aim_dir = aim_at_player()
		telegraph = telegraph_time
		sound_requested.emit("enemy_chant")
	elif distance < config.band_min:
		move_by(-to_player.normalized() * speed * delta)
	elif distance > config.band_max:
		move_towards(player.global_position, speed * delta)

func _fire() -> void:
	attack_timer = cooldown
	prefers_zone = true
	fire_fan(aim_dir, config.shots, config.get("spread", 0.0))

func _prepare_action_pose() -> void:
	if telegraph > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, telegraph, telegraph_time)

func _draw() -> void:
	super._draw()
	if telegraph <= 0.0:
		return
	var progress := 1.0 - telegraph / telegraph_time
	var shots: int = config.shots
	var spread: float = config.get("spread", 0.0)
	if shots > 1:
		var half_angle := (shots - 1) * spread * 0.5 + 0.04
		draw_sector(aim_dir, reach, half_angle, progress, Color("e36f60"))
	draw_magic_guides(aim_dir, reach, shots, spread, progress)
