extends "res://scripts/enemy_boss.gd"

enum Attack { NONE, SWEEP, FOLLOWUP, VOLLEY, SEAL, LANES }

var attack := Attack.NONE
var windup := 0.0
var windup_duration := 0.0
var heading := Vector2.DOWN
var sequence_position := 0
var combo_side := 1.0

func setup(enemy_kind: String, target: Node2D) -> void:
	super.setup(enemy_kind, target)
	boss_stage = 1
	boss_stage_total = 3
	facing = Vector2.DOWN

func _behavior(delta: float) -> void:
	if _boss_action_blocked(delta):
		return
	if attack != Attack.NONE:
		windup -= delta
		if windup <= 0.0:
			_resolve_attack()
		return
	var distance := global_position.distance_to(player.global_position)
	if attack_timer <= 0.0 and can_begin_attack():
		var decision := _choose_attack(distance)
		if decision != Attack.NONE:
			_begin_attack(decision)
			return
	if distance > config.strike_trigger * 0.76 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _choose_attack(distance: float) -> Attack:
	var in_melee: bool = distance <= config.strike_trigger and sees_player()
	var can_cast: bool = distance < config.reach and sees_player(ArenaLayout.PROJECTILE_RADIUS)
	var can_seal: bool = distance < config.zone_reach and sees_player()
	if boss_stage == 3 and sequence_position == 0 and can_seal:
		return Attack.LANES
	if boss_stage == 3 and sequence_position == 1 and can_cast:
		return Attack.VOLLEY
	if boss_stage < 3 and sequence_position == 2 and can_cast:
		return Attack.VOLLEY
	if sequence_position == 1 and can_seal:
		return Attack.SEAL
	if in_melee:
		return Attack.SWEEP
	if sequence_position == 2 and can_seal:
		return Attack.SEAL
	if can_cast:
		return Attack.VOLLEY
	if can_seal:
		return Attack.SEAL
	return Attack.NONE

func _begin_attack(selected: Attack) -> void:
	heading = aim_at_player()
	var timing: float = config.get("phase_delay_factor", 1.0) if boss_stage > 1 else 1.0
	var target := player.global_position
	match selected:
		Attack.SWEEP:
			_prepare(selected, maxf(0.67, config.telegraph * timing), "melee", "lord_sweep_warn")
		Attack.VOLLEY:
			_prepare(selected, maxf(0.73, config.cast_telegraph * timing), "volley", "lord_volley_warn")
		Attack.SEAL:
			_prepare(selected, config.zone_delay, "zone", "lord_seal_warn")
			_place_seals(target)
		Attack.LANES:
			var lane_warning: float = config.zone_delay + 0.15
			if _place_lanes(lane_warning):
				_prepare(selected, lane_warning, "zone", "lord_lanes_warn")
			else:
				_prepare(Attack.SEAL, config.zone_delay, "zone", "lord_seal_warn")
				_place_seals(target)

func _prepare(selected: Attack, duration: float, pose: String, cue: String) -> void:
	attack = selected
	windup_duration = duration
	windup = duration
	_attack_art = pose
	sound_requested.emit(cue)

func _place_seals(target: Vector2) -> void:
	add_hazard(target, target, config.zone_radius, windup_duration, 0.28, config.zone_damage)
	if boss_stage == 1:
		return
	var flank: Vector2 = heading.orthogonal() * (config.zone_radius * 1.88)
	for offset in [-1, 1]:
		var at: Vector2 = target + flank * offset * combo_side + heading * (offset * 28.0)
		if not layout.is_walkable(at, 8.0) or not layout.has_clear_line(target, at):
			continue
		var delay := windup_duration + (0.24 if offset < 0 else 0.49)
		add_hazard(at, at, config.zone_radius * 0.8, delay, 0.26, config.zone_damage)

func _place_lanes(warning_time: float) -> bool:
	var ready := false
	var flank := heading.orthogonal() * 87.0
	const HALF_WIDTH := 26.0
	for offset in [-1, 1]:
		var start: Vector2 = global_position + heading * 15.0 + flank * offset
		if not layout.is_walkable(start, HALF_WIDTH):
			continue
		var finish := start + heading * minf(355.0, config.reach)
		var block := layout.first_block(start, finish, HALF_WIDTH)
		if block < INF:
			finish = start.lerp(finish, block)
		if finish.distance_squared_to(start) < 50.0 * 50.0:
			continue
		add_hazard(start, finish, HALF_WIDTH, warning_time + (0.21 if offset > 0 else 0.0), 0.29, config.zone_damage)
		ready = true
	return ready

func _resolve_attack() -> void:
	match attack:
		Attack.SWEEP, Attack.FOLLOWUP:
			show_attack_release()
			if target_in_sector(_sweep_heading(), config.strike_reach, config.strike_angle):
				player.take_damage(damage, "enemy")
			sound_requested.emit("lord_sweep")
			if attack == Attack.SWEEP and boss_stage > 1:
				_prepare(Attack.FOLLOWUP, 0.54, "melee", "lord_sweep_warn")
				return
		Attack.VOLLEY:
			fire_fan(heading, config.shots, config.spread, "lord_volley")
		Attack.SEAL:
			show_attack_release()
		Attack.LANES:
			show_attack_release()
			sound_requested.emit("lord_lanes")
	attack = Attack.NONE
	if boss_stage == 3 and sequence_position == 2:
		_recover_for(config.get("long_recovery", 1.02))
	elif boss_stage == 3:
		_recover_for(0.37)
		attack_timer = 0.53
	else:
		_recover_for(0.55 if boss_stage == 1 else 0.68)
	sequence_position = (sequence_position + 1) % 3
	if sequence_position == 0:
		combo_side = -combo_side

func _sweep_heading() -> Vector2:
	if boss_stage == 1:
		return heading
	return heading.rotated((-0.25 if attack == Attack.SWEEP else 0.25) * combo_side)

func holding_attack_slot() -> bool:
	return attack != Attack.NONE

func _stage_for_health() -> int:
	var ratio := hp / max_hp
	if ratio <= config.get("final_phase_threshold", 0.35):
		return 3
	return 2 if ratio <= config.phase_threshold else 1

func _phase_cue() -> String:
	return "lord_phase" if boss_stage == 2 else "lord_final_phase"

func _reset_actions() -> void:
	attack = Attack.NONE
	sequence_position = 0

func _prepare_action_pose() -> void:
	super._prepare_action_pose()
	if attack != Attack.NONE:
		set_action_pose(ActorMotion.Phase.WINDUP, windup, windup_duration)

func _draw_warning() -> void:
	super._draw_warning()
	if attack == Attack.NONE:
		return
	var progress := clampf(1.0 - windup / windup_duration, 0.0, 1.0)
	match attack:
		Attack.SWEEP, Attack.FOLLOWUP:
			draw_sector(_sweep_heading(), config.strike_reach, config.strike_angle, progress, Color("ff9f93"))
		Attack.VOLLEY:
			draw_magic_guides(heading, config.reach, config.shots, config.spread, progress, Color("eaa3d6"))
		Attack.SEAL, Attack.LANES:
			_warning.draw_arc(Vector2.ZERO, hit_radius + 4.0, -PI / 2.0, TAU * progress - PI / 2.0,
				24, Color("f2afef"), 2.0)
