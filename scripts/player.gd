extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const PlayerStats = preload("res://data/player_stats.gd")
const EditionArt = preload("res://data/edition_art.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const SWORD_RANGE := 60.0
const SWORD_HALF_ANGLE := deg_to_rad(50.0)
const SWORD_FLASH_TIME := 0.16
const CAST_FLASH_TIME := 0.21
const INVULNERABILITY_TIME := 0.6
const HURT_POSE_TIME := 0.15
const BODY_ANCHOR := Vector2(0.0, -8.0)

var stats := PlayerStats.BASE.duplicate()
var max_hp: float = PlayerStats.BASE.max_hp
var hp: float = PlayerStats.BASE.max_hp
var speed: float = PlayerStats.BASE.speed
var weapon := ""
var weapon_timers: Dictionary = {}
var invulnerability := 0.0
var sword_flash := 0.0
var swing_origin := Vector2.INF
var swing_direction := Vector2.RIGHT
var cast_flash := 0.0
var cast_direction := Vector2.RIGHT
var aim := Vector2.RIGHT
var can_move := false
var can_attack := false
var alive := true
var layout := ArenaLayout.new()
var body_sprite: Sprite2D
var weapon_sprite: Sprite2D
var motion := ActorMotion.new()
var _hero_scale := Vector2.ONE

func _ready() -> void:
	body_sprite = get_node_or_null("HeroArt")
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		add_child(body_sprite)
	if body_sprite.texture == null:
		body_sprite.texture = EditionArt.icon("hero")
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if body_sprite.texture != null:
		_hero_scale = Vector2.ONE * (52.0 / body_sprite.texture.get_height())
	body_sprite.show_behind_parent = true
	motion.apply(body_sprite, BODY_ANCHOR, _hero_scale)
	weapon_sprite = get_node_or_null("WeaponArt")
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		add_child(weapon_sprite)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_refresh_weapon_art()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	sword_flash = maxf(0.0, sword_flash - delta)
	cast_flash = maxf(0.0, cast_flash - delta)
	var origin := global_position
	if can_move:
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		global_position = layout.move_actor(global_position, movement * speed * delta, ArenaLayout.PLAYER_RADIUS)
		var cursor := get_global_mouse_position() - global_position
		if cursor.length_squared() > 16.0:
			aim = cursor.normalized()
	if can_move or can_attack:
		for id in weapon_timers.keys():
			var remaining := maxf(0.0, weapon_timers[id] - delta)
			if remaining == 0.0:
				weapon_timers.erase(id)
			else:
				weapon_timers[id] = remaining
	if Input.is_action_pressed("attack"):
		attack()
	_animate_body(delta, (global_position - origin) / delta if delta > 0.0 else Vector2.ZERO)
	_animate_weapon()
	body_sprite.modulate = _damage_tint()
	queue_redraw()

func weapon_data() -> Dictionary:
	return PlayerStats.WEAPONS.get(weapon, {})

func attack_ready_in() -> float:
	return weapon_timers.get(weapon, 0.0)

func attack() -> void:
	if not can_attack or not alive or weapon.is_empty() or attack_ready_in() > 0.0:
		return
	var data := weapon_data()
	weapon_timers[weapon] = PlayerStats.attack_interval(weapon, stats)
	var damage: float = stats[data.damage_type]
	if randf() < stats.critical:
		damage *= PlayerStats.CRITICAL_MULTIPLIER
	if data.range_type == "melee":
		_swing(damage)
	else:
		cast_flash = CAST_FLASH_TIME
		cast_direction = aim
		projectile_requested.emit(global_position, aim, damage)
		sound_requested.emit("magic")

func _swing(damage: float) -> void:
	swing_origin = global_position
	swing_direction = aim
	sword_flash = SWORD_FLASH_TIME
	cast_flash = 0.0
	sound_requested.emit("sword")
	var targets := get_tree().get_nodes_in_group("enemies")
	targets.append_array(get_tree().get_nodes_in_group("breakables"))
	for target in targets:
		if not alive or not is_instance_valid(target) or not target.alive:
			continue
		var difference: Vector2 = target.global_position - global_position
		if difference.length() > SWORD_RANGE + target.hit_radius or absf(swing_direction.angle_to(difference)) > SWORD_HALF_ANGLE:
			continue
		if not layout.has_clear_line(global_position, target.global_position):
			continue
		var is_enemy: bool = target.is_in_group("enemies")
		var destroyed: bool = target.take_damage(damage, difference.normalized() * 150.0)
		if destroyed and stats.lifesteal > 0.0 and is_enemy:
			heal(stats.lifesteal)

func take_damage(amount: float) -> void:
	if not alive or invulnerability > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invulnerability = INVULNERABILITY_TIME
	health_changed.emit(hp, max_hp)
	sound_requested.emit("hurt")
	if hp <= 0.0:
		alive = false
		died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func set_loadout(equipment: Dictionary, corruption: Dictionary) -> void:
	weapon = equipment.get("weapon", "")
	stats = PlayerStats.calculate(equipment, corruption)
	max_hp = stats.max_hp
	speed = stats.speed
	hp = minf(hp, max_hp)
	health_changed.emit(hp, max_hp)
	_refresh_weapon_art()
	queue_redraw()

func _animate_body(delta: float, velocity: Vector2) -> void:
	var phase := ActorMotion.Phase.MOVE
	var progress := 0.0
	var direction := aim
	if invulnerability > INVULNERABILITY_TIME - HURT_POSE_TIME:
		phase = ActorMotion.Phase.HURT
		progress = (INVULNERABILITY_TIME - invulnerability) / HURT_POSE_TIME
	elif cast_flash > 0.0 or sword_flash > 0.0:
		var age := 1.0 - (cast_flash / CAST_FLASH_TIME if cast_flash > 0.0 else sword_flash / SWORD_FLASH_TIME)
		var impact_fraction := 0.42
		if age < impact_fraction:
			phase = ActorMotion.Phase.STRIKE
			progress = age / impact_fraction
		else:
			phase = ActorMotion.Phase.RECOVERY
			progress = inverse_lerp(impact_fraction, 1.0, age)
		direction = cast_direction if cast_flash > 0.0 else swing_direction
	motion.advance(delta, velocity, direction, phase, progress)
	motion.apply(body_sprite, BODY_ANCHOR, _hero_scale)

func _refresh_weapon_art() -> void:
	if weapon_sprite == null:
		return
	weapon_sprite.texture = EditionArt.icon(weapon)
	weapon_sprite.visible = weapon_sprite.texture != null
	if not weapon_sprite.visible:
		return
	var source_size := weapon_sprite.texture.get_size()
	var is_sword: bool = weapon_data().range_type == "melee"
	var grip := Vector2(0.23, 0.77) if is_sword else Vector2(0.39, 0.60)
	weapon_sprite.offset = source_size * (Vector2(0.5, 0.5) - grip)
	weapon_sprite.scale = Vector2.ONE * ((34.0 if is_sword else 40.0) / source_size.y)
	_animate_weapon()

func _animate_weapon() -> void:
	if not weapon_sprite.visible:
		return
	var direction := aim
	if weapon_data().range_type == "melee" and sword_flash > 0.0:
		var swing := clampf(1.0 - sword_flash / SWORD_FLASH_TIME, 0.0, 1.0)
		direction = swing_direction.rotated(lerpf(-SWORD_HALF_ANGLE, SWORD_HALF_ANGLE, swing))
	elif weapon_data().range_type == "ranged" and cast_flash > 0.0:
		direction = cast_direction
	weapon_sprite.position = direction * 11.0 + motion.offset * 0.55 + Vector2(0.0, 3.0)
	weapon_sprite.rotation = direction.angle() + 0.84

func _damage_tint() -> Color:
	if invulnerability > 0.0 and int((INVULNERABILITY_TIME - invulnerability) * 16.0) % 2 == 0:
		return Color(1.0, 0.45, 0.42)
	return Color.WHITE

func _draw() -> void:
	var step := motion.foot_stride
	draw_set_transform(Vector2(step * 1.3, 17.0), 0.0, Vector2(1.0 - absf(step) * 0.08, 0.38))
	draw_circle(Vector2.ZERO, 15.0, Color(0.02, 0.02, 0.04, 0.45))
	draw_set_transform(Vector2.ZERO)
	if sword_flash > 0.0:
		var origin := swing_origin if swing_origin.is_finite() else global_position
		var center := to_local(origin)
		var edge_points := PackedVector2Array()
		var angle := swing_direction.angle()
		for i in range(17):
			var heading := Vector2.from_angle(angle + lerpf(-SWORD_HALF_ANGLE, SWORD_HALF_ANGLE, i / 16.0))
			var impact := layout.first_block(origin, origin + heading * SWORD_RANGE)
			var distance := SWORD_RANGE if impact == INF else SWORD_RANGE * impact
			edge_points.append(center + heading * distance)
		var area := PackedVector2Array([center])
		area.append_array(edge_points)
		var fade := clampf(sword_flash / SWORD_FLASH_TIME, 0.0, 1.0)
		draw_colored_polygon(area, Color(0.95, 0.83, 0.52, 0.35 * fade))
		draw_polyline(edge_points, Color(1.0, 0.9, 0.65, 0.9 * fade), 3.0)
	if cast_flash > 0.0:
		var fade := cast_flash / CAST_FLASH_TIME
		draw_arc(cast_direction * 17.0, lerpf(6.0, 16.0, 1.0 - fade), 0.0, TAU, 20, Color(0.58, 0.94, 1.0, fade * 0.75), 2.0)
	var tint := _damage_tint()
	if body_sprite == null or body_sprite.texture == null:
		draw_rect(Rect2(-10, -2, 20, 20), Color(0.20, 0.27, 0.38) * tint)
		draw_rect(Rect2(-8, 10, 6, 9), Color(0.10, 0.13, 0.20) * tint)
		draw_rect(Rect2(2, 10, 6, 9), Color(0.10, 0.13, 0.20) * tint)
		draw_rect(Rect2(-11, -4, 22, 13), Color(0.29, 0.43, 0.57) * tint)
		draw_rect(Rect2(-6, -5, 12, 10), Color(0.74, 0.78, 0.76) * tint)
		draw_rect(Rect2(-8, -19, 16, 15), Color(0.85, 0.73, 0.59) * tint)
		draw_rect(Rect2(-9, -20, 18, 7), Color(0.31, 0.24, 0.24) * tint)
		draw_rect(Rect2(-5, -11, 3, 3), Color(0.12, 0.16, 0.20))
		draw_rect(Rect2(3, -11, 3, 3), Color(0.12, 0.16, 0.20))
	if weapon_sprite != null and weapon_sprite.visible:
		return
	var data := weapon_data()
	if data.get("range_type") == "melee":
		draw_line(aim * 13.0, aim * 27.0, Color(0.90, 0.89, 0.76), 4.0)
		draw_line(aim * 12.0 + aim.orthogonal() * 5.0, aim * 12.0 - aim.orthogonal() * 5.0, Color(0.74, 0.55, 0.27), 3.0)
	elif data.get("range_type") == "ranged":
		var grip := aim * 13.0 + aim.orthogonal() * 7.0
		var tip := aim * 27.0 + aim.orthogonal() * 2.0
		draw_line(grip, tip, Color("b39173"), 4.0)
		draw_circle(tip, 4.0, Color("9ae4e2"))
