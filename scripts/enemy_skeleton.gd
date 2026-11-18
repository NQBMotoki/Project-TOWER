extends "res://scripts/enemy_base.gd"

# Holds still and warns before firing. The aim direction locks when the warning starts.
var telegraph := 0.0
var telegraph_time := 0.55
var aim_dir := Vector2.RIGHT

func _ready() -> void:
	super._ready()
	telegraph_time = float(config.get("telegraph", telegraph_time))

func _behavior(delta: float) -> void:
	var to_player: Vector2 = player.global_position - global_position
	var distance := to_player.length()
	if telegraph > 0.0:
		telegraph -= delta
		if telegraph <= 0.0:
			_fire()
		return
	if distance < 170.0:
		position -= to_player.normalized() * speed * delta
	elif distance > 270.0:
		position += to_player.normalized() * speed * delta
	if spawn_delay <= 0.0 and attack_timer <= 0.0 and distance < 540.0:
		aim_dir = to_player.normalized() if distance > 1.0 else Vector2.RIGHT
		telegraph = telegraph_time
		sound_requested.emit("enemy_chant")

func _fire() -> void:
	attack_timer = cooldown
	var shots := int(config.get("shots", 1))
	var spread := float(config.get("spread", 0.0))
	if shots <= 1:
		projectile_requested.emit(global_position, aim_dir, damage)
	else:
		for i in range(shots):
			var offset := (float(i) - (float(shots) - 1.0) * 0.5) * spread
			projectile_requested.emit(global_position, aim_dir.rotated(offset), damage)
	sound_requested.emit("enemy_magic")

func _draw() -> void:
	super._draw()
	if telegraph > 0.0:
		var progress := 1.0 - telegraph / maxf(0.01, telegraph_time)
		var alpha := lerpf(0.12, 0.85, progress)
		var color := Color(1.0, 0.46, 0.36, alpha)
		if kind == "elite":
			# A filled cone reads from across the arena; the thin arc alone did not.
			var angle := aim_dir.angle()
			var points := PackedVector2Array([Vector2.ZERO])
			for i in range(9):
				points.append(Vector2.from_angle(angle - 0.30 + 0.60 * float(i) / 8.0) * 280.0)
			draw_colored_polygon(points, Color(1.0, 0.42, 0.30, 0.08 + 0.16 * progress))
			draw_arc(Vector2.ZERO, 280.0, angle - 0.30, angle + 0.30, 20, Color(color.r, color.g, color.b, alpha * 0.55), 2.0)
			draw_arc(Vector2.ZERO, 40.0, angle - 0.34, angle + 0.34, 18, color, 4.0)
			draw_line(Vector2.ZERO, aim_dir * 200.0, Color(color.r, color.g, color.b, alpha * 0.75), 2.0)
		else:
			draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, color, 2.5)
