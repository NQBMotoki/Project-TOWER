class_name ArenaLayout
extends RefCounted

const BOUNDS := Rect2(112, 124, 1056, 472)
const PLAYER_START := Vector2(640, 365)
const PLAYER_RADIUS := 16.0
const ELITE_RADIUS := 25.0
const PROJECTILE_RADIUS := 4.0
const SPAWN_POINTS := [
	Vector2(160, 165), Vector2(640, 165), Vector2(1120, 165),
	Vector2(160, 555), Vector2(640, 555), Vector2(1120, 555),
]
const BORDER_GAP := 57.0
const OBSTACLE_GAP := 61.0
const MOTION_MARGIN := 0.1

var obstacles: Array = []
var _navigation := AStar2D.new()

func generate(definition: FloorDefinition, rng: RandomNumberGenerator) -> void:
	var protected := protected_points(definition)
	var locations: Array[Vector2] = []
	for y in [226, 356, 494]:
		if y == 356 and definition.keep_center_open:
			continue
		for x in [255, 410, 565, 720, 875, 1030]:
			locations.append(Vector2(x, y))
	obstacles.clear()
	while obstacles.size() < definition.obstacle_count and not locations.is_empty():
		var center: Vector2 = locations.pop_at(rng.randi_range(0, locations.size() - 1))
		center += Vector2(rng.randi_range(-6, 6), rng.randi_range(-6, 6))
		var kind := "pillar" if rng.randi_range(0, 1) == 0 else "wall"
		var size := Vector2(45, 42) if kind == "pillar" else Vector2(rng.randi_range(61, 76), 29)
		var rect := Rect2(center - size / 2.0, size)
		if _valid_obstacle(rect, definition.keep_center_open, protected):
			obstacles.append({"rect": rect, "kind": kind})
	_build_navigation()
	assert(obstacles.size() == definition.obstacle_count and connected(protected))

func restore(saved: Variant, definition: FloorDefinition) -> bool:
	if not saved is Array or saved.size() != definition.obstacle_count:
		return false
	obstacles.clear()
	var protected := protected_points(definition)
	for entry in saved:
		if not entry is Dictionary or not entry.get("rect") is Rect2 or entry.get("kind") not in ["pillar", "wall"]:
			return false
		if not _valid_obstacle(entry.rect, definition.keep_center_open, protected):
			return false
		obstacles.append(entry.duplicate())
	_build_navigation()
	return connected(protected)

static func protected_points(definition: FloorDefinition) -> Array:
	return [PLAYER_START] + SPAWN_POINTS + definition.clear_pickups.keys()

func _valid_obstacle(rect: Rect2, open_center: bool, protected: Array) -> bool:
	if not rect.is_finite() or rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return false
	if not BOUNDS.grow(-BORDER_GAP).encloses(rect):
		return false
	if open_center and rect.position.y < 459.0 and rect.end.y > 260.0:
		return false
	for point in protected:
		if rect.grow(ELITE_RADIUS + 17.0).has_point(point):
			return false
	for entry in obstacles:
		if rect.grow(OBSTACLE_GAP).intersects(entry.rect):
			return false
	return true

func is_walkable(point: Vector2, radius: float) -> bool:
	if not point.is_finite() or not BOUNDS.grow(-radius).has_point(point):
		return false
	for entry in obstacles:
		if entry.rect.grow(radius).has_point(point):
			return false
	return true

func has_clear_line(from: Vector2, to: Vector2, radius := 0.0) -> bool:
	return first_block(from, to, radius) == INF

func first_block(from: Vector2, to: Vector2, radius := 0.0) -> float:
	var first := INF
	for entry in obstacles:
		first = minf(first, _rect_entry(from, to, entry.rect.grow(radius)))
	return first

