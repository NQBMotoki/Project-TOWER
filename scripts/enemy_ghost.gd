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
				player.take_damage(damage)
			recover = config.recover
			attack_timer = cooldown
			sound_requested.emit("enemy_magic")
		return
	if recover > 0.0:
		recover -= delta
		body_alpha = lerpf(0.55, 1.0, maxf(0.0, recover) / config.recover)
		return
	if attack_timer <= 0.0 and distance <= config.strike_trigger and sees_player():
		windup = config.telegraph
		body_alpha = 1.0
		sound_requested.emit("enemy_ghost")
	elif distance > config.strike_trigger * 0.75 or not sees_player():
		move_towards(player.global_position, speed * delta)

func _prepare_action_pose() -> void:
	if windup > 0.0:
		set_action_pose(ActorMotion.Phase.WINDUP, windup, config.telegraph)
	elif recover > 0.0:
		set_action_pose(ActorMotion.Phase.RECOVERY, recover, config.recover)

func _draw() -> void:
	super._draw()
	if windup <= 0.0:
		return
	var progress: float = 1.0 - windup / config.telegraph
	var rim := PackedVector2Array()
	for i in range(32):
		var ray := Vector2.from_angle(i * TAU / 32.0)
		rim.append(ray * clear_reach(ray, config.strike_reach))
	draw_colored_polygon(rim, Color(0.59, 0.85, 1.0, 0.12 + 0.25 * progress))
	rim.append(rim[0])
	draw_polyline(rim, Color(0.68, 0.90, 1.0, 0.56 + 0.44 * progress), 3.0)
