extends "res://scripts/enemy_base.gd"

# Holds still and warns before firing. The aim direction locks when the warning starts.
# `reach` is both the firing gate and the drawn warning range, so the marked
# area always covers every shot that can actually be taken.
var telegraph := 0.0
var telegraph_time := 0.55
var aim_dir := Vector2.RIGHT
var reach := 560.0

func _ready() -> void:
	super._ready()
	telegraph_time = float(config.get("telegraph", telegraph_time))
	reach = float(config.get("reach", reach))

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
	if spawn_delay <= 0.0 and attack_timer <= 0.0 and distance < reach:
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
			# The cone must cover every shot that can be taken, so it is drawn all
			# the way to `reach`. The inner half is brighter so a long cone still
			# reads as one shape.
			var angle := aim_dir.angle()
			var points := PackedVector2Array([Vector2.ZERO])
			for i in range(9):
				points.append(Vector2.from_angle(angle - 0.30 + 0.60 * float(i) / 8.0) * reach)
			draw_colored_polygon(points, Color(1.0, 0.42, 0.30, 0.05 + 0.09 * progress))
			var inner := PackedVector2Array([Vector2.ZERO])
			for i in range(9):
				inner.append(Vector2.from_angle(angle - 0.30 + 0.60 * float(i) / 8.0) * reach * 0.55)
			draw_colored_polygon(inner, Color(1.0, 0.42, 0.30, 0.06 + 0.11 * progress))
			draw_arc(Vector2.ZERO, reach, angle - 0.30, angle + 0.30, 24, Color(color.r, color.g, color.b, alpha * 0.5), 2.0)
			draw_arc(Vector2.ZERO, 40.0, angle - 0.34, angle + 0.34, 18, color, 4.0)
			draw_line(Vector2.ZERO, aim_dir * reach * 0.6, Color(color.r, color.g, color.b, alpha * 0.45), 2.0)
		else:
			draw_arc(Vector2.ZERO, 27.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, color, 2.5)