static func _rect_entry(from: Vector2, to: Vector2, rect: Rect2) -> float:
	var near := 0.0
	var far := 1.0
	var travel := to - from
	for axis in [0, 1]:
		if is_zero_approx(travel[axis]):
			if from[axis] < rect.position[axis] or from[axis] > rect.end[axis]:
				return INF
			continue
		var a: float = (rect.position[axis] - from[axis]) / travel[axis]
		var b: float = (rect.end[axis] - from[axis]) / travel[axis]
		near = maxf(near, minf(a, b))
		far = minf(far, maxf(a, b))
		if near > far:
			return INF
	return near

func move_actor(from: Vector2, offset: Vector2, radius: float) -> Vector2:
	var bounds := BOUNDS.grow(-radius)
	# Keep a small margin at clip points so subsequent steps can slide along a face.
	var to := (from + offset).clamp(bounds.position + Vector2.ONE * MOTION_MARGIN,
		bounds.end - Vector2.ONE * MOTION_MARGIN)
	var horizontal := _clip_motion(from, Vector2(to.x, from.y), radius)
	return _clip_motion(horizontal, Vector2(horizontal.x, to.y), radius)

func _clip_motion(from: Vector2, to: Vector2, radius: float) -> Vector2:
	if from.is_equal_approx(to):
		return from
	var fraction := first_block(from, to, radius)
	if fraction == INF:
		return to
	return from.lerp(to, maxf(0.0, fraction - MOTION_MARGIN / from.distance_to(to)))

func _build_navigation() -> void:
	_navigation.clear()
	var id := 2
	for entry in obstacles:
		var rect: Rect2 = entry.rect.grow(ELITE_RADIUS + 3.0)
		for point in [rect.position, Vector2(rect.end.x, rect.position.y),
				rect.end, Vector2(rect.position.x, rect.end.y)]:
			_connect_point(id, point, ELITE_RADIUS)
			id += 1

func _connect_point(id: int, point: Vector2, radius: float) -> void:
	var others := _navigation.get_point_ids()
	_navigation.add_point(id, point)
	for other in others:
		if has_clear_line(point, _navigation.get_point_position(other), radius):
			_navigation.connect_points(id, other)

func path_to(from: Vector2, target: Vector2, radius: float) -> PackedVector2Array:
	var to := _walkable_target(target, radius)
	if has_clear_line(from, to, radius):
		return PackedVector2Array([to])
	_connect_point(0, from, radius)
	_connect_point(1, to, radius)
	var path := _navigation.get_point_path(0, 1)
	_navigation.remove_point(0)
	_navigation.remove_point(1)
	if not path.is_empty():
		path.remove_at(0)
	return path

func _walkable_target(point: Vector2, radius: float) -> Vector2:
	var bounds := BOUNDS.grow(-radius - MOTION_MARGIN)
	var target := point.clamp(bounds.position, bounds.end)
	for entry in obstacles:
		var rect: Rect2 = entry.rect.grow(radius + 1.0)
		if not rect.has_point(target):
			continue
		var sides := [Vector2(rect.position.x, target.y), Vector2(rect.end.x, target.y),
			Vector2(target.x, rect.position.y), Vector2(target.x, rect.end.y)]
		var nearest: Vector2 = sides[0]
		for side in sides:
			if side.distance_squared_to(target) < nearest.distance_squared_to(target):
				nearest = side
		return nearest
	return target

func connected(points: Array) -> bool:
	for point in points:
		if not is_walkable(point, ELITE_RADIUS) or path_to(PLAYER_START, point, ELITE_RADIUS).is_empty():
			return false
	return true

func shooting_position(from: Vector2, target: Vector2, preferred: float, radius: float) -> Vector2:
	var best := target
	var best_cost := INF
	var heading := (from - target).angle()
	for distance in [preferred, preferred * 0.76, preferred * 0.55]:
		for i in range(16):
			var point: Vector2 = target + Vector2.from_angle(heading + i * TAU / 16.0) * distance
			if not is_walkable(point, radius) or not has_clear_line(point, target, PROJECTILE_RADIUS):
				continue
			var cost: float = from.distance_to(point) + (preferred - distance) * 0.85
			if cost < best_cost:
				best = point
				best_cost = cost
	return best
