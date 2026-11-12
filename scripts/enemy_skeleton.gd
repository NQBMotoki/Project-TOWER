extends "res://scripts/enemy_base.gd"

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if distance < 170.0:
		position -= to_player.normalized() * speed * delta
	elif distance > 270.0:
		position += to_player.normalized() * speed * delta
	if spawn_delay <= 0.0 and attack_timer <= 0.0 and distance < 540.0:
		var direction := to_player.normalized()
		if kind == "elite":
			for angle in [-0.24, 0.0, 0.24]:
				projectile_requested.emit(global_position, direction.rotated(angle), damage)
		else:
			projectile_requested.emit(global_position, direction, damage)
		attack_timer = cooldown
		sound_requested.emit("enemy_magic")
