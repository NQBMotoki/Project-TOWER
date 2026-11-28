extends "res://scripts/enemy_base.gd"

enum RushPhase { NONE, WINDUP, ADVANCE, RECOVER }

var windup := 0.0
var strike_direction := Vector2.RIGHT
var rush_phase := RushPhase.NONE
var rush_remaining := 0.0
var rush_direction := Vector2.RIGHT
var strike_recover := 0.0
var rush_hit := false

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
				player.take_damage(damage, "enemy")
			sound_requested.emit("goblin_swing")
			strike_recover = 0.32
			attack_timer = cooldown
		return
	if strike_recover > 0.0:
		strike_recover -= delta
		return
	if attack_timer <= 0.0 and can_begin_attack() and sees_player():
		if distance <= config.strike_trigger:
			_prepare_strike()
			return
		if config.has("rush_trigger") and distance <= config.rush_trigger:
			rush_direction = aim_at_player()
			_attack_art = "rush"
			rush_phase = RushPhase.WINDUP
			rush_remaining = config.rush_telegraph
			rush_hit = false
			sound_requested.emit("goblin_rush_warn")
			return
	if distance > config.strike_trigger * 0.77 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _prepare_strike() -> void:
	_attack_art = ""
	windup = config.telegraph
	strike_direction = aim_at_player()
	sound_requested.emit("goblin_windup")

func _update_rush(delta: float) -> void:
	var struck_wall := false
	if rush_phase == RushPhase.ADVANCE:
		var start := global_position
		struck_wall = move_straight(rush_direction, config.rush_speed * minf(delta, rush_remaining))
		if not rush_hit:
			rush_hit = swept_attack(start, hit_radius + 5.0, damage)
	rush_remaining -= delta
	if rush_remaining > 0.0 and not struck_wall:
		return
	match rush_phase:
		RushPhase.WINDUP:
			rush_phase = RushPhase.ADVANCE
			rush_remaining = config.rush_time
			sound_requested.emit("goblin_rush")
		RushPhase.ADVANCE:
			rush_phase = RushPhase.RECOVER
			rush_remaining = config.rush_recover
		RushPhase.RECOVER:
			rush_phase = RushPhase.NONE
			attack_timer = cooldown

func holding_attack_slot() -> bool:
	return windup > 0.0 or rush_phase == RushPhase.WINDUP or rush_phase == RushPhase.ADVANCE

func leaves_trail() -> bool:
	return rush_phase == RushPhase.ADVANCE or rush_phase == RushPhase.RECOVER

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

func _draw_warning() -> void:
	super._draw_warning()
	if windup > 0.0:
		draw_sector(strike_direction, config.strike_reach, config.strike_angle,
			1.0 - windup / config.telegraph, Color("ff8a61"))
	elif rush_phase == RushPhase.WINDUP:
		var progress: float = 1.0 - rush_remaining / config.rush_telegraph
		draw_rush_path(rush_direction, config.rush_speed * config.rush_time, hit_radius + 5.0, progress, Color("ffad79"))
