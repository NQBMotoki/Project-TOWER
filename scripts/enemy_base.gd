extends Node2D

signal died(enemy: Node)
@warning_ignore("unused_signal")
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)
@warning_ignore("unused_signal")
signal boss_phase_changed(phase: int)

const CompleteEnemies = preload("res://data/complete_enemies.gd")
const UpgradeArt = preload("res://data/upgrade_art.gd")
const EditionArt = preload("res://data/edition_art.gd")
const EnemyHazard = preload("res://scripts/enemy_ground_hazard.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const HIT_FLASH_TIME := 0.14
const RELEASE_POSE_TIME := 0.13
const RECOVERY_POSE_TIME := 0.25
const TRAIL_TIME := 0.24
const TRAIL_COLORS := {
	"slime": Color("b6d583"), "corrupted_slime": Color("da91f5"),
	"corrupted_goblin": Color("e48a77"), "ghost": Color("8dbacb"),
	"elite": Color("e3bf86"),
}
const STEP_SOUNDS := {
	"goblin": "goblin_step", "skeleton": "skeleton_step",
	"archer": "archer_step", "ghost": "ghost_drift",
	"elite": "skeleton_step",
}
static var _unshaded: CanvasItemMaterial
var kind := "slime"
var config: Dictionary = {}
var player: Node2D
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var damage := 1.0
var cooldown := 1.0
var attack_timer := 0.0
var spawn_delay := 0.85
var spawn_delay_total := 0.85
var hit_flash := 0.0
var knockback := Vector2.ZERO
var hit_radius := 17.0
var body_scale := Vector2.ONE
var body_alpha := 1.0
var facing := Vector2.RIGHT
var shot_speed := 230.0
var alive := true
var active := true
var drop_id := ""
var hazard_sound: Callable
var attack_permitted: Callable
var layout: ArenaLayout
var boss_stage := 0
var boss_stage_total := 0
var _route := PackedVector2Array()
var _route_target := Vector2.INF
var _route_remaining := 0.0
var _sight_position := Vector2.ZERO
var _sight_remaining := 0.0
var _art_scale := 1.0
var _fallback_art: Texture2D
var _sprite_frames := false
var _attack_art := ""
var _motion := ActorMotion.new()
var _pose_phase := ActorMotion.Phase.MOVE
var _pose_progress := 0.0
var _release_pose_age := INF
var _warning: Node2D
var _trail: Array[Dictionary] = []
var _hazards: Array[Node2D] = []
var _rush_outline_key: Array = []
var _rush_outline_points := PackedVector2Array()

@onready var art: Sprite2D = get_node_or_null("Sprite2D")

func setup(enemy_kind: String, target: Node2D) -> void:
	kind = enemy_kind
	player = target
	layout = target.layout
	config = CompleteEnemies.ENEMIES[kind]
	max_hp = config.hp
	hp = max_hp
	speed = config.speed
	damage = config.damage
	cooldown = config.cooldown
	shot_speed = float(config.get("shot_speed", 230.0))
	attack_timer = cooldown * 0.5
	if kind in ["elite", "lord"]:
		hit_radius = ArenaLayout.ELITE_RADIUS

func set_spawn_delay(value: float) -> void:
	spawn_delay = maxf(0.0, value)
	spawn_delay_total = maxf(0.01, spawn_delay)

func _ready() -> void:
	add_to_group("enemies")
	_warning = Node2D.new()
	_warning.name = "WorldTelegraph"
	_warning.show_behind_parent = true
	_warning.material = unshaded_material()
	_warning.draw.connect(_draw_warning)
	add_child(_warning)
	if art != null and art.texture == null:
		art.texture = EditionArt.icon(kind)
	if art != null and art.texture != null:
		_fallback_art = art.texture
		var texture_size := art.texture.get_size()
		_art_scale = hit_radius * 2.7 / maxf(texture_size.x, texture_size.y)
		art.scale = Vector2.ONE * _art_scale
		art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if art != null:
		_animate_body(0.0, Vector2.ZERO)

func _physics_process(delta: float) -> void:
	if not active or not alive or not is_instance_valid(player) or not player.alive:
		return
	spawn_delay = maxf(0.0, spawn_delay - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	_release_pose_age += delta
	var previous_position := global_position
	_route_remaining -= delta
	_sight_remaining -= delta
	# A spawning enemy holds still so staggered waves read as separate arrivals.
	if spawn_delay <= 0.0:
		_behavior(delta)
	if not holding_attack_slot():
		move_by(knockback * delta)
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	_update_trail(delta, previous_position)
	if art != null:
		_animate_body(delta, (global_position - previous_position) / maxf(delta, 0.001))
	queue_redraw()
	_warning.queue_redraw()

func _animate_body(delta: float, movement_velocity: Vector2) -> void:
	_pose_phase = ActorMotion.Phase.MOVE
	_pose_progress = 0.0
	_prepare_action_pose()
	if _release_pose_age < RELEASE_POSE_TIME:
		_pose_phase = ActorMotion.Phase.STRIKE
		_pose_progress = _release_pose_age / RELEASE_POSE_TIME
	elif _pose_phase == ActorMotion.Phase.MOVE and movement_velocity.length_squared() < 100.0:
		var recovery_age := _release_pose_age - RELEASE_POSE_TIME
		if recovery_age < RECOVERY_POSE_TIME:
			_pose_phase = ActorMotion.Phase.RECOVERY
			_pose_progress = recovery_age / RECOVERY_POSE_TIME
	var force_frame := _special_frame()
	if hit_flash > 0.0 and force_frame == null and _pose_phase == ActorMotion.Phase.MOVE:
		set_action_pose(ActorMotion.Phase.HURT, hit_flash, HIT_FLASH_TIME)
	if _motion.advance_cycle(delta, movement_velocity, 58.0) and _pose_phase == ActorMotion.Phase.MOVE:
		var step: String = STEP_SOUNDS.get(kind.trim_prefix("corrupted_"), "")
		if not step.is_empty():
			sound_requested.emit(step)
	var moving := movement_velocity.length_squared() > 25.0
	var progress := _pose_progress
	var action: String = ActorMotion.PHASE_NAMES[_pose_phase]
	var direction := facing
	if _pose_phase == ActorMotion.Phase.MOVE:
		progress = _motion.walk_progress if moving else _motion.idle_progress
		if moving:
			action = "walk"
			direction = movement_facing(movement_velocity)
		elif boss_stage > 1:
			action = "final" if boss_stage == 3 else "stance"
	elif _pose_phase != ActorMotion.Phase.HURT and not _attack_art.is_empty():
		action += "_" + _attack_art
	var facing_name := ActorMotion.direction_name(direction)
	var frame_index := ActorMotion.frame_index(progress, UpgradeArt.frame_count(kind, facing_name, action))
	var frame := force_frame if force_frame != null else UpgradeArt.frame(kind, facing_name, action, frame_index)
	_sprite_frames = frame != null
	if _sprite_frames:
		var body_size := hit_radius / 17.0
		art.texture = frame
		art.position = Vector2(0, -24) * body_size
		art.scale = Vector2.ONE * body_size
		art.flip_h = false
		art.rotation = 0.0
	else:
		art.texture = _fallback_art
		_motion.advance(delta, movement_velocity, facing, _pose_phase, _pose_progress)
		_motion.apply(art, Vector2.ZERO, body_scale * _art_scale)
	var hit_age := HIT_FLASH_TIME - hit_flash
	var tint := 1.7 if hit_flash > 0.0 and fmod(hit_age, 0.065) < 0.043 else 1.0
	art.modulate = Color(tint, tint, tint, body_alpha)

func _prepare_action_pose() -> void:
	pass

func _special_frame() -> Texture2D:
	return null

func holding_attack_slot() -> bool:
	return false

func can_begin_attack() -> bool:
	return not attack_permitted.is_valid() or attack_permitted.call()

func leaves_trail() -> bool:
	return false

func movement_facing(velocity: Vector2) -> Vector2:
	return velocity.normalized()

static func unshaded_material() -> CanvasItemMaterial:
	if _unshaded == null:
		_unshaded = CanvasItemMaterial.new()
		_unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _unshaded

func _update_trail(delta: float, previous_position: Vector2) -> void:
	for index in range(_trail.size() - 1, -1, -1):
		_trail[index].remaining -= delta
		if _trail[index].remaining <= 0.0:
			_trail.remove_at(index)
	if not leaves_trail() or previous_position.distance_squared_to(global_position) < 0.25:
		return
	if _trail.is_empty() or Vector2(_trail.back().point).distance_squared_to(previous_position) >= 22.0:
		var texture: Texture2D = art.texture if kind == "ghost" and art != null else null
		_trail.append({"point": previous_position, "remaining": TRAIL_TIME, "texture": texture})

func _draw_warning() -> void:
	var color: Color = TRAIL_COLORS.get(kind, Color.WHITE)
	for entry in _trail:
		var age: float = entry.remaining / TRAIL_TIME
		var at: Vector2 = to_local(entry.point)
		var texture: Texture2D = entry.texture
		if texture != null:
			_warning.draw_texture(texture, at - Vector2(32, 56), Color(color, age * 0.20))
		else:
			var size := Vector2(6.0 + 11.0 * age, 2.0 + 3.0 * age)
			_warning.draw_rect(Rect2(at - size * 0.5, size), Color(color, age * 0.36))
	if spawn_delay > 0.0:
		var progress := clampf(1.0 - spawn_delay / spawn_delay_total, 0.0, 1.0)
		_warning.draw_arc(Vector2.ZERO, hit_radius + 16.0 - 9.0 * progress, 0.0, TAU, 24, Color(0.98, 0.82, 0.51, 0.25 + 0.35 * progress), 2.0)
		_warning.draw_arc(Vector2.ZERO, hit_radius + 7.0, 0.0, TAU, 24, Color(0.98, 0.82, 0.51, 0.55), 2.0)

func set_action_pose(phase: ActorMotion.Phase, remaining: float, duration: float) -> void:
	_pose_phase = phase
	_pose_progress = 1.0 - clampf(remaining / maxf(duration, 0.001), 0.0, 1.0)

func show_attack_release() -> void:
	_release_pose_age = 0.0

func _behavior(_delta: float) -> void:
	pass

func move_by(offset: Vector2) -> void:
	global_position = layout.move_actor(global_position, offset, hit_radius)

func sees_player(clearance := 0.0) -> bool:
	return layout.has_clear_line(global_position, player.global_position, clearance)

func move_towards(target: Vector2, distance: float) -> void:
	var direction := global_position.direction_to(target)
	if direction != Vector2.ZERO:
		facing = direction
	var waypoint := target
	if not layout.has_clear_line(global_position, target, hit_radius):
		if _route_remaining <= 0.0 or _route_target.distance_squared_to(target) > 48.0 * 48.0:
			_route = layout.path_to(global_position, target, hit_radius)
			_route_target = target
			_route_remaining = 0.22
		if not _route.is_empty():
			waypoint = _route[0]
			if global_position.distance_to(waypoint) <= distance:
				_route.remove_at(0)
	move_by((waypoint - global_position).limit_length(distance))

func move_to_sight(preferred: float, distance: float) -> void:
	if _sight_remaining <= 0.0:
		_sight_position = layout.shooting_position(global_position, player.global_position, preferred, hit_radius)
		_sight_remaining = 0.35
	move_towards(_sight_position, distance)

func take_damage(amount: float, impulse: Vector2 = Vector2.ZERO) -> bool:
	if not alive:
		return false
	hp = maxf(0.0, hp - amount)
	knockback = Vector2.ZERO if holding_attack_slot() or boss_stage_total > 0 else impulse
	hit_flash = HIT_FLASH_TIME
	var hit := "hit_flesh"
	if kind in ["skeleton", "corrupted_skeleton", "archer", "corrupted_archer", "elite"]:
		hit = "hit_bone"
	elif kind == "lord":
		hit = "hit_metal"
	elif kind == "ghost":
		hit = "hit"
	sound_requested.emit(hit)
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()
		return true
	return false

func aim_at_player() -> Vector2:
	var direction := global_position.direction_to(player.global_position)
	facing = direction if direction != Vector2.ZERO else facing
	return facing

func target_in_sector(heading: Vector2, reach: float, half_angle: float) -> bool:
	var offset: Vector2 = player.global_position - global_position
	if offset.length_squared() > reach * reach or not sees_player():
		return false
	return offset.is_zero_approx() or absf(heading.angle_to(offset)) <= half_angle

func clear_reach(heading: Vector2, reach: float, clearance := 0.0) -> float:
	var fraction := layout.first_block(global_position, global_position + heading * reach, clearance)
	return reach if fraction == INF else reach * fraction

func move_straight(heading: Vector2, distance: float) -> bool:
	var available := clear_reach(heading, distance, hit_radius)
	var blocked := available < distance
	global_position += heading * maxf(0.0, available - ArenaLayout.MOTION_MARGIN if blocked else available)
	return blocked

func swept_attack(from: Vector2, radius: float, amount: float) -> bool:
	var closest := global_position
	if not from.is_equal_approx(global_position):
		closest = Geometry2D.get_closest_point_to_segment(player.global_position, from, global_position)
	if closest.distance_squared_to(player.global_position) > radius * radius \
			or not layout.has_clear_line(closest, player.global_position):
		return false
	player.take_damage(amount, "enemy")
	return true

func draw_sector(heading: Vector2, reach: float, half_angle: float, progress: float, color: Color) -> void:
	var rim := PackedVector2Array()
	for i in range(25):
		var ray := heading.rotated(lerpf(-half_angle, half_angle, i / 24.0))
		rim.append(ray * clear_reach(ray, reach))
	var area := PackedVector2Array([Vector2.ZERO])
	area.append_array(rim)
	_warning.draw_colored_polygon(area, Color(color, 0.07 + 0.15 * progress))
	_warning.draw_polyline(rim, Color(color, 0.50 + 0.43 * progress), 2.5)
	_warning.draw_line(Vector2.ZERO, rim[0], Color(color, 0.34 + 0.35 * progress), 1.5)
	_warning.draw_line(Vector2.ZERO, rim[-1], Color(color, 0.34 + 0.35 * progress), 1.5)

func draw_rush_path(heading: Vector2, distance: float, radius: float, progress: float, color: Color) -> void:
	var reach := clear_reach(heading, distance, hit_radius)
	if reach < distance:
		reach = maxf(0.0, reach - ArenaLayout.MOTION_MARGIN)
	var edge := heading.orthogonal() * radius
	var fill := Color(color, 0.07 + 0.14 * progress)
	var line := Color(color, 0.56 + 0.38 * progress)
	var outline_key := [layout, global_position, heading, reach, radius]
	if _rush_outline_key != outline_key:
		_rush_outline_key = outline_key
		_rush_outline_points = _rush_outline(heading, reach, radius)
	_warning.draw_colored_polygon(_rush_outline_points, fill)
	_warning.draw_polyline(_rush_outline_points, line, 1.5)
	_warning.draw_line(_rush_outline_points[-1], _rush_outline_points[0], line, 1.5)
	for mark in range(1, floori(reach / 23.0) + 1):
		var center := heading * (mark * 23.0)
		_warning.draw_polyline(PackedVector2Array([center - heading * 5.0 + edge * 0.30,
			center + heading * 3.0, center - heading * 5.0 - edge * 0.30]), line, 1.8)

func _rush_outline(heading: Vector2, reach: float, radius: float) -> PackedVector2Array:
	var vertices := PackedVector2Array(ArenaLayout.VERTICES)
	for entry in layout.obstacles:
		var rect: Rect2 = entry.rect
		vertices.append_array(PackedVector2Array([rect.position, rect.end,
			Vector2(rect.position.x, rect.end.y), Vector2(rect.end.x, rect.position.y)]))
	var angle := heading.angle()
	var near := _rush_cap(Vector2.ZERO, angle + PI / 2.0, radius, vertices)
	var far := _rush_cap(heading * reach, angle - PI / 2.0, radius, vertices)
	if is_zero_approx(reach):
		# With no travel the two semicircles share their endpoints.
		near.resize(near.size() - 1)
		far.resize(far.size() - 1)
		near.append_array(far)
		return near
	var cuts := PackedFloat64Array()
	var sections := ceili(reach / 8.0)
	for index in range(1, sections):
		cuts.append(reach * index / sections)
	for vertex in vertices:
		var along := heading.dot(vertex - global_position)
		if along > 0.02 and along < reach - 0.02:
			# Sample both sides of corners, where an edge can change abruptly.
			cuts.append(along - 0.02)
			cuts.append(along + 0.02)
	cuts.sort()
	var flank := heading.rotated(PI / 2.0)
	var other_edge := PackedVector2Array()
	var previous := -1.0
	for along in cuts:
		if is_equal_approx(along, previous):
			continue
		var center := heading * along
		near.append(_rush_rim_point(center, -flank, radius))
		other_edge.append(_rush_rim_point(center, flank, radius))
		previous = along
	near.append_array(far)
	other_edge.reverse()
	near.append_array(other_edge)
	return near

func _rush_cap(center: Vector2, start_angle: float, radius: float, vertices: PackedVector2Array) -> PackedVector2Array:
	var angles := PackedFloat64Array()
	for index in range(17):
		angles.append(PI * index / 16.0)
	for vertex in vertices:
		var offset := vertex - (global_position + center)
		if offset.length_squared() > radius * radius:
			continue
		var angle := fposmod(offset.angle() - start_angle, TAU)
		if angle > 0.001 and angle < PI - 0.001:
			angles.append(angle - 0.001)
			angles.append(angle + 0.001)
	angles.sort()
	var cap := PackedVector2Array()
	for angle in angles:
		var point := _rush_rim_point(center, Vector2.from_angle(start_angle + angle), radius)
		if cap.is_empty() or not cap[-1].is_equal_approx(point):
			cap.append(point)
	return cap

func _rush_rim_point(center: Vector2, ray: Vector2, radius: float) -> Vector2:
	# Like swept_attack, measure sight from the closest point on the path.
	var source := global_position + center
	var block := layout.first_block(source, source + ray * radius)
	return center + ray * radius * (block if block < INF else 1.0)

func draw_magic_guides(heading: Vector2, reach: float, shots: int, spread: float, progress: float,
		tint := Color("ed9fc9")) -> void:
	var color := Color(tint, 0.38 + 0.48 * progress)
	for i in range(shots):
		var ray := heading.rotated((i - (shots - 1) * 0.5) * spread)
		var extent := clear_reach(ray, reach, ArenaLayout.PROJECTILE_RADIUS)
		_warning.draw_dashed_line(Vector2.ZERO, ray * extent, color, 2.0, 7.0)
		_warning.draw_line(ray * minf(24.0, extent), ray * minf(46.0, extent), Color(color, 0.9), 3.5)
	_warning.draw_arc(Vector2.ZERO, hit_radius + 8.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 24, color, 2.5)

func fire_fan(heading: Vector2, shots: int, spread: float, cue := "skeleton_release") -> void:
	show_attack_release()
	for i in range(shots):
		var ray := heading.rotated((i - (shots - 1) * 0.5) * spread)
		projectile_requested.emit(global_position, ray, damage)
	sound_requested.emit(cue)

func add_hazard(origin: Vector2, end: Vector2, radius: float, delay: float, duration: float, amount: float) -> void:
	var hazard := EnemyHazard.new()
	hazard.setup(player, end - origin, radius, delay, duration, amount)
	if hazard_sound.is_valid():
		hazard.sound_requested.connect(hazard_sound)
	get_parent().add_child(hazard)
	hazard.global_position = origin
	_hazards.append(hazard)
	hazard.tree_exiting.connect(func(): _hazards.erase(hazard), CONNECT_ONE_SHOT)

func clear_owned_hazards() -> void:
	for hazard in _hazards:
		if is_instance_valid(hazard):
			hazard.process_mode = Node.PROCESS_MODE_DISABLED
			hazard.hide()
			hazard.queue_free()
	_hazards.clear()

func _draw() -> void:
	var scale_factor := hit_radius / 17.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_factor, scale_factor) * body_scale)
	draw_circle(Vector2(0, 1 if _sprite_frames else 13), 15, Color(0.02, 0.02, 0.04, 0.30))
	if art == null or art.texture == null:
		_draw_placeholder()
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp and alive and boss_stage_total == 0:
		var meter_y := (-51.0 if _sprite_frames else -31.0) * scale_factor
		draw_rect(Rect2(-18, meter_y, 36, 4), Color(0.12, 0.10, 0.15, 0.9))
		draw_rect(Rect2(-18, meter_y, 36 * maxf(0.0, hp / max_hp), 4), Color(0.92, 0.42, 0.35))

