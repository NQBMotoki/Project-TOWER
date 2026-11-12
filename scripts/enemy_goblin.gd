extends "res://scripts/enemy_base.gd"

var windup := 0.0
var strike_direction := Vector2.RIGHT

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			if spawn_delay <= 0.0 and to_player.length() < 55.0 and absf(strike_direction.angle_to(to_player)) < deg_to_rad(55.0):
				player.take_damage(damage)
			attack_timer = cooldown
	elif to_player.length() < 42.0 and attack_timer <= 0.0 and spawn_delay <= 0.0:
		windup = 0.5
		strike_direction = to_player.normalized()
	elif to_player.length() > 33.0:
		position += to_player.normalized() * speed * delta

func _draw() -> void:
	super._draw()
	if windup > 0.0:
		draw_line(strike_direction * 18.0, strike_direction * 55.0, Color(1.0, 0.33, 0.25, 0.9), 5.0)
		draw_arc(Vector2.ZERO, 55.0, strike_direction.angle() - 0.5, strike_direction.angle() + 0.5, 12, Color(1.0, 0.38, 0.24, 0.8), 2.0)
