extends Node2D

signal sound_requested(kind: String, position: Vector2)
static var _unshaded: CanvasItemMaterial

var target: Node2D
var extent := Vector2.ZERO
var radius := 1.0
var warning := 0.0
var warning_total := 0.0
var remaining := 0.0
var duration_total := 0.0
var damage := 0.0
var hit_cooldown := 0.0
var burst := false
var _near_edge := PackedVector2Array()
var _far_edge := PackedVector2Array()

func setup(player: Node2D, segment: Vector2, size: float, delay: float, duration: float, amount: float) -> void:
	target = player
	extent = segment
	radius = size
	warning = delay
	warning_total = delay
	remaining = duration
	duration_total = duration
	damage = amount
	burst = delay > 0.0
	show_behind_parent = true

func _ready() -> void:
	add_to_group("enemy_hazards")
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = _unshaded

func _circle_outline(offset: Vector2) -> PackedVector2Array:
	var points := PackedVector2Array()
	for index in range(32):
		var ray := Vector2.from_angle(TAU * index / 32.0) * radius
		var center := to_global(offset)
		var block: float = target.layout.first_block(center, center + ray)
		points.append(offset + ray * (1.0 if block == INF else block))
	return points

func _draw_edge(points: PackedVector2Array, color: Color) -> void:
	draw_polyline(points, color, 2.0)
	draw_line(points[-1], points[0], color, 2.0)

func _physics_process(delta: float) -> void:
	if not is_instance_valid(target) or not target.alive:
		queue_free()
		return
	if warning > 0.0:
		warning -= delta
		if warning > 0.0:
			queue_redraw()
			return
		sound_requested.emit("enemy_zone_burst", global_position)
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
	if position_in_zone.distance_squared_to(closest) > radius * radius \
			or not target.layout.has_clear_line(to_global(closest), target.global_position):
		return false
	target.take_damage(damage, "hazard")
	return true

func _draw() -> void:
	if not is_instance_valid(target):
		return
	if _near_edge.is_empty():
		_near_edge = _circle_outline(Vector2.ZERO)
		if not extent.is_zero_approx():
			_far_edge = _circle_outline(extent)
	var color := Color("eda1f1") if burst else Color("ca9ade")
	var fraction := clampf(1.0 - warning / maxf(0.01, warning_total), 0.0, 1.0)
	var opacity := clampf(remaining / maxf(0.01, duration_total) * 1.8, 0.0, 1.0)
	var edge := Color(color, opacity * (0.60 + 0.35 * fraction))
	var fill := Color(color, (0.12 if warning > 0.0 else 0.27) * opacity)
	if not extent.is_zero_approx():
		var flank := extent.normalized().orthogonal() * radius
		draw_line(Vector2.ZERO, extent, fill, radius * 2.0)
		draw_dashed_line(flank, extent + flank, edge, 1.6, 10.0)
		draw_dashed_line(-flank, extent - flank, edge, 1.6, 10.0)
		draw_colored_polygon(_far_edge, fill)
		_draw_edge(_far_edge, edge)
		if burst and warning > 0.0:
			var section := extent * fraction
			draw_line(section - flank, section + flank, edge, 2.0)
		elif not burst:
			var marks := maxi(1, floori(extent.length() / 16.0))
			for index in marks:
				var at := extent * (index + 0.5) / marks + flank * (0.45 if index % 2 == 0 else -0.52)
				draw_rect(Rect2(at, Vector2(3, 2)), Color(color, opacity * 0.55))
	draw_colored_polygon(_near_edge, fill)
	_draw_edge(_near_edge, edge)
	if burst:
		var ring := PackedVector2Array()
		for point in _near_edge:
			ring.append(point * (0.90 - 0.70 * fraction))
		_draw_edge(ring, Color(color, opacity * 0.77))
		draw_line(Vector2(-6, 0), Vector2(6, 0), edge, 2.0)
		draw_line(Vector2(0, -6), Vector2(0, 6), edge, 2.0)
