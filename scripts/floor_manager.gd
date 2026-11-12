extends Node

signal floor_cleared
signal enemy_killed(enemy: Node)
signal counts_changed(remaining: int, wave: int, total_waves: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float)
signal sound_requested(kind: String)

const GameData = preload("res://data/game_data.gd")
const SCENES := {
	"slime": preload("res://scenes/enemies/slime.tscn"),
	"goblin": preload("res://scenes/enemies/goblin.tscn"),
	"skeleton": preload("res://scenes/enemies/skeleton.tscn"),
	"elite": preload("res://scenes/enemies/elite.tscn"),
}
var floor_number := 1
var wave_index := -1
var waves: Array = []
var enemies: Array = []
var player: Node2D
var actors: Node2D
var wait_for_wave := -1.0
var cleared := false
var running := false

func start_floor(index: int, target: Node2D, parent: Node2D) -> void:
	clear_enemies()
	floor_number = index
	player = target
	actors = parent
	waves = GameData.FLOORS[index - 1]
	wave_index = -1
	cleared = false
	running = true
	wait_for_wave = 0.65
	counts_changed.emit(0, 0, waves.size())

func _process(delta: float) -> void:
	if not running or cleared or wait_for_wave < 0.0:
		return
	wait_for_wave -= delta
	if wait_for_wave <= 0.0:
		wait_for_wave = -1.0
		_spawn_wave()

func _spawn_wave() -> void:
	wave_index += 1
	if wave_index >= waves.size():
		_finish_floor()
		return
	for kind in waves[wave_index]:
		var enemy = SCENES[kind].instantiate()
		enemy.setup(kind, player)
		enemy.position = _spawn_position()
		enemy.died.connect(_on_enemy_died)
		enemy.projectile_requested.connect(func(origin, direction, damage): projectile_requested.emit(origin, direction, damage))
		enemy.sound_requested.connect(func(sound): sound_requested.emit(sound))
		actors.add_child(enemy)
		enemies.append(enemy)
	counts_changed.emit(enemies.size(), wave_index + 1, waves.size())

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
	counts_changed.emit(enemies.size(), wave_index + 1, waves.size())
	if floor_number == 5 and enemy.kind == "elite":
		_finish_floor()
	elif enemies.is_empty():
		if wave_index + 1 < waves.size():
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
