extends Node2D

const GameData = preload("res://data/game_data.gd")
const RewardManager = preload("res://scripts/reward_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DeathEffect = preload("res://scripts/death_effect.gd")

enum State { MENU, TRANSITION, COMBAT, SAFE, REWARD, GAME_OVER, VICTORY }
@onready var arena: Node2D = $Arena
@onready var actors: Node2D = $Actors
@onready var projectiles: Node2D = $Projectiles
@onready var floor_manager: Node = $FloorManager
@onready var sound: Node = $Sound
@onready var loc: Node = $Localization
@onready var ui: CanvasLayer = $UI
var state := State.MENU
var player: Node2D
var floor_number := 1
var kills := 0
var elapsed := 0.0
var transition_remaining := 0.0
var enemy_count := 0
var wave := 0
var total_waves := 0
var lore_open := false
var current_choices: Array = []

func _ready() -> void:
	randomize()
	ui.setup(loc)
	ui.start_pressed.connect(start_run)
	ui.restart_pressed.connect(start_run)
	ui.menu_pressed.connect(show_menu)
	ui.quit_pressed.connect(func(): get_tree().quit())
	ui.upgrade_selected.connect(_on_upgrade_selected)
	floor_manager.floor_cleared.connect(_on_floor_cleared)
	floor_manager.enemy_killed.connect(_on_enemy_killed)
	floor_manager.counts_changed.connect(_on_counts_changed)
	floor_manager.projectile_requested.connect(_enemy_projectile)
	floor_manager.sound_requested.connect(sound.play)
	show_menu()

func _process(delta: float) -> void:
	if state in [State.TRANSITION, State.COMBAT, State.SAFE, State.REWARD]:
		elapsed += delta
	if state == State.TRANSITION:
		transition_remaining -= delta
		if transition_remaining <= 0.0:
			_begin_combat()
	if state in [State.COMBAT, State.SAFE] and is_instance_valid(player):
		var near := false
		if state == State.SAFE and GameData.LORE.has(floor_number):
			near = player.global_position.distance_to(GameData.LORE[floor_number].position) < 56.0
		ui.update_hud(player, floor_number, enemy_count, wave, total_waves, state == State.SAFE, near)

func _unhandled_input(event: InputEvent) -> void:
	if state != State.SAFE or event.is_echo():
		return
	if lore_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("close"):
			lore_open = false
			ui.close_lore()
			player.can_move = true
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("interact") and GameData.LORE.has(floor_number):
		if player.global_position.distance_to(GameData.LORE[floor_number].position) < 56.0:
			lore_open = true
			player.can_move = false
			ui.show_lore(GameData.LORE[floor_number])
			get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next"):
		_show_reward()
		get_viewport().set_input_as_handled()

func show_menu() -> void:
	floor_manager.clear_enemies()
	_clear_projectiles()
	_clear_actors()
	state = State.MENU
	arena.floor_number = 1
	arena.lore_active = false
	arena.queue_redraw()
	ui.show_menu()

func start_run() -> void:
	floor_manager.clear_enemies()
	_clear_projectiles()
	_clear_actors()
	floor_number = 1
	kills = 0
	elapsed = 0.0
	lore_open = false
	current_choices.clear()
	player = PlayerScene.instantiate()
	player.position = Vector2(640, 365)
	actors.add_child(player)
	player.died.connect(_on_player_died)
	player.sound_requested.connect(sound.play)
	player.projectile_requested.connect(_player_projectile)
	_start_transition()

func _start_transition() -> void:
	state = State.TRANSITION
	player.can_move = false
	player.can_attack = false
	player.position = Vector2(640, 365)
	arena.floor_number = floor_number
	arena.lore_active = false
	arena.queue_redraw()
	transition_remaining = 2.1
	ui.show_transition(floor_number)

func _begin_combat() -> void:
	if state != State.TRANSITION:
		return
	state = State.COMBAT
	player.can_move = true
	player.can_attack = true
	ui.show_hud()
	floor_manager.start_floor(floor_number, player, actors)

func _on_floor_cleared() -> void:
	if state != State.COMBAT:
		return
	_clear_projectiles()
	player.can_attack = false
	if floor_number == 5:
		end_run(true)
	elif GameData.LORE.has(floor_number):
		state = State.SAFE
		arena.lore_active = true
		arena.queue_redraw()
		player.can_move = true
	else:
		_show_reward()

func _show_reward() -> void:
	if state not in [State.COMBAT, State.SAFE] or lore_open:
		return
	state = State.REWARD
	player.can_move = false
	player.can_attack = false
	arena.lore_active = false
	current_choices = RewardManager.generate_choices(3)
	ui.show_reward(current_choices)

func _on_upgrade_selected(item: Dictionary) -> void:
	if state != State.REWARD or not current_choices.has(item):
		return
	player.apply_upgrade(item)
	current_choices.clear()
	sound.play("choose")
	floor_number += 1
	_start_transition()

func _on_player_died() -> void:
	if state == State.COMBAT:
		end_run(false)

func end_run(victory: bool) -> void:
	if state in [State.GAME_OVER, State.VICTORY, State.MENU]:
		return
	state = State.VICTORY if victory else State.GAME_OVER
	player.can_move = false
	player.can_attack = false
	floor_manager.clear_enemies()
	_clear_projectiles()
	arena.lore_active = false
	ui.show_result(victory, floor_number, kills, elapsed, player.upgrades)

func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	sound.play("death")
	var effect := DeathEffect.new()
	effect.position = enemy.position
	actors.add_child(effect)

func _on_counts_changed(remaining: int, wave_number: int, wave_count: int) -> void:
	enemy_count = remaining
	wave = wave_number
	total_waves = wave_count

func _player_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	_spawn_projectile(origin, direction, damage, true)

func _enemy_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	_spawn_projectile(origin, direction, damage, false)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, friendly: bool) -> void:
	if state != State.COMBAT:
		return
	var projectile := ProjectileScene.instantiate()
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, friendly, player)

func _clear_projectiles() -> void:
	for projectile in projectiles.get_children():
		projectile.set_physics_process(false)
		projectile.queue_free()

func _clear_actors() -> void:
	for actor in actors.get_children():
		actor.set_process(false)
		actor.set_physics_process(false)
		actor.queue_free()
	player = null
