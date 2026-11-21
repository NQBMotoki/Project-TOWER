extends Node2D

signal died
signal health_changed(current: float, maximum: float)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const GameData = preload("res://data/game_data.gd")
const SWORD_RANGE := 60.0
const SWORD_HALF_ANGLE := deg_to_rad(50.0)
const BASE_HP := 100.0

var max_hp := 100.0
var hp := 100.0
var speed := 185.0
var sword_damage := 12.0
var sword_cooldown := 0.42
var magic_damage := 20.0
var magic_cooldown := 2.4
var crit_chance := 0.05
var sword_heal := 0.0
var sword_timer := 0.0
var magic_timer := 0.0
var invulnerability := 0.0
var sword_flash := 0.0
var aim := Vector2.RIGHT
var can_move := false
var can_attack := false
var alive := true
var has_sword := true
var has_staff := true
var layout := ArenaLayout.new()

func _physics_process(delta: float) -> void:
	if not alive:
		return
	invulnerability = maxf(0.0, invulnerability - delta)
	sword_flash = maxf(0.0, sword_flash - delta)
	if can_move:
		var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		global_position = layout.move_actor(global_position, movement * speed * delta, ArenaLayout.PLAYER_RADIUS)
		var cursor := get_global_mouse_position() - global_position
		if cursor.length_squared() > 16.0:
			aim = cursor.normalized()
	if can_attack:
		sword_timer = maxf(0.0, sword_timer - delta)
		magic_timer = maxf(0.0, magic_timer - delta)
		if Input.is_action_pressed("attack") and sword_timer <= 0.0:
			attack_sword()
		if Input.is_action_pressed("magic") and magic_timer <= 0.0:
			cast_magic()
	queue_redraw()

func attack_sword() -> void:
	if not has_sword or not can_attack or not alive:
		return
	sword_timer = sword_cooldown
	sword_flash = 0.16
	sound_requested.emit("sword")
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy) or not enemy.alive:
			continue
		var difference: Vector2 = enemy.global_position - global_position
		if difference.length() <= SWORD_RANGE + enemy.hit_radius and absf(aim.angle_to(difference)) <= SWORD_HALF_ANGLE and layout.has_clear_line(global_position, enemy.global_position):
			var damage := sword_damage * (1.5 if randf() < crit_chance else 1.0)
			var killed: bool = enemy.take_damage(damage, difference.normalized() * 150.0)
			if killed and sword_heal > 0.0:
				heal(sword_heal)

func cast_magic() -> void:
	if not has_staff or not can_attack or not alive:
		return
	magic_timer = magic_cooldown
	var damage := magic_damage * (1.5 if randf() < crit_chance else 1.0)
	projectile_requested.emit(global_position + aim * 20.0, aim, damage)
	sound_requested.emit("magic")

func take_damage(amount: float) -> void:
	if not alive or invulnerability > 0.0:
		return
	hp = maxf(0.0, hp - amount)
	invulnerability = 0.6
	health_changed.emit(hp, max_hp)
	sound_requested.emit("hurt")
	if hp <= 0.0:
		alive = false
		died.emit()

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)
	health_changed.emit(hp, max_hp)

func set_equipment(equipment: Dictionary) -> void:
	has_sword = equipment.has("sword")
	has_staff = equipment.has("magic")
	max_hp = BASE_HP
	speed = 185.0
	sword_damage = 12.0
	sword_cooldown = 0.42
	magic_damage = 20.0
	magic_cooldown = 2.4
	crit_chance = 0.05
	sword_heal = 0.0
	for id in equipment.values():
		var item := GameData.upgrade(id)
		if not item.is_empty():
			_apply_equipment_effect(item)
	hp = minf(hp, max_hp)
	health_changed.emit(hp, max_hp)
	queue_redraw()

func _apply_equipment_effect(item: Dictionary) -> void:
	var value: float = item.value
	match item.type:
		"sword_damage": sword_damage += value
		"sword_cooldown": sword_cooldown = maxf(0.22, sword_cooldown * value)
		"magic_damage": magic_damage += value
		"magic_cooldown": magic_cooldown = maxf(1.0, magic_cooldown * value)
		"critical": crit_chance = minf(0.6, crit_chance + value)
		"lifesteal": sword_heal += value
		"health": max_hp += value
		"speed": speed *= value

func _draw() -> void:
	if sword_flash > 0.0:
		var points := PackedVector2Array([Vector2.ZERO])
		for i in range(9):
			var angle := aim.angle() - SWORD_HALF_ANGLE + (SWORD_HALF_ANGLE * 2.0 * i / 8.0)
			points.append(Vector2.from_angle(angle) * SWORD_RANGE)
		draw_colored_polygon(points, Color(0.95, 0.83, 0.52, 0.35))
		draw_arc(Vector2.ZERO, SWORD_RANGE, aim.angle() - SWORD_HALF_ANGLE, aim.angle() + SWORD_HALF_ANGLE, 12, Color(1.0, 0.9, 0.65, 0.9), 3.0)
	draw_ellipse_shadow()
	var tint := Color.WHITE
	if invulnerability > 0.0 and int(invulnerability * 16.0) % 2 == 0:
		tint = Color(1.0, 0.45, 0.42)
	draw_rect(Rect2(-10, -2, 20, 20), Color(0.20, 0.27, 0.38) * tint)
	draw_rect(Rect2(-8, 10, 6, 9), Color(0.10, 0.13, 0.20) * tint)
	draw_rect(Rect2(2, 10, 6, 9), Color(0.10, 0.13, 0.20) * tint)
	draw_rect(Rect2(-11, -4, 22, 13), Color(0.29, 0.43, 0.57) * tint)
	draw_rect(Rect2(-6, -5, 12, 10), Color(0.74, 0.78, 0.76) * tint)
	draw_rect(Rect2(-8, -19, 16, 15), Color(0.85, 0.73, 0.59) * tint)
	draw_rect(Rect2(-9, -20, 18, 7), Color(0.31, 0.24, 0.24) * tint)
	draw_rect(Rect2(-5, -11, 3, 3), Color(0.12, 0.16, 0.20))
	draw_rect(Rect2(3, -11, 3, 3), Color(0.12, 0.16, 0.20))
	if has_sword:
		draw_line(aim * 13.0, aim * 27.0, Color(0.90, 0.89, 0.76), 4.0)
		draw_line(aim * 12.0 + aim.orthogonal() * 5.0, aim * 12.0 - aim.orthogonal() * 5.0, Color(0.74, 0.55, 0.27), 3.0)
	if has_staff:
		draw_line(Vector2(-12, 11), Vector2(-18, -14), Color("b39173"), 3.0)
		draw_circle(Vector2(-18, -14), 3.0, Color("9ae4e2"))

func draw_ellipse_shadow() -> void:
	draw_circle(Vector2(0, 15), 15.0, Color(0.02, 0.02, 0.04, 0.35))
