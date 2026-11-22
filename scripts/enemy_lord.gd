extends "res://scripts/enemy_base.gd"

enum Attack { NONE, BLADE, VOLLEY }

var attack := Attack.NONE
var windup := 0.0
var windup_duration := 0.0
var heading := Vector2.RIGHT
var ranged_casts := 0

func _behavior(delta: float) -> void:
	if attack != Attack.NONE:
		windup -= delta
		if windup <= 0.0:
			_resolve_attack()
		return
	var distance := global_position.distance_to(player.global_position)
	if attack_timer <= 0.0:
		if distance <= config.strike_trigger and sees_player():
			_begin_attack(Attack.BLADE, config.telegraph, "enemy_telegraph")
			return
		if ranged_casts % 2 == 1 and distance < config.zone_reach:
			show_attack_release()
			add_hazard(player.global_position, player.global_position, config.zone_radius,
				config.zone_delay, 0.28, config.zone_damage)
			ranged_casts += 1
			attack_timer = cooldown
			sound_requested.emit("enemy_zone_warning")
			return
		if distance < config.reach and sees_player(ArenaLayout.PROJECTILE_RADIUS):
			_begin_attack(Attack.VOLLEY, config.cast_telegraph, "enemy_chant")
			return
	if distance > config.strike_trigger * 0.78 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _begin_attack(next_attack: Attack, duration: float, sound: String) -> void:
	attack = next_attack
	var phase_factor: float = config.phase_delay_factor if hp / max_hp <= config.phase_threshold else 1.0
	windup_duration = duration * phase_factor
	windup = windup_duration
	heading = aim_at_player()
	sound_requested.emit(sound)

func _resolve_attack() -> void:
	if attack == Attack.BLADE:
		show_attack_release()
		if target_in_sector(heading, config.strike_reach, config.strike_angle):
			player.take_damage(damage)
		sound_requested.emit("enemy_rush")
	else:
		fire_fan(heading, config.shots, config.spread)
		ranged_casts += 1
	attack = Attack.NONE
	attack_timer = cooldown

func _prepare_action_pose() -> void:
	if attack != Attack.NONE:
		set_action_pose(ActorMotion.Phase.WINDUP, windup, windup_duration)

func _draw() -> void:
	super._draw()
	match attack:
		Attack.BLADE:
			draw_sector(heading, config.strike_reach, config.strike_angle, 1.0 - windup / windup_duration, Color("ff8157"))
		Attack.VOLLEY:
			draw_magic_guides(heading, config.reach, config.shots, config.spread, 1.0 - windup / windup_duration)
