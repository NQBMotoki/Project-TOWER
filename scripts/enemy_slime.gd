extends "res://scripts/enemy_base.gd"

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	if to_player.length() > 24.0:
		position += to_player.normalized() * speed * delta
	elif spawn_delay <= 0.0 and attack_timer <= 0.0:
		player.take_damage(damage)
		attack_timer = cooldown
