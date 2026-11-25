extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const PlayerStats = preload("res://data/player_stats.gd")
const UpgradeArt = preload("res://data/upgrade_art.gd")
const EditionArt = preload("res://data/edition_art.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const BoonFlash = preload("res://scripts/boon_flash.gd")
const SWORD_RANGE := 60.0
const SWORD_HALF_ANGLE := deg_to_rad(50.0)
const SWORD_FLASH_TIME := 0.16
const CAST_FLASH_TIME := 0.21
const INVULNERABILITY_TIME := 0.6
const HURT_POSE_TIME := 0.15
const BODY_ANCHOR := Vector2(0.0, -8.0)

var stats := PlayerStats.calculate({}, {})
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
var _fallback_hero: Texture2D
var _grip := Vector2.ZERO
var _has_animated_pose := false
var _body_direction := Vector2.DOWN
var _cinematic_velocity := Vector2.ZERO
var _cinematic_direction := Vector2.ZERO
var _startled := -1.0
var _story_pose := ""
var _story_progress := 0.0
var _weapon_behind_body := false
var boon_levels: Dictionary = {}
var attack_serial := 0
var boon_triggers: Dictionary = {}
var _hit_actions: Dictionary = {}
var _edge_action := -1
var _swing_range := SWORD_RANGE
var _swing_angle := SWORD_HALF_ANGLE

func _ready() -> void:
	body_sprite = get_node_or_null("HeroArt")
	if body_sprite == null:
		body_sprite = Sprite2D.new()
		add_child(body_sprite)
	if body_sprite.texture == null:
		body_sprite.texture = EditionArt.icon("hero")
	body_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_fallback_hero = body_sprite.texture
	if body_sprite.texture != null:
		_hero_scale = Vector2.ONE * (52.0 / body_sprite.texture.get_height())
	body_sprite.show_behind_parent = true
	motion.apply(body_sprite, BODY_ANCHOR, _hero_scale)
	weapon_sprite = get_node_or_null("WeaponArt")
	if weapon_sprite == null:
		weapon_sprite = Sprite2D.new()
		add_child(weapon_sprite)
	weapon_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	weapon_sprite.show_behind_parent = true
	_refresh_weapon_art()
	_animate_body(0.0, Vector2.ZERO)
	_animate_weapon()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	sword_flash = maxf(0.0, sword_flash - delta)
	cast_flash = maxf(0.0, cast_flash - delta)
	var origin := global_position
	if can_move:
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var speed_bonus: float = (0.12 if boon_triggers.get("kill_speed", 0.0) > 0.0 else 0.0)
		if boon_triggers.get("cast_speed", 0.0) > 0.0:
			speed_bonus += stats.aftercast_speed
		if boon_triggers.get("step_speed", 0.0) > 0.0:
			speed_bonus += 0.05 + 0.04 * boon_levels.get("AFTERSTEP", 0)
		global_position = layout.move_actor(global_position, movement * speed * (1.0 + speed_bonus) * delta, ArenaLayout.PLAYER_RADIUS)
		var cursor := get_global_mouse_position() - global_position
		if cursor.length_squared() > 16.0:
			aim = cursor.normalized()
	if can_move or can_attack:
		for timer in ["kill_speed", "cast_speed", "step_speed", "step_cooldown", "reprisal_cooldown", "echo_cooldown", "shards_time"]:
			if boon_triggers.has(timer):
				boon_triggers[timer] = maxf(0.0, boon_triggers[timer] - delta)
		for id in weapon_timers.keys():
			var remaining := maxf(0.0, weapon_timers[id] - delta)
			if remaining == 0.0:
				weapon_timers.erase(id)
			else:
				weapon_timers[id] = remaining
	if Input.is_action_pressed("attack"):
		attack()
	var velocity := (global_position - origin) / delta if delta > 0.0 else Vector2.ZERO
	if not _cinematic_direction.is_zero_approx():
		velocity = _cinematic_velocity
	if motion.advance_cycle(delta, velocity):
		sound_requested.emit("footstep")
	_animate_body(delta, velocity)
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
	attack_serial += 1
	weapon_timers[weapon] = PlayerStats.attack_interval(weapon, stats)
	var damage: float = stats[data.damage_type]
	if hp <= max_hp * 0.35:
		damage *= 1.0 + stats.low_health_attack
	if randf() < stats.critical:
		damage *= stats.critical_multiplier
	if data.range_type == "melee":
		_swing(damage)
	else:
		cast_flash = CAST_FLASH_TIME
		cast_direction = aim
		projectile_requested.emit(global_position, aim, damage)
		sound_requested.emit("magic")
		if stats.aftercast_speed > 0.0:
			boon_triggers.cast_speed = 0.9
	if boon_levels.has("AFTERSTEP") and boon_triggers.get("step_cooldown", 0.0) <= 0.0:
		boon_triggers.step_speed = 1.4
		boon_triggers.step_cooldown = 6.0

func _swing(damage: float) -> void:
	swing_origin = global_position
	swing_direction = aim
	sword_flash = SWORD_FLASH_TIME
	cast_flash = 0.0
	_swing_range = weapon_data().get("reach", SWORD_RANGE)
	_swing_angle = weapon_data().get("angle", SWORD_HALF_ANGLE)
	sound_requested.emit("sword")
	var targets := get_tree().get_nodes_in_group("enemies")
	targets.append_array(get_tree().get_nodes_in_group("breakables"))
	for target in targets:
		if not alive or not is_instance_valid(target) or not target.alive:
			continue
		var difference: Vector2 = target.global_position - global_position
		if difference.length() > _swing_range + target.hit_radius or absf(swing_direction.angle_to(difference)) > _swing_angle:
			continue
		if not layout.has_clear_line(global_position, target.global_position):
			continue
		apply_attack_hit(target, damage, difference.normalized() * 150.0, weapon, attack_serial)

func apply_attack_hit(target: Node2D, damage: float, impulse: Vector2, source_weapon: String, token: int) -> void:
	var melee: bool = PlayerStats.WEAPONS.get(source_weapon, {}).get("range_type") == "melee"
	if not target.is_in_group("enemies"):
		if target.take_damage(damage, impulse) and boon_levels.has("SHARDS"):
			boon_triggers.shards_time = 4.0
		return
	var origin := target.global_position
	var bonus := 0.0
	if boon_triggers.get("shards_time", 0.0) > 0.0:
		bonus += damage * 0.18
		boon_triggers.shards_time = 0.0
	if melee and boon_levels.has("EDGE") and _edge_action != token:
		boon_triggers.edges = int(boon_triggers.get("edges", 0) + 1) % 3
		if boon_triggers.edges == 0:
			bonus += stats.physical * 0.30
			_edge_action = token
			_boon_flash("edge", origin)
	if target.take_damage(damage + bonus, impulse) and melee and stats.lifesteal > 0.0:
		heal(stats.lifesteal)
	if _hit_actions.has(token):
		return
	_hit_actions[token] = true
	if _hit_actions.size() > 128:
		_hit_actions.erase(_hit_actions.keys()[0])
	if boon_triggers.get("reprisal", false):
		weapon_timers[source_weapon] = maxf(0.0, weapon_timers.get(source_weapon, 0.0) - 0.25)
		boon_triggers.reprisal = false
		boon_triggers.reprisal_cooldown = 8.0
	if not melee and (boon_levels.has("FRACTURE") or source_weapon == "U12"):
		_fork(origin, target, stats.magic * (0.35 if boon_levels.has("FRACTURE") else 0.27), impulse.normalized())
	if boon_levels.has("ECHO"):
		boon_triggers.echo_hits = mini(4, boon_triggers.get("echo_hits", 0) + 1)
		if boon_triggers.echo_hits == 4 and boon_triggers.get("echo_cooldown", 0.0) <= 0.0:
			boon_triggers.echo_hits = 0
			boon_triggers.echo_cooldown = 4.0
			_pulse(origin, target, stats.physical * 0.25 if melee else stats.magic * 0.25)

func _fork(origin: Vector2, direct: Node2D, amount: float, heading: Vector2) -> void:
	var nearest: Node2D
	var limit := 62.0 * 62.0
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == direct or not other.alive:
			continue
		var offset: Vector2 = other.global_position - origin
		var distance := offset.length_squared()
		if distance >= limit or offset.normalized().dot(heading) < 0.25:
			continue
		if layout.has_clear_line(origin, other.global_position):
			nearest = other
			limit = distance
	if nearest != null:
		_boon_flash("fork", origin, nearest.global_position - origin)
		nearest.take_damage(amount)

func _pulse(origin: Vector2, direct: Node2D, amount: float) -> void:
	_boon_flash("pulse", origin)
	for other in get_tree().get_nodes_in_group("enemies"):
		if is_instance_valid(other) and other != direct and other.alive and origin.distance_to(other.global_position) < 48.0:
			if layout.has_clear_line(origin, other.global_position):
				other.take_damage(amount)

func _boon_flash(kind: String, origin: Vector2, target_offset := Vector2.ZERO) -> void:
	var effect := BoonFlash.new()
	effect.kind = kind
	effect.destination = target_offset
	effect.top_level = true
	add_child(effect)
	effect.global_position = origin

func on_enemy_defeated() -> void:
	if boon_levels.has("AFTERBREATH"):
		boon_triggers.kill_speed = 2.0

func reset_floor_effects() -> void:
	boon_triggers.clear()
	_hit_actions.clear()
	_edge_action = -1

func take_damage(amount: float, source := "enemy") -> void:
	if not alive or invulnerability > 0.0:
		return
	if source == "enemy" and not boon_triggers.get("ward_used", false):
		var ward: float = [0.0, 0.30, 0.40][clampi(boon_levels.get("WARD", 0), 0, 2)]
		amount *= 1.0 - minf(0.55, ward + stats.first_guard)
		boon_triggers.ward_used = true
	if boon_levels.has("REPRISAL") and boon_triggers.get("reprisal_cooldown", 0.0) <= 0.0:
		boon_triggers.reprisal = true
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

func drink_potion() -> void:
	var recovery := 0.0
	if boon_levels.has("RECOVERY") and hp <= max_hp * 0.5 and not boon_triggers.get("recovery_used", false):
		recovery = 8.0
		boon_triggers.recovery_used = true
	heal(stats.potion_heal + recovery)

func set_loadout(equipment: Dictionary, corruption: Dictionary, boons := {}) -> void:
	weapon = equipment.get("weapon", "")
	boon_levels = boons
	stats = PlayerStats.calculate(equipment, corruption, boons)
	max_hp = stats.max_hp
	speed = stats.speed
	hp = minf(hp, max_hp)
	health_changed.emit(hp, max_hp)
	_refresh_weapon_art()
	queue_redraw()

func set_cinematic_pose(direction: Vector2, velocity: Vector2, startled := -1.0, pose := "", progress := 0.0) -> void:
	_cinematic_direction = direction
	_cinematic_velocity = velocity
	_startled = startled
	_story_pose = pose
	_story_progress = progress
	if is_instance_valid(body_sprite):
		_animate_body(0.0, velocity)

func clear_cinematic_pose() -> void:
	_cinematic_direction = Vector2.ZERO
	_cinematic_velocity = Vector2.ZERO
	_startled = -1.0
	_story_pose = ""

func _animate_body(delta: float, velocity: Vector2) -> void:
	var phase := ActorMotion.Phase.MOVE
	var moving := velocity.length_squared() > 25.0
	var progress := motion.walk_progress if moving else motion.idle_progress
	if not _cinematic_direction.is_zero_approx():
		_body_direction = _cinematic_direction
	elif moving:
		_body_direction = velocity.normalized()
	elif can_move:
		_body_direction = aim
	var direction := _body_direction
	if _cinematic_direction.is_zero_approx():
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
	var state: String = ActorMotion.PHASE_NAMES[phase]
	if phase == ActorMotion.Phase.MOVE and moving:
		state = "walk"
	if _startled >= 0.0:
		state = "startled"
		progress = _startled
	elif not _story_pose.is_empty():
		state = _story_pose
		progress = _story_progress
	var facing := ActorMotion.direction_name(direction)
	var id := "hero"
	if not weapon.is_empty():
		id = "hero_sword" if weapon_data().range_type == "melee" else "hero_staff"
	var index := ActorMotion.frame_index(progress, UpgradeArt.frame_count(id, facing, state))
	var frame := UpgradeArt.frame(id, facing, state, index)
	_has_animated_pose = frame != null
	if _has_animated_pose:
		body_sprite.texture = frame
		body_sprite.position = Vector2(0, -24)
		body_sprite.scale = Vector2.ONE
		body_sprite.flip_h = false
		body_sprite.rotation = 0.0
		_grip = UpgradeArt.grip(id, facing, state, index)
	else:
		body_sprite.texture = _fallback_hero
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
		direction = swing_direction.rotated(lerpf(-_swing_angle, _swing_angle, swing))
	elif weapon_data().range_type == "ranged" and cast_flash > 0.0:
		direction = cast_direction
	weapon_sprite.position = _grip if _has_animated_pose else direction * 11.0 + motion.offset * 0.55 + Vector2(0.0, 3.0)
	var behind := direction.y < -0.32
	if behind != _weapon_behind_body:
		move_child(weapon_sprite, body_sprite.get_index())
		_weapon_behind_body = behind
	weapon_sprite.rotation = direction.angle() + 0.84

func _damage_tint() -> Color:
	if invulnerability > 0.0 and int((INVULNERABILITY_TIME - invulnerability) * 16.0) % 2 == 0:
		return Color(1.0, 0.45, 0.42)
	return Color.WHITE

func _draw() -> void:
	var step := 0.0 if _has_animated_pose else motion.foot_stride
	var shadow_y := 1.0 if _has_animated_pose else 17.0
	draw_set_transform(Vector2(step * 1.3, shadow_y), 0.0, Vector2(1.0 - absf(step) * 0.08, 0.38))
	draw_circle(Vector2.ZERO, 15.0, Color(0.02, 0.02, 0.04, 0.45))
	draw_set_transform(Vector2.ZERO)
	if sword_flash > 0.0:
		var origin := swing_origin if swing_origin.is_finite() else global_position
		var center := to_local(origin)
		var edge_points := PackedVector2Array()
		var angle := swing_direction.angle()
		for i in range(17):
			var heading := Vector2.from_angle(angle + lerpf(-_swing_angle, _swing_angle, i / 16.0))
			var impact := layout.first_block(origin, origin + heading * _swing_range)
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
