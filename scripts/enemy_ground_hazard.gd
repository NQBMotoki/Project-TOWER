extends Node2D

signal sound_requested(kind: String)

var target: Node2D
var extent := Vector2.ZERO
var radius := 1.0
var warning := 0.0
var warning_total := 0.0
var remaining := 0.0
var damage := 0.0
var hit_cooldown := 0.0
var burst := false

func setup(player: Node2D, segment: Vector2, size: float, delay: float, duration: float, amount: float) -> void:
	target = player
	extent = segment
	radius = size
	warning = delay
	warning_total = delay
	remaining = duration
	damage = amount
	burst = delay > 0.0
	show_behind_parent = true

func _ready() -> void:
	add_to_group("enemy_hazards")

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return
	if warning > 0.0:
		warning -= delta
		if warning > 0.0:
			queue_redraw()
			return
		sound_requested.emit("enemy_zone_burst")
		_hurt_target()
	remaining -= delta
	if remaining <= 0.0:
		queue_free()
	elif not burst:
		hit_cooldown -= delta
		if hit_cooldown <= 0.0 and _hurt_target():
			hit_cooldown = 0.72
	queue_redraw()

func _hurt_target() -> bool:
	var position_in_zone := to_local(target.global_position)
	var closest := Vector2.ZERO
	if not extent.is_zero_approx():
		closest = Geometry2D.get_closest_point_to_segment(position_in_zone, Vector2.ZERO, extent)
	if position_in_zone.distance_squared_to(closest) > radius * radius:
		return false
	target.take_damage(damage)
	return true

func _draw() -> void:
	var color := Color("e882f1") if burst else Color("66dc91")
	var pulse := 0.3 + 0.45 * (1.0 - maxf(0.0, warning) / maxf(0.01, warning_total))
	if not extent.is_zero_approx():
		draw_line(Vector2.ZERO, extent, Color(color, 0.27), radius * 2.0)
		draw_dashed_line(Vector2.ZERO, extent, Color(color, 0.88), 2.0, 7.0)
		draw_circle(extent, radius, Color(color, 0.27))
		draw_arc(extent, radius, 0.0, TAU, 28, Color(color, 0.86), 2.0)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.22 if warning > 0.0 else 0.38))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, Color(color, 0.95), 2.0)
	if burst:
		draw_arc(Vector2.ZERO, radius * pulse, 0.0, TAU, 28, Color(color, 0.73), 2.0)
		draw_line(Vector2(-7, 0), Vector2(7, 0), Color(color, 0.9), 2.0)
		draw_line(Vector2(0, -7), Vector2(0, 7), Color(color, 0.9), 2.0)
