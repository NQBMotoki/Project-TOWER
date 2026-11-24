extends Node

signal floor_cleared
signal enemy_killed(enemy: Node)
signal enemy_encountered(kind: String)
signal counts_changed(remaining: int, wave: int, total_waves: int)
signal before_wave(index: int)
signal between_waves(next_index: int)
signal projectile_requested(origin: Vector2, direction: Vector2, damage: float, shot_speed: float, travel_range: float)
signal sound_requested(kind: String)

const CompleteEnemies = preload("res://data/complete_enemies.gd")
const SCENES := {
	"slime": preload("res://scenes/enemies/slime.tscn"),
	"goblin": preload("res://scenes/enemies/goblin.tscn"),
	"skeleton": preload("res://scenes/enemies/skeleton.tscn"),
	"archer": preload("res://scenes/enemies/archer.tscn"),
	"elite": preload("res://scenes/enemies/elite.tscn"),
	"ghost": preload("res://scenes/enemies/ghost.tscn"),
	"lord": preload("res://scenes/enemies/lord.tscn"),
}
const WAVE_TIMING := CompleteEnemies.WAVE_TIMING
const SPAWN_DELAY := WAVE_TIMING.spawn_warning
const SPAWN_STAGGER := WAVE_TIMING.spawn_stagger
var floor: FloorDefinition
var wave_index := -1
var enemies: Array = []
var player: Node2D
var actors: Node2D
var wait_for_wave := -1.0
var cleared := false
var running := false
var spawn_seed := 0
var wave_drops: Array[String] = []

func start_floor(definition: FloorDefinition, target: Node2D, parent: Node2D, next_index: int, seed: int) -> void:
	clear_enemies()
	floor = definition
	player = target
	actors = parent
	wave_index = next_index - 1
	spawn_seed = seed
	cleared = false
	running = true
	wait_for_wave = WAVE_TIMING.first_wave_delay
	counts_changed.emit(0, next_index, floor.waves.size())

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
	before_wave.emit(wave_index)
	var rotation := _spawn_rotation(spawn_seed, wave_index)
	var order := 0
	for kind in waves[wave_index]:
		var behavior: String = CompleteEnemies.ENEMIES[kind].behavior
		var enemy = SCENES.get(kind, SCENES[behavior]).instantiate()
		enemy.setup(kind, player)
		enemy.position = ArenaLayout.LORD_INTRO_POSITION if kind == "lord" else _spawn_position(rotation)
		enemy.drop_id = wave_drops[order] if order < wave_drops.size() else ""
		# Staggered arrival keeps four enemies from acting on the same frame.
		enemy.set_spawn_delay(SPAWN_DELAY + SPAWN_STAGGER * float(order))
		enemy.died.connect(_on_enemy_died)
		enemy.projectile_requested.connect(_on_enemy_projectile.bind(enemy))
		enemy.sound_requested.connect(sound_requested.emit)
		enemy.hazard_sound = sound_requested.emit
		actors.add_child(enemy)
		enemies.append(enemy)
		enemy_encountered.emit(kind)
		order += 1
	counts_changed.emit(enemies.size(), wave_index + 1, waves.size())

func _on_enemy_projectile(origin: Vector2, direction: Vector2, damage: float, enemy: Node) -> void:
	projectile_requested.emit(origin, direction, damage, enemy.shot_speed, enemy.config.reach)

func _spawn_rotation(seed: int, index: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, index])
	return rng.randi_range(0, ArenaLayout.SPAWN_POINTS.size() - 1)

func _spawn_position(rotation: int) -> Vector2:
	var candidates := ArenaLayout.SPAWN_POINTS
	var best: Vector2 = candidates[rotation]
	var best_score := -1.0
	for i in range(candidates.size()):
		var point: Vector2 = candidates[(i + rotation) % candidates.size()]
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
	counts_changed.emit(enemies.size(), wave_index + 1, floor.waves.size())
	if not enemies.is_empty():
		return
	_clear_hazards()
	if wave_index + 1 < floor.waves.size():
		wait_for_wave = WAVE_TIMING.between_waves_delay
		between_waves.emit(wave_index + 1)
	else:
		_finish_floor()

func _finish_floor() -> void:
	if cleared:
		return
	cleared = true
	running = false
	floor_cleared.emit()

func clear_enemies() -> void:
	_clear_hazards()
	running = false
	wait_for_wave = -1.0
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.alive = false
			enemy.remove_from_group("enemies")
			enemy.queue_free()
	enemies.clear()

func _clear_hazards() -> void:
	if not is_instance_valid(actors):
		return
	for hazard in get_tree().get_nodes_in_group("enemy_hazards"):
		if hazard.get_parent() == actors:
			hazard.process_mode = Node.PROCESS_MODE_DISABLED
			hazard.hide()
			hazard.queue_free()

func wave_in_progress() -> bool:
	return running and not enemies.is_empty()
