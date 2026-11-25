extends "res://scripts/enemy_base.gd"

var windup := 0.0
var recover := 0.0

func _ready() -> void:
	super._ready()
	body_alpha = 0.56
	if art != null:
		art.modulate.a = body_alpha

func _behavior(delta: float) -> void:
	var distance := global_position.distance_to(player.global_position)
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			show_attack_release()
			if distance <= config.strike_reach and sees_player():
				player.take_damage(damage, "enemy")
			recover = config.recover
			body_alpha = 0.42
			attack_timer = cooldown
			sound_requested.emit("ghost_strike")
		return
	if recover > 0.0:
		recover -= delta
		body_alpha = lerpf(0.88, 0.42, maxf(0.0, recover) / config.recover)
		return
	if attack_timer <= 0.0 and can_begin_attack() and distance <= config.strike_trigger and sees_player():
		windup = config.telegraph
		body_alpha = 1.0
		sound_requested.emit("ghost_manifest")
	elif distance > config.strike_trigger * 0.75 or not sees_player():
		var previous := facing
		move_towards(player.global_position, speed * delta)
		facing = previous.slerp(facing, minf(1.0, delta * 5.0))
		body_alpha = move_toward(body_alpha, 0.68, delta * 0.55)

func holding_attack_slot() -> bool:
	return windup > 0.0

func leaves_trail() -> bool:
	return windup <= 0.0

func movement_facing(_velocity: Vector2) -> Vector2:
	return facing

func _prepare_action_pose() -> void:
	if windup > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, windup, config.telegraph)
	elif recover > 0.0:
		set_action_pose(ActorMotion.Phase.RECOVERY, recover, config.recover)

func _draw_warning() -> void:
	super._draw_warning()
	if windup <= 0.0:
		return
	var progress: float = 1.0 - windup / config.telegraph
	var rim := PackedVector2Array()
	for i in range(32):
		var ray := Vector2.from_angle(i * TAU / 32.0)
		rim.append(ray * clear_reach(ray, config.strike_reach))
	_warning.draw_colored_polygon(rim, Color(0.59, 0.85, 1.0, 0.08 + 0.16 * progress))
	rim.append(rim[0])
	_warning.draw_polyline(rim, Color(0.68, 0.90, 1.0, 0.56 + 0.44 * progress), 2.5)
	_warning.draw_arc(Vector2.ZERO, hit_radius + 5.0, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, Color("c8f3e9"), 2.0)
