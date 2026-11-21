extends Node2D

signal died(enemy: Node)
@warning_ignore("unused_signal")
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const GameData = preload("res://data/game_data.gd")
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
var shot_speed := 230.0
var alive := true
var active := true
var drop_id := ""
var layout: ArenaLayout
var _route := PackedVector2Array()
var _route_target := Vector2.INF
var _route_remaining := 0.0
var _sight_position := Vector2.ZERO
var _sight_remaining := 0.0

func setup(enemy_kind: String, target: Node2D) -> void:
	kind = enemy_kind
	player = target
	layout = target.layout
	config = GameData.ENEMIES[kind]
	max_hp = config.hp
	hp = max_hp
	speed = config.speed
	damage = config.damage
	cooldown = config.cooldown
	shot_speed = float(config.get("shot_speed", 230.0))
	attack_timer = cooldown * 0.5
	if kind == "elite":
		hit_radius = ArenaLayout.ELITE_RADIUS

func set_spawn_delay(value: float) -> void:
	spawn_delay = maxf(0.0, value)
	spawn_delay_total = maxf(0.01, spawn_delay)

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if not active or not alive or not is_instance_valid(player) or not player.alive:
		return
	spawn_delay = maxf(0.0, spawn_delay - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	_route_remaining -= delta
	_sight_remaining -= delta
	# A spawning enemy holds still so staggered waves read as separate arrivals.
	if spawn_delay <= 0.0:
		_behavior(delta)
	move_by(knockback * delta)
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	queue_redraw()

func _behavior(_delta: float) -> void:
	pass

func move_by(offset: Vector2) -> void:
	global_position = layout.move_actor(global_position, offset, hit_radius)

func sees_player(clearance := 0.0) -> bool:
	return layout.has_clear_line(global_position, player.global_position, clearance)

func move_towards(target: Vector2, distance: float) -> void:
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
	hp -= amount
	knockback = impulse
	hit_flash = 0.14
	sound_requested.emit("hit")
	if hp <= 0.0:
		alive = false
		died.emit(self)
		queue_free()
		return true
	return false

func _draw() -> void:
	var scale_factor := 1.45 if kind == "elite" else 1.0
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(scale_factor, scale_factor) * body_scale)
	draw_circle(Vector2(0, 13), 15, Color(0.02, 0.02, 0.04, 0.30))
	var flash := Color.WHITE if hit_flash <= 0.0 else Color(2.2, 2.2, 2.2)
	match kind:
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
		_:
			var robe := Color(0.39, 0.33, 0.52) if kind == "skeleton" else Color(0.60, 0.24, 0.31)
			draw_rect(Rect2(-11, 0, 22, 18), robe * flash)
			draw_rect(Rect2(-10, -16, 20, 17), Color(0.85, 0.82, 0.68) * flash)
			draw_rect(Rect2(-7, -10, 5, 5), Color(0.15, 0.12, 0.21))
			draw_rect(Rect2(2, -10, 5, 5), Color(0.15, 0.12, 0.21))
			draw_rect(Rect2(-4, -1, 8, 3), Color(0.35, 0.31, 0.32))
			if kind == "elite":
				draw_rect(Rect2(-10, -22, 20, 5), Color(0.89, 0.65, 0.25))
				draw_rect(Rect2(-10, -26, 4, 6), Color(0.89, 0.65, 0.25))
				draw_rect(Rect2(6, -26, 4, 6), Color(0.89, 0.65, 0.25))
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp and alive:
		draw_rect(Rect2(-18, -31 * scale_factor, 36, 4), Color(0.12, 0.10, 0.15, 0.9))
		draw_rect(Rect2(-18, -31 * scale_factor, 36 * maxf(0.0, hp / max_hp), 4), Color(0.92, 0.42, 0.35))
	if spawn_delay > 0.0:
		var progress := clampf(1.0 - spawn_delay / spawn_delay_total, 0.0, 1.0)
		draw_arc(Vector2.ZERO, hit_radius + 16.0 - 9.0 * progress, 0.0, TAU, 24, Color(0.98, 0.82, 0.51, 0.25 + 0.35 * progress), 2.0)
		draw_arc(Vector2.ZERO, hit_radius + 7.0, 0.0, TAU, 24, Color(0.98, 0.82, 0.51, 0.55), 2.0)