func _draw_placeholder() -> void:
	var flash := Color.WHITE if hit_flash <= 0.0 else Color(2.2, 2.2, 2.2)
	if config.get("corrupted", false):
		flash *= Color(1.2, 0.65, 1.9)
		draw_arc(Vector2.ZERO, 20.0, 0.0, TAU, 16, Color("cf77ec"), 2.0)
	match config.get("behavior", kind):
		"slime":
			draw_rect(Rect2(-14, -7, 28, 19), Color(0.38, 0.72, 0.48) * flash)
			draw_rect(Rect2(-10, -12, 20, 6), Color(0.50, 0.82, 0.56) * flash)
			draw_rect(Rect2(-11, 11, 22, 4), Color(0.24, 0.50, 0.37) * flash)
			draw_rect(Rect2(-7, -4, 3, 4), Color(0.08, 0.20, 0.18))
			draw_rect(Rect2(4, -4, 3, 4), Color(0.08, 0.20, 0.18))
		"goblin":
			draw_rect(Rect2(-9, 3, 18, 14), Color(0.40, 0.31, 0.24) * flash)
			draw_rect(Rect2(-12, -13, 24, 17), Color(0.49, 0.65, 0.34) * flash)
			draw_rect(Rect2(-17, -10, 6, 7), Color(0.49, 0.65, 0.34) * flash)
			draw_rect(Rect2(11, -10, 6, 7), Color(0.49, 0.65, 0.34) * flash)
			draw_rect(Rect2(-7, -7, 4, 3), Color(0.17, 0.16, 0.12))
			draw_rect(Rect2(3, -7, 4, 3), Color(0.17, 0.16, 0.12))
		"archer":
			draw_rect(Rect2(-9, 1, 18, 17), Color(0.31, 0.40, 0.35) * flash)
			draw_rect(Rect2(-8, -15, 16, 16), Color(0.86, 0.83, 0.70) * flash)
			draw_rect(Rect2(-6, -10, 4, 4), Color(0.12, 0.14, 0.16))
			draw_rect(Rect2(2, -10, 4, 4), Color(0.12, 0.14, 0.16))
			draw_rect(Rect2(-7, 5, 14, 3), Color(0.55, 0.62, 0.52))
			draw_arc(Vector2(11, 0), 17.0, -1.15, 1.15, 10, Color(0.55, 0.42, 0.26), 2.5)
		"ghost":
			draw_colored_polygon(PackedVector2Array([Vector2(-14, 15), Vector2(-11, -12),
				Vector2(-4, -19), Vector2(5, -19), Vector2(12, -11), Vector2(16, 15),
				Vector2(6, 9), Vector2(0, 16), Vector2(-6, 10)]),
				Color(0.62, 0.86, 0.96, body_alpha))
			draw_rect(Rect2(-7, -10, 4, 5), Color(0.08, 0.14, 0.28, body_alpha))
			draw_rect(Rect2(3, -10, 4, 5), Color(0.08, 0.14, 0.28, body_alpha))
		_:
			var robe := Color(0.39, 0.33, 0.52) if kind == "skeleton" else Color(0.60, 0.24, 0.31)
			draw_rect(Rect2(-11, 0, 22, 18), robe * flash)
			draw_rect(Rect2(-10, -16, 20, 17), Color(0.85, 0.82, 0.68) * flash)
			draw_rect(Rect2(-7, -10, 5, 5), Color(0.15, 0.12, 0.21))
			draw_rect(Rect2(2, -10, 5, 5), Color(0.15, 0.12, 0.21))
			draw_rect(Rect2(-4, -1, 8, 3), Color(0.35, 0.31, 0.32))
			if kind in ["elite", "lord"]:
				draw_rect(Rect2(-10, -22, 20, 5), Color(0.89, 0.65, 0.25))
				draw_rect(Rect2(-10, -26, 4, 6), Color(0.89, 0.65, 0.25))
				draw_rect(Rect2(6, -26, 4, 6), Color(0.89, 0.65, 0.25))
