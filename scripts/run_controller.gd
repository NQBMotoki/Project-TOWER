extends Node2D

const RewardManager = preload("res://scripts/reward_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const DeathEffect = preload("res://scripts/death_effect.gd")

enum State { MENU, TRANSITION, COMBAT, SAFE, REWARD, GAME_OVER, VICTORY }
const RECORD_READ_DISTANCE := 56.0

@export var floors: Array[FloorDefinition] = []
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
var current_floor: FloorDefinition:
	get:
		return floors[floor_number - 1]
var kills := 0
var elapsed := 0.0
var transition_remaining := 0.0
var wait_for_input := false
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
			if wait_for_input:
				ui.set_transition_ready(true)
			else:
				_begin_combat()
	if state in [State.COMBAT, State.SAFE] and is_instance_valid(player):
		var can_read := state == State.SAFE and current_floor.after_clear == FloorDefinition.AfterClear.OPTIONAL_RECORD
		ui.update_hud(player, floor_number, floors.size(), enemy_count, wave, total_waves, can_read, can_read and _near_record())

func _unhandled_input(event: InputEvent) -> void:
	if state == State.TRANSITION:
		if wait_for_input and transition_remaining <= 0.0 and not event.is_echo():
			if event.is_action_pressed("next") or event.is_action_pressed("interact") or event.is_action_pressed("close"):
				_begin_combat()
				get_viewport().set_input_as_handled()
		return
	if state != State.SAFE or event.is_echo():
		return
	var epilogue := current_floor.after_clear == FloorDefinition.AfterClear.EPILOGUE
	if lore_open:
		if event.is_action_pressed("interact") or event.is_action_pressed("close") or (epilogue and event.is_action_pressed("next")):
			lore_open = false
			ui.close_lore()
			get_viewport().set_input_as_handled()
			if epilogue:
				end_run(true)
			else:
				player.can_move = true
		return
	if event.is_action_pressed("interact") and _near_record():
		_open_lore()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("next"):
		_show_reward()
		get_viewport().set_input_as_handled()

func _near_record() -> bool:
	return current_floor.after_clear == FloorDefinition.AfterClear.OPTIONAL_RECORD and player.global_position.distance_to(current_floor.record_position) < RECORD_READ_DISTANCE

func show_menu() -> void:
	floor_manager.clear_enemies()
	_clear_projectiles()
	_clear_actors()
	state = State.MENU
	lore_open = false
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
	wait_for_input = false
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
	wait_for_input = current_floor.wait_for_confirmation
	ui.show_transition(floor_number, current_floor.tip_key, current_floor.entry_note_key, wait_for_input)

func _begin_combat() -> void:
	if state != State.TRANSITION:
		return
	wait_for_input = false
	state = State.COMBAT
	player.can_move = true
	player.can_attack = true
	ui.show_hud()
	floor_manager.start_floor(current_floor, player, actors)

func _on_floor_cleared() -> void:
	if state != State.COMBAT:
		return
	_clear_projectiles()
	player.can_attack = false
	match current_floor.after_clear:
		FloorDefinition.AfterClear.REWARD:
			_show_reward()
		FloorDefinition.AfterClear.OPTIONAL_RECORD:
			state = State.SAFE
			arena.lore_position = current_floor.record_position
			arena.lore_active = true
			arena.queue_redraw()
			player.can_move = true
		FloorDefinition.AfterClear.EPILOGUE:
			state = State.SAFE
			_open_lore()

func _open_lore() -> void:
	lore_open = true
	player.can_move = false
	ui.show_lore(current_floor.record_title_key, current_floor.record_body_key)

func _show_reward() -> void:
	if state not in [State.COMBAT, State.SAFE] or lore_open or current_floor.after_clear == FloorDefinition.AfterClear.EPILOGUE:
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
	if state in [State.COMBAT, State.SAFE]:
		end_run(false)

func end_run(victory: bool) -> void:
	if state in [State.GAME_OVER, State.VICTORY, State.MENU]:
		return
	state = State.VICTORY if victory else State.GAME_OVER
	player.can_move = false
	player.can_attack = false
	lore_open = false
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
	_spawn_projectile(origin, direction, damage, true, -1.0)

func _enemy_projectile(origin: Vector2, direction: Vector2, damage: float, shot_speed: float) -> void:
	_spawn_projectile(origin, direction, damage, false, shot_speed)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, friendly: bool, shot_speed := -1.0) -> void:
	if state != State.COMBAT:
		return
	var projectile := ProjectileScene.instantiate()
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, friendly, player, shot_speed)

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
