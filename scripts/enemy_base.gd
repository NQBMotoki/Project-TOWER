extends Node2D

signal died(enemy: Node)
@warning_ignore("unused_signal")
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const GameData = preload("res://data/game_data.gd")
const ARENA := Rect2(112, 124, 1056, 472)
var kind := "slime"
var player: Node2D
var hp := 1.0
var max_hp := 1.0
var speed := 1.0
var damage := 1.0
var cooldown := 1.0
var attack_timer := 0.0
var spawn_delay := 0.85
var hit_flash := 0.0
var knockback := Vector2.ZERO
var hit_radius := 17.0
var alive := true
var active := true

func setup(enemy_kind: String, target: Node2D) -> void:
	kind = enemy_kind
	player = target
	var stats: Dictionary = GameData.ENEMIES[kind]
	max_hp = stats.hp
	hp = max_hp
	speed = stats.speed
	damage = stats.damage
	cooldown = stats.cooldown
	attack_timer = cooldown * 0.5
	if kind == "elite":
		hit_radius = 25.0

func _ready() -> void:
	add_to_group("enemies")

func _physics_process(delta: float) -> void:
	if not active or not alive or not is_instance_valid(player) or not player.alive:
		return
	spawn_delay = maxf(0.0, spawn_delay - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	attack_timer = maxf(0.0, attack_timer - delta)
	_behavior(delta)
	position += knockback * delta
	knockback = knockback.move_toward(Vector2.ZERO, 500.0 * delta)
	position.x = clampf(position.x, ARENA.position.x + hit_radius, ARENA.end.x - hit_radius)
	position.y = clampf(position.y, ARENA.position.y + hit_radius, ARENA.end.y - hit_radius)
	queue_redraw()

func _behavior(_delta: float) -> void:
	pass

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
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * scale_factor)
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
		draw_arc(Vector2.ZERO, hit_radius + 7, 0, TAU, 24, Color(0.98, 0.82, 0.51, 0.55), 2.0)
