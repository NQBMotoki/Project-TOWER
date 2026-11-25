extends "res://scripts/enemy_boss.gd"

enum Attack { NONE, SWEEP_FIRST, SWEEP_SECOND, VOLLEY, CHARGE_WINDUP, CHARGE }

var attack := Attack.NONE
var heading := Vector2.DOWN
var attack_time := 0.0
var attack_total := 0.0
var attacks_finished := 0
var approach_time := 0.0
var charge_connected := false
var wall_sparks := false

func setup(enemy_kind: String, target: Node2D) -> void:
	super.setup(enemy_kind, target)
	boss_stage = 1
	boss_stage_total = 2
	facing = Vector2.DOWN

func _ready() -> void:
	super._ready()
	sound_requested.emit("elite_entrance")

func _behavior(delta: float) -> void:
	if _boss_action_blocked(delta):
		return
	if attack == Attack.CHARGE:
		_charge(delta)
		return
	if attack != Attack.NONE:
		attack_time -= delta
		if attack_time <= 0.0:
			_release()
		return
	var distance := global_position.distance_to(player.global_position)
	if attack_timer <= 0.0:
		approach_time += delta
	if attack_timer <= 0.0 and can_begin_attack() and sees_player():
		var strike_trigger: float = config.get("strike_trigger", 93.0)
		var charge_reach := _charge_speed() * _charge_duration() + hit_radius + 4.0
		if boss_stage == 2 and attacks_finished % 3 == 1 \
				and distance > strike_trigger * 0.7 and distance <= charge_reach:
			heading = aim_at_player()
			charge_connected = false
			_prepare(Attack.CHARGE_WINDUP, config.get("rush_telegraph", 0.72), "rush", "elite_charge_warn")
			return
		if distance <= strike_trigger:
			heading = aim_at_player()
			_prepare(Attack.SWEEP_FIRST, config.get("sweep_telegraph", 0.72), "sweep", "elite_sweep_warn")
			return
		if distance <= config.reach and sees_player(ArenaLayout.PROJECTILE_RADIUS) \
				and (attacks_finished % 3 != 2 or approach_time >= 1.8):
			heading = aim_at_player()
			_prepare(Attack.VOLLEY, config.telegraph, "volley", "elite_volley_warn")
			return
	if distance > config.get("strike_trigger", 93.0) * 0.76 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _prepare(next: Attack, duration: float, pose: String, cue: String) -> void:
	attack = next
	attack_time = duration
	attack_total = duration
	_attack_art = pose
	sound_requested.emit(cue)

func _release() -> void:
	match attack:
		Attack.SWEEP_FIRST, Attack.SWEEP_SECOND:
			show_attack_release()
			if target_in_sector(_sweep_heading(), config.get("strike_reach", 106.0), config.get("strike_angle", 0.88)):
				player.take_damage(damage, "enemy")
			sound_requested.emit("elite_sweep")
			if attack == Attack.SWEEP_FIRST:
				_prepare(Attack.SWEEP_SECOND, config.get("sweep_followup", 0.44), "sweep", "elite_sweep_warn")
				return
			_finish(0.59)
		Attack.VOLLEY:
			fire_fan(heading, config.shots, config.spread, "elite_volley")
			_finish(0.54)
		Attack.CHARGE_WINDUP:
			_prepare(Attack.CHARGE, _charge_duration(), "rush", "elite_charge")

func _charge(delta: float) -> void:
	var previous := global_position
	var struck_wall := move_straight(heading, _charge_speed() * minf(delta, attack_time))
	if not charge_connected:
		charge_connected = swept_attack(previous, hit_radius + 4.0, damage * 1.25)
	attack_time -= delta
	if attack_time > 0.0 and not struck_wall:
		return
	wall_sparks = struck_wall
	if struck_wall:
		sound_requested.emit("elite_wall")
	_finish(config.get("rush_recover", 0.65) + (0.18 if struck_wall else 0.0))

func _finish(duration: float) -> void:
	attack = Attack.NONE
	approach_time = 0.0
	attacks_finished += 1
	_recover_for(duration)

func _charge_speed() -> float:
	return config.get("rush_speed", 460.0)

func _charge_duration() -> float:
	return config.get("rush_time", 0.42)

func _sweep_heading() -> Vector2:
	return heading.rotated(-0.23 if attack == Attack.SWEEP_FIRST else 0.23)

func holding_attack_slot() -> bool:
	return attack != Attack.NONE

func leaves_trail() -> bool:
	return attack == Attack.CHARGE or (_attack_art == "rush" and recovery > 0.0)

func _stage_for_health() -> int:
	return 2 if hp / max_hp <= config.get("phase_threshold", 0.55) else 1

func _phase_cue() -> String:
	return "elite_phase"

func _reset_actions() -> void:
	attack = Attack.NONE
	approach_time = 0.0
	attacks_finished = 0
	wall_sparks = false

func _special_frame() -> Texture2D:
	if spawn_delay <= 0.0:
		return super._special_frame()
	var index := ActorMotion.frame_index(1.0 - spawn_delay / spawn_delay_total, 4)
	return UpgradeArt.frame(kind, "s", "assemble", index)

func _prepare_action_pose() -> void:
	super._prepare_action_pose()
	if attack != Attack.NONE:
		var phase := ActorMotion.Phase.STRIKE if attack == Attack.CHARGE else ActorMotion.Phase.WINDUP
		set_action_pose(phase, attack_time, attack_total)

func _draw_warning() -> void:
	super._draw_warning()
	if wall_sparks and recovery > recovery_total - 0.23:
		var alpha := clampf((recovery - recovery_total + 0.23) / 0.23, 0.0, 1.0)
		for index in range(5):
			var ray := heading.rotated((index - 2) * 0.32)
			var start := ray * (9.0 + 8.0 * (1.0 - alpha))
			_warning.draw_line(start, start + ray * (4.0 + index), Color(0.92, 0.74, 0.51, alpha), 2.0)
	if attack == Attack.NONE:
		return
	var progress := clampf(1.0 - attack_time / attack_total, 0.0, 1.0)
	match attack:
		Attack.SWEEP_FIRST, Attack.SWEEP_SECOND:
			draw_sector(_sweep_heading(), config.get("strike_reach", 106.0),
				config.get("strike_angle", 0.88), progress, Color("ffc895"))
		Attack.VOLLEY:
			draw_magic_guides(heading, config.reach, config.shots, config.spread, progress, Color("eee1b3"))
		Attack.CHARGE_WINDUP:
			draw_rush_path(heading, _charge_speed() * _charge_duration(), hit_radius + 4.0, progress, Color("f0ac72"))
