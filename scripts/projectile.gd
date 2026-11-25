extends Node2D

signal impact_sound(kind: String, position: Vector2)

var direction := Vector2.RIGHT
var damage := 0.0
var friendly := true
var trap_arrow := false
var target: Node2D
var speed := 400.0
var lifetime := 2.3
var remaining_distance := INF
var travelled_distance := 0.0
var consumed := false
var layout: ArenaLayout
var weapon_id := ""
var attack_token := 0

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
		if trap_arrow or (not friendly and speed > 400.0):
			impact_sound.emit("arrow_impact", global_position)
		elif not friendly and victim == null:
			impact_sound.emit("skeleton_bone_impact", global_position)
		queue_free()
		if victim != null:
			if victim == target:
				victim.take_damage(damage, "trap" if trap_arrow else "enemy")
			elif friendly and not weapon_id.is_empty() and is_instance_valid(target):
				target.apply_attack_hit(victim, damage, direction * 100.0, weapon_id, attack_token)
			else:
				victim.take_damage(damage, direction * 100.0)
		return
	global_position = next_position
	travelled_distance += step
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
		var history := minf(travelled_distance, 19.0)
		var tail := -direction * history
		var fin := direction.orthogonal() * minf(3.0, history * 0.35)
		draw_line(tail, direction * 5.0, Color(shaft, 0.81), 2.2)
		if history >= 6.0:
			draw_line(tail + fin, tail + direction * 7.0, Color(shaft, 0.58), 1.5)
			draw_line(tail - fin, tail + direction * 7.0, Color(shaft, 0.58), 1.5)
		draw_line(direction * 5.0, Vector2.ZERO, head, 3.0)
		return
	var color := Color("8ddcfa") if friendly else Color("ea92c5")
	var side := direction.orthogonal()
	var trail := minf(travelled_distance, 25.0)
	if trail > 0.5:
		draw_colored_polygon(PackedVector2Array([side * 4.0, -direction * trail, -side * 4.0]), Color(color, 0.30))
	var center := -direction * minf(trail * 0.55, 13.0)
	draw_line(center, Vector2.ZERO, Color(color, 0.77), 2.0)
	draw_colored_polygon(PackedVector2Array([direction * 6.0, side * 4.0, -direction * 5.0, -side * 4.0]), color)
	draw_rect(Rect2(-1.5, -1.5, 3.0, 3.0), Color("fff0d9"))
