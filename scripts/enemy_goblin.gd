extends "res://scripts/enemy_base.gd"

enum RushPhase { NONE, WINDUP, ADVANCE, RECOVER }

var windup := 0.0
var strike_direction := Vector2.RIGHT
var rush_phase := RushPhase.NONE
var rush_remaining := 0.0
var rush_direction := Vector2.RIGHT

func _behavior(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if rush_phase != RushPhase.NONE:
		_update_rush(delta)
		return
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			show_attack_release()
			if target_in_sector(strike_direction, config.strike_reach, config.strike_angle):
				player.take_damage(damage)
			attack_timer = cooldown
		return
	if attack_timer <= 0.0 and sees_player():
		if distance <= config.strike_trigger:
			_prepare_strike()
			return
		if config.has("rush_trigger") and distance <= config.rush_trigger:
			rush_direction = aim_at_player()
			rush_phase = RushPhase.WINDUP
			rush_remaining = config.rush_telegraph
			sound_requested.emit("enemy_rush")
			return
	if distance > config.strike_trigger * 0.77 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _prepare_strike() -> void:
	windup = config.telegraph
	strike_direction = aim_at_player()
	sound_requested.emit("enemy_telegraph")

func _update_rush(delta: float) -> void:
	if rush_phase == RushPhase.ADVANCE:
		move_straight(rush_direction, config.rush_speed * minf(delta, rush_remaining))
	rush_remaining -= delta
	if rush_remaining > 0.0:
		return
	match rush_phase:
		RushPhase.WINDUP:
			rush_phase = RushPhase.ADVANCE
			rush_remaining = config.rush_time
		RushPhase.ADVANCE:
			rush_phase = RushPhase.RECOVER
			rush_remaining = config.rush_recover
			if global_position.distance_to(player.global_position) <= config.strike_reach and sees_player():
				_prepare_strike()
				# After the pursuit, the same melee warning still governs damage.
				rush_phase = RushPhase.NONE
		RushPhase.RECOVER:
			rush_phase = RushPhase.NONE
			attack_timer = cooldown

func _prepare_action_pose() -> void:
	if windup > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, windup, config.telegraph)
		return
	match rush_phase:
		RushPhase.WINDUP:
			set_action_pose(ActorMotion.Phase.WINDUP, rush_remaining, config.rush_telegraph)
		RushPhase.ADVANCE:
			set_action_pose(ActorMotion.Phase.STRIKE, rush_remaining, config.rush_time)
		RushPhase.RECOVER:
			set_action_pose(ActorMotion.Phase.RECOVERY, rush_remaining, config.rush_recover)

func _draw() -> void:
	super._draw()
	if windup > 0.0:
		draw_sector(strike_direction, config.strike_reach, config.strike_angle,
			1.0 - windup / config.telegraph, Color("ff8a61"))
	elif rush_phase == RushPhase.WINDUP:
		var reach := clear_reach(rush_direction, config.rush_speed * config.rush_time, hit_radius)
		var progress: float = 1.0 - rush_remaining / config.rush_telegraph
		draw_dashed_line(Vector2.ZERO, rush_direction * reach, Color(1.0, 0.64, 0.45, 0.55 + progress * 0.40), 3.0, 7.0)
		draw_arc(rush_direction * reach, hit_radius, 0.0, TAU, 22, Color("ffac67"), 2.0)
