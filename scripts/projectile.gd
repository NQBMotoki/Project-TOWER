extends Node2D

const ARENA := Rect2(112, 124, 1056, 472)
var direction := Vector2.RIGHT
var damage := 0.0
var friendly := true
var target: Node2D
var speed := 400.0
var lifetime := 2.3
var consumed := false

func setup(origin: Vector2, heading: Vector2, amount: float, is_friendly: bool, player: Node2D) -> void:
	global_position = origin
	direction = heading.normalized()
	damage = amount
	friendly = is_friendly
	target = player
	speed = 400.0 if friendly else 230.0

func _physics_process(delta: float) -> void:
	if consumed:
		return
	lifetime -= delta
	var old_position := global_position
	var next_position := old_position + direction * speed * delta
	if friendly:
		for enemy in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy) or not enemy.alive:
				continue
			var closest := Geometry2D.get_closest_point_to_segment(enemy.global_position, old_position, next_position)
			if closest.distance_to(enemy.global_position) <= enemy.hit_radius + 5.0:
				consumed = true
				enemy.take_damage(damage, direction * 100.0)
				queue_free()
				return
	elif is_instance_valid(target) and target.alive:
		var closest := Geometry2D.get_closest_point_to_segment(target.global_position, old_position, next_position)
		if closest.distance_to(target.global_position) <= 17.0:
			consumed = true
			target.take_damage(damage)
			queue_free()
			return
	global_position = next_position
	if lifetime <= 0.0 or not ARENA.has_point(global_position):
		consumed = true
		queue_free()
	queue_redraw()

func _draw() -> void:
	var color := Color(0.49, 0.85, 1.0) if friendly else Color(1.0, 0.42, 0.41)
	draw_circle(Vector2.ZERO, 10, Color(color.r, color.g, color.b, 0.18))
	draw_rect(Rect2(-5, -5, 10, 10), color)
	draw_rect(Rect2(-2, -2, 4, 4), Color(1.0, 0.96, 0.81))
