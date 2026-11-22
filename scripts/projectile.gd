extends Node2D

var direction := Vector2.RIGHT
var damage := 0.0
var friendly := true
var trap_arrow := false
var target: Node2D
var speed := 400.0
var lifetime := 2.3
var remaining_distance := INF
var consumed := false
var layout: ArenaLayout

func setup(origin: Vector2, heading: Vector2, amount: float, is_friendly: bool, player: Node2D, shot_speed := -1.0, max_travel := -1.0) -> void:
	global_position = origin
	direction = heading.normalized()
	damage = amount
	friendly = is_friendly
	target = player
	layout = player.layout
	if shot_speed > 0.0:
		speed = shot_speed
	else:
		speed = 400.0 if friendly else 230.0
	remaining_distance = max_travel if max_travel >= 0.0 else INF
	lifetime = maxf(2.3, max_travel / speed + 0.02)

func _physics_process(delta: float) -> void:
	if consumed:
		return
	var step := minf(remaining_distance, speed * minf(delta, lifetime))
	lifetime = maxf(0.0, lifetime - delta)
	remaining_distance -= step
	var old_position := global_position
	var next_position := old_position + direction * step
	var impact := layout.first_block(old_position, next_position, ArenaLayout.PROJECTILE_RADIUS)
	var victim: Node2D
	if friendly or trap_arrow:
		var recipients := get_tree().get_nodes_in_group("enemies")
		if friendly:
			recipients.append_array(get_tree().get_nodes_in_group("breakables"))
		for candidate in recipients:
			if not is_instance_valid(candidate) or not candidate.alive:
				continue
			var entry := _hit_fraction(old_position, next_position, candidate.global_position, candidate.hit_radius + ArenaLayout.PROJECTILE_RADIUS)
			if entry < impact and layout.has_clear_line(candidate.global_position, old_position.lerp(next_position, entry)):
				impact = entry
				victim = candidate
	if not friendly and is_instance_valid(target) and target.alive:
		var entry := _hit_fraction(old_position, next_position, target.global_position, ArenaLayout.PLAYER_RADIUS + ArenaLayout.PROJECTILE_RADIUS)
		if entry < impact and layout.has_clear_line(target.global_position, old_position.lerp(next_position, entry)):
			impact = entry
			victim = target
	if impact < INF:
		consumed = true
		global_position = old_position.lerp(next_position, impact)
		queue_free()
		if victim != null:
			if victim == target:
				victim.take_damage(damage)
			else:
				victim.take_damage(damage, direction * 100.0)
		return
	global_position = next_position
	if lifetime <= 0.0 or remaining_distance <= 0.0:
		consumed = true
		queue_free()
	queue_redraw()

func _hit_fraction(from: Vector2, to: Vector2, center: Vector2, radius: float) -> float:
	if from.distance_squared_to(center) <= radius * radius:
		return 0.0
	var fraction := Geometry2D.segment_intersects_circle(from, to, center, radius)
	return fraction if fraction >= 0.0 else INF

func _draw() -> void:
	# Fast hostile shots are arrows: a thin shaft instead of an orb.
	if trap_arrow or (not friendly and speed > 400.0):
		var shaft := Color("ffc270") if trap_arrow else Color("f2e6c2")
		var head := Color("fff0ab") if trap_arrow else Color("bd8a50")
		draw_line(-direction * 16.0, direction * 9.0, shaft, 2.0)
		draw_line(direction * 9.0, direction * 3.0, head, 3.0)
		return
	var color := Color(0.49, 0.85, 1.0) if friendly else Color(1.0, 0.42, 0.41)
	draw_circle(Vector2.ZERO, 10, Color(color.r, color.g, color.b, 0.18))
	draw_rect(Rect2(-5, -5, 10, 10), color)
	draw_rect(Rect2(-2, -2, 4, 4), Color(1.0, 0.96, 0.81))
