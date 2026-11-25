extends "res://scripts/enemy_base.gd"

var recovery := 0.0
var recovery_total := 0.0
var stage_shift := 0.0
var stage_shift_total := 0.0

func take_damage(amount: float, impulse: Vector2 = Vector2.ZERO) -> bool:
	var defeated := super.take_damage(amount, impulse)
	if defeated:
		clear_owned_hazards()
	elif alive and spawn_delay <= 0.0 and stage_shift <= 0.0:
		_change_stage()
	return defeated

func _boss_action_blocked(delta: float) -> bool:
	if stage_shift > 0.0:
		stage_shift = maxf(0.0, stage_shift - delta)
		return true
	if _change_stage():
		return true
	if recovery > 0.0:
		recovery = maxf(0.0, recovery - delta)
		return true
	return false

func _change_stage() -> bool:
	if _stage_for_health() <= boss_stage:
		return false
	boss_stage += 1
	clear_owned_hazards()
	_reset_actions()
	_release_pose_age = INF
	recovery = 0.0
	stage_shift_total = config.get("phase_transition", 1.0)
	stage_shift = stage_shift_total
	attack_timer = 0.0
	boss_phase_changed.emit(boss_stage)
	sound_requested.emit(_phase_cue())
	return true

func _recover_for(duration: float) -> void:
	recovery = duration
	recovery_total = duration
	attack_timer = maxf(cooldown, duration)

func _stage_for_health() -> int:
	return 1

func _phase_cue() -> String:
	return ""

func _reset_actions() -> void:
	pass

func _special_frame() -> Texture2D:
	if stage_shift <= 0.0:
		return null
	var direction := ActorMotion.direction_name(facing)
	var progress := 1.0 - stage_shift / stage_shift_total
	var index := ActorMotion.frame_index(progress, UpgradeArt.frame_count(kind, direction, "phase"))
	return UpgradeArt.frame(kind, direction, "phase", index)

func _prepare_action_pose() -> void:
	if recovery > 0.0:
		set_action_pose(ActorMotion.Phase.RECOVERY, recovery, recovery_total)

func _draw_warning() -> void:
	super._draw_warning()
	if stage_shift <= 0.0:
		return
	var progress := 1.0 - stage_shift / stage_shift_total
	var radius := hit_radius + 7.0 + 20.0 * progress
	var color := Color(0.83, 0.54, 0.90, 0.43 * sin(PI * progress))
	_warning.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 32, color, 2.0)
	for index in range(8):
		var vector := Vector2.from_angle(TAU * index / 8.0 + progress * 0.2)
		_warning.draw_line(vector * radius, vector * (radius + 3.0), color, 2.0)
