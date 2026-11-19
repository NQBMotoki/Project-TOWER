extends Node

signal floor_cleared
signal enemy_killed(enemy: Node)
signal counts_changed(remaining: int, wave: int, total_waves: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float, shot_speed: float)
signal sound_requested(kind: String)

const SCENES := {
	"slime": preload("res://scenes/enemies/slime.tscn"),
	"goblin": preload("res://scenes/enemies/goblin.tscn"),
	"skeleton": preload("res://scenes/enemies/skeleton.tscn"),
	"archer": preload("res://scenes/enemies/archer.tscn"),
	"elite": preload("res://scenes/enemies/elite.tscn"),
}
const SPAWN_DELAY := 0.85
const SPAWN_STAGGER := 0.35
var floor: FloorDefinition
var wave_index := -1
var enemies: Array = []
var player: Node2D
var actors: Node2D
var wait_for_wave := -1.0
var cleared := false
var running := false

func start_floor(definition: FloorDefinition, target: Node2D, parent: Node2D) -> void:
	clear_enemies()
	floor = definition
	player = target
	actors = parent
	wave_index = -1
	cleared = false
	running = true
	wait_for_wave = 0.65
	counts_changed.emit(0, 0, floor.waves.size())

func _process(delta: float) -> void:
	if not running or cleared or wait_for_wave < 0.0:
		return
	wait_for_wave -= delta
	if wait_for_wave <= 0.0:
		wait_for_wave = -1.0
		_spawn_wave()

func _spawn_wave() -> void:
	var waves := floor.waves
	wave_index += 1
	if wave_index >= waves.size():
		_finish_floor()
		return
	var order := 0
	for kind in waves[wave_index]:
		var enemy = SCENES[kind].instantiate()
		enemy.setup(kind, player)
		enemy.position = _spawn_position()
		# Staggered arrival keeps four enemies from acting on the same frame.
		enemy.set_spawn_delay(SPAWN_DELAY + SPAWN_STAGGER * float(order))
		enemy.died.connect(_on_enemy_died)
		enemy.projectile_requested.connect(_on_enemy_projectile.bind(enemy))
		enemy.sound_requested.connect(func(sound): sound_requested.emit(sound))
		actors.add_child(enemy)
		enemies.append(enemy)
		order += 1
	counts_changed.emit(enemies.size(), wave_index + 1, waves.size())

func _on_enemy_projectile(origin: Vector2, direction: Vector2, damage: float, enemy: Node) -> void:
	projectile_requested.emit(origin, direction, damage, enemy.shot_speed)

func _spawn_position() -> Vector2:
	var candidates := [Vector2(160, 165), Vector2(640, 165), Vector2(1120, 165), Vector2(160, 555), Vector2(640, 555), Vector2(1120, 555)]
	candidates.shuffle()
	var best: Vector2 = candidates[0]
	var best_score := -1.0
	for point in candidates:
		var score: float = point.distance_to(player.global_position)
		for enemy in enemies:
			if is_instance_valid(enemy):
				score = minf(score, point.distance_to(enemy.global_position) * 1.8)
		if score > best_score:
			best = point
			best_score = score
	return best

func _on_enemy_died(enemy: Node) -> void:
	if cleared or not running or not enemies.has(enemy):
		return
	enemies.erase(enemy)
	enemy_killed.emit(enemy)
	var target_defeated: bool = enemy.kind == floor.clear_on_enemy_defeat
	if target_defeated:
		clear_enemies()
	counts_changed.emit(enemies.size(), wave_index + 1, floor.waves.size())
	if target_defeated:
		_finish_floor()
	elif enemies.is_empty():
		if wave_index + 1 < floor.waves.size():
			wait_for_wave = 0.9
		else:
			_finish_floor()

func _finish_floor() -> void:
	if cleared:
		return
	cleared = true
	running = false
	floor_cleared.emit()

func clear_enemies() -> void:
	running = false
	wait_for_wave = -1.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.alive = false
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	enemies.clear()
