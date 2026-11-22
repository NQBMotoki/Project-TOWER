extends Node2D

const GameData = preload("res://data/game_data.gd")
const EditionArt = preload("res://data/edition_art.gd")
const EnemyLoot = preload("res://scripts/enemy_loot.gd")
const FeaturesScene = preload("res://scenes/world/floor_features.tscn")
const FollowCamera = preload("res://scenes/world/follow_camera.tscn")
const Codex = preload("res://scripts/run_codex.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const PickupScene = preload("res://scenes/world/pickup.tscn")
const GhostScene = preload("res://scenes/world/knight_ghost.tscn")
const Ghost = preload("res://scripts/knight_ghost.gd")
const DeathEffect = preload("res://scripts/death_effect.gd")

enum State { MENU, OPENING, GROUNDS, TRANSITION, DIALOGUE, COMBAT, SAFE, ENDING, GAME_OVER, VICTORY }
const RUN_STATES := [State.OPENING, State.GROUNDS, State.TRANSITION, State.DIALOGUE, State.COMBAT, State.SAFE, State.ENDING]
const PLAY_STATES := [State.GROUNDS, State.COMBAT, State.SAFE]
const TRANSITIONS := [State.OPENING, State.TRANSITION, State.ENDING]
const LORD_DIALOGUE: Array[String] = ["DIALOGUE_F10_1", "DIALOGUE_F10_2", "DIALOGUE_F10_3", "DIALOGUE_F10_4"]
const LORD_SPEAKERS: Array[String] = ["ENEMY_LORD_NAME", "DIALOGUE_PLAYER", "ENEMY_LORD_NAME", "ENEMY_LORD_NAME"]
const AUTO_PICKUP_DISTANCE := 24.0
const TRANSITION_TIME := 2.1
const PICKUP_DISTANCE := 47.0

@export var floors: Array[FloorDefinition] = []
@onready var arena: Node2D = $Arena
@onready var grounds: Node2D = $TowerGrounds
@onready var entrance: Marker2D = $TowerGrounds/Entrance
@onready var camp: Marker2D = $TowerGrounds/Camp
@onready var actors: Node2D = $Actors
@onready var pickups: Node2D = $Pickups
@onready var projectiles: Node2D = $Projectiles
@onready var floor_manager: Node = $FloorManager
@onready var sound: Node = $Sound
@onready var loc: Node = $Localization
@onready var ui: CanvasLayer = $UI

var state := State.MENU
var player: Node2D
var inventory: RunInventory
var floor_number := 0
var current_floor: FloorDefinition:
	get:
		return floors[floor_number - 1]
var kills := 0
var elapsed := 0.0
var transition_remaining := 0.0
var enemy_count := 0
var wave := 0
var total_waves := 0
var features: Node2D
var camera: Camera2D
var codex_path := Codex.PATH
var codex: Codex
var pearl_available := false
var stair_notice_seen := false
var gate_armed := false
var lord_introduced := false
var ghost: Node2D
var ghost_seen := false
var lord_preview: Sprite2D
var seed := 0
var layouts: Array[ArenaLayout] = []
var save_path := RunSave.PATH
var saves: RunSave
var _resume: Dictionary = {}
var _preserve_recovery_backup := false
var _checkpoint: Dictionary = {}
var _next_wave := 0
var _wave_drops: Array[String] = []

func _ready() -> void:
	get_tree().auto_accept_quit = false
	saves = RunSave.new(save_path)
	codex = Codex.new(codex_path)
	var codex_error := codex.load_progress()
	features = FeaturesScene.instantiate()
	add_child(features)
	move_child(features, actors.get_index())
	features.drop_requested.connect(_add_pickup)
	features.sound_requested.connect(sound.play)
	ui.setup(loc)
	ui.start_pressed.connect(_request_start)
	ui.continue_pressed.connect(resume_run)
	ui.overwrite_pressed.connect(start_run)
	ui.menu_pressed.connect(show_menu)
	ui.quit_pressed.connect(_quit)
	ui.save_menu_pressed.connect(_save_and_menu)
	ui.close_requested.connect(_close_or_pause)
	ui.overlay_changed.connect(_sync_pause)
	ui.codex_pressed.connect(func(): ui.show_codex(codex))
	ui.dialogue_finished.connect(_finish_lord_dialogue)
	ui.inventory_requested.connect(_on_inventory_requested)
	ui.sound_preview_requested.connect(func(): sound.play("pickup", true))
	loc.preferences_changed.connect(_apply_preferences)
	loc.bindings_changed.connect(_update_hud)
	loc.language_changed.connect(_update_hud)
	loc.settings_write_failed.connect(func(): ui.notify("UI_SETTINGS_SAVE_ERROR"))
	floor_manager.floor_cleared.connect(_on_floor_cleared)
	floor_manager.enemy_killed.connect(_on_enemy_killed)
	floor_manager.enemy_encountered.connect(func(kind: String): _check_codex(codex.discover_enemy(kind)))
	floor_manager.before_wave.connect(_on_before_wave)
	floor_manager.between_waves.connect(_on_between_waves)
	floor_manager.counts_changed.connect(_on_counts_changed)
	floor_manager.projectile_requested.connect(_enemy_projectile)
	floor_manager.sound_requested.connect(sound.play)
	_apply_preferences()
	show_menu()
	if codex_error != OK and codex_error != ERR_FILE_NOT_FOUND:
		ui.notify("UI_CODEX_SAVE_ERROR")

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_quit()

func _process(delta: float) -> void:
	if state in RUN_STATES and state != State.ENDING:
		elapsed += delta
	if state in TRANSITIONS and transition_remaining > 0.0:
		transition_remaining = maxf(0.0, transition_remaining - delta)
		ui.set_transition_progress(TRANSITION_TIME - transition_remaining, transition_remaining <= 0.0)
		if transition_remaining <= 0.0:
			_finish_transition()
	if is_instance_valid(ghost):
		ghost.show_at(ghost.elapsed + delta)
		if ghost.elapsed >= Ghost.DURATION:
			_finish_ghost()
	if state in PLAY_STATES and not is_instance_valid(ghost):
		_update_world_interactions()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or state not in PLAY_STATES or is_instance_valid(ghost):
		return
	if event.is_action_pressed("inventory"):
		ui.show_inventory(inventory, player, codex)
	elif event.is_action_pressed("quick_item") and inventory.potion_on_quick_slot:
		_drink_potion()
	elif event.is_action_pressed("interact"):
		_interact()
	else:
		return
	get_viewport().set_input_as_handled()

func _sync_pause() -> void:
	get_tree().paused = state in RUN_STATES and ui.top_overlay() != null

func _close_or_pause() -> void:
	var top: Control = ui.top_overlay()
	if top != null:
		if state == State.DIALOGUE and top == ui.dialogue:
			ui.show_pause(false)
		else:
			ui.pop_overlay()
	elif state in RUN_STATES:
		ui.show_pause(state == State.COMBAT and floor_manager.wave_in_progress())

func _apply_preferences() -> void:
	arena.high_quality = loc.high_quality
	grounds.high_quality = loc.high_quality
	arena.queue_redraw()
	grounds.queue_redraw()
	sound.set_volumes(loc.master_volume, loc.effects_volume, loc.music_volume)

func _request_start() -> void:
	if state == State.MENU and not _resume.is_empty():
		ui.show_overwrite()
	else:
		start_run()

func show_menu() -> void:
	state = State.MENU
	_clear_world()
	grounds.hide()
	arena.hide()
	sound.set_music("grounds")
	ui.notify("")
	_preserve_recovery_backup = false
	var latest := saves.load_latest()
	_resume = RunSave.prepare_resume(latest.get("data"), floors)
	if _resume.is_empty():
		var backup := saves.load_backup()
		_resume = RunSave.prepare_resume(backup.get("data"), floors)
		if not _resume.is_empty():
			_preserve_recovery_backup = true
			ui.notify("UI_SAVE_RECOVERED")
		elif latest.error != ERR_FILE_NOT_FOUND or backup.error != ERR_FILE_NOT_FOUND:
			ui.notify("UI_SAVE_INVALID")
	ui.show_menu(not _resume.is_empty())
	_sync_pause()

func start_run() -> void:
	_clear_world()
	_resume.clear()
	_preserve_recovery_backup = false
	ui.notify("")
	seed = randi()
	floor_number = 0
	kills = 0
	elapsed = 0.0
	ghost_seen = false
	inventory = RunInventory.new()
	layouts.clear()
	pearl_available = false
	stair_notice_seen = false
	lord_introduced = false
	for i in range(floors.size()):
		var layout := ArenaLayout.new()
		layout.generate(floors[i], _rng("layout", i), i + 1)
		layouts.append(layout)
	_create_player()
	var fixed_pickups: Dictionary = grounds.pickups()
	for id in fixed_pickups:
		_add_pickup(id, fixed_pickups[id])
	player.position = grounds.get_node("Start").position
	_setup_world()
	_enter_transition(State.OPENING, TRANSITION_TIME)
	_save_run()

func _create_player() -> void:
	player = PlayerScene.instantiate()
	player.set_loadout(inventory.equipped, inventory.corruption)
	actors.add_child(player)
	camera = FollowCamera.instantiate()
	player.add_child(camera)
	player.died.connect(_on_player_died)
	player.sound_requested.connect(sound.play)
	player.projectile_requested.connect(_player_projectile)

func _enter_grounds() -> void:
	state = State.GROUNDS
	grounds.show()
	features.show()
	actors.show()
	pickups.show()
	player.can_move = true
	player.can_attack = true
	features.enabled = true
	sound.set_music("grounds")
	_guide_weapons()
	ui.show_hud()

func _interact() -> void:
	var near := _near_object()
	if near != null and near.get_parent() == pickups:
		_collect(near)
		return
	if state == State.GROUNDS:
		if near == entrance:
			_try_enter()
		elif near == camp:
			_check_codex(codex.discover_item("LORE_CAMP"))
			_read_book("LORE_CAMP")
	elif state == State.SAFE and pearl_available and _at(ArenaLayout.ALTAR_POSITION, ArenaLayout.LANDMARK_RADIUS):
		pearl_available = false
		inventory.absorb_blood_bead()
		features.set_landmark_state(true, false)
		sound.play("pearl_pickup")
		ui.notify("UI_PEARL_ABSORBED", {"count": inventory.blood_beads}, 2.5)
		_save_run()

func _update_world_interactions() -> void:
	for node in pickups.get_children():
		if _at(node.position, AUTO_PICKUP_DISTANCE):
			_collect(node)
	if state == State.GROUNDS and not inventory.has_weapon() and not ghost_seen and _at(entrance.position, 58.0):
		_show_ghost()
	if state != State.SAFE:
		return
	var summit := floor_number == floors.size()
	var gate_position := ArenaLayout.EXIT_POSITION if summit else ArenaLayout.STAIRS_POSITION
	var at_gate := _at(gate_position, ArenaLayout.LANDMARK_RADIUS)
	if not at_gate:
		gate_armed = true
	if not summit and pearl_available and not stair_notice_seen and _at(gate_position, 92.0):
		stair_notice_seen = true
		ui.notify("UI_STAIR_FORFEIT", {}, 3.0)
	if not at_gate or not gate_armed:
		return
	if summit:
		_enter_transition(State.ENDING, TRANSITION_TIME)
		_save_run()
	else:
		floor_number += 1
		_start_floor_transition()

func _at(point: Vector2, radius: float) -> bool:
	return player.position.distance_squared_to(point) < radius * radius

func _near_object() -> Node2D:
	var closest: Node2D
	var distance := PICKUP_DISTANCE
	var nearby := pickups.get_children()
	if state == State.GROUNDS:
		nearby.append_array([entrance, camp])
	for node in nearby:
		var gap: float = node.global_position.distance_to(player.global_position)
		if gap < distance:
			distance = gap
			closest = node
	return closest

func _try_enter() -> void:
	if inventory.has_weapon():
		floor_number = 1
		_start_floor_transition()
	elif not ghost_seen:
		_show_ghost()
	else:
		ui.notify("UI_NEED_WEAPONS", {}, 2.5)

func _show_ghost() -> void:
	ghost = GhostScene.instantiate()
	ghost.position = entrance.position + Vector2(0, 42)
	for node in pickups.get_children():
		if node.item_id in GameData.STARTERS.values():
			ghost.targets.append(node.global_position)
	actors.add_child(ghost)
	player.can_move = false
	player.can_attack = false
	sound.play("ghost")

func _finish_ghost() -> void:
	ghost.queue_free()
	ghost = null
	ghost_seen = true
	player.can_move = true
	player.can_attack = true
	_guide_weapons()
	_save_run()

func _guide_weapons() -> void:
	for node in pickups.get_children():
		node.guided = ghost_seen and node.item_id in GameData.STARTERS.values()

func _start_floor_transition() -> void:
	_clear_pickups()
	_clear_projectiles()
	_checkpoint.clear()
	_wave_drops.clear()
	_next_wave = 0
	_on_counts_changed(0, 0, current_floor.waves.size())
	ui.clear_pickup_notices()
	pearl_available = false
	stair_notice_seen = false
	player.position = ArenaLayout.PLAYER_START
	_setup_world()
	_enter_transition(State.TRANSITION, TRANSITION_TIME)
	_save_run()

func _enter_transition(phase: State, remaining: float) -> void:
	state = phase
	player.can_move = false
	player.can_attack = false
	features.enabled = false
	transition_remaining = remaining
	match phase:
		State.OPENING:
			grounds.hide()
			features.hide()
			actors.hide()
			pickups.hide()
			sound.set_music("grounds")
			ui.show_special_transition("TRANSITION_GROUNDS_TITLE", "TRANSITION_GROUNDS_TIP")
		State.ENDING:
			sound.set_music("ending")
			ui.show_special_transition("TRANSITION_END_TITLE", "TRANSITION_END_TIP")
		_:
			sound.set_music("lord" if floor_number == floors.size() else "tower")
			ui.show_transition(floor_number, current_floor.tip_key, current_floor.entry_note_key)
	ui.set_transition_progress(TRANSITION_TIME - remaining, remaining <= 0.0)

func _finish_transition() -> void:
	match state:
		State.OPENING:
			_enter_grounds()
			_save_run()
		State.TRANSITION:
			if ui.status_key == "UI_STAIR_FORFEIT":
				ui.notify("")
			if floor_number == floors.size() and not lord_introduced:
				_enter_dialogue()
			else:
				_enter_combat()
			_save_run()
		State.ENDING:
			end_run(true)

func _setup_world() -> void:
	features.show()
	actors.show()
	pickups.show()
	grounds.visible = floor_number == 0
	arena.visible = floor_number > 0
	arena.floor_number = floor_number
	arena.layout = ArenaLayout.new() if floor_number == 0 else layouts[floor_number - 1]
	player.layout = arena.layout
	features.setup(player, player.layout, floor_number, seed)
	camera.reset_smoothing()
	arena.queue_redraw()

func _enter_dialogue() -> void:
	state = State.DIALOGUE
	player.can_move = false
	player.can_attack = false
	features.enabled = false
	sound.set_music("lord")
	_check_codex(codex.discover_enemy("lord"))
	lord_preview = Sprite2D.new()
	lord_preview.name = "LordPreview"
	lord_preview.texture = EditionArt.icon("lord")
	lord_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if lord_preview.texture != null:
		var size := lord_preview.texture.get_size()
		lord_preview.scale = Vector2.ONE * (ArenaLayout.ELITE_RADIUS * 2.7 / maxf(size.x, size.y))
	lord_preview.position = ArenaLayout.LORD_INTRO_POSITION
	actors.add_child(lord_preview)
	ui.show_hud()
	ui.show_dialogue(LORD_DIALOGUE, LORD_SPEAKERS)

func _finish_lord_dialogue() -> void:
	if state != State.DIALOGUE:
		return
	_remove_lord_preview()
	lord_introduced = true
	_enter_combat()
	_save_run()

func _remove_lord_preview() -> void:
	if is_instance_valid(lord_preview):
		lord_preview.hide()
		lord_preview.queue_free()
		lord_preview = null

func _enter_combat() -> void:
	state = State.COMBAT
	player.can_move = floor_number < floors.size()
	player.can_attack = player.can_move
	features.enabled = true
	sound.set_music("lord" if floor_number == floors.size() else "tower")
	ui.show_hud()
	floor_manager.start_floor(current_floor, player, actors, _next_wave, hash([seed, floor_number]))
	if not _wave_drops.is_empty():
		floor_manager.wait_for_wave = 0.0

func _on_before_wave(index: int) -> void:
	_next_wave = index
	if _wave_drops.is_empty():
		var excluded: Array = inventory.owned.duplicate()
		for node in pickups.get_children():
			excluded.append(node.item_id)
		var available := EnemyLoot.available_equipment(excluded)
		for order in range(current_floor.waves[index].size()):
			var rng := _rng("loot", floor_number, index, order)
			_wave_drops.append(EnemyLoot.drop_for_roll(rng.randi_range(0, 99), available, rng))
	floor_manager.wave_drops.assign(_wave_drops)
	_checkpoint = _snapshot()
	_write_checkpoint(_checkpoint)
	player.can_move = true
	player.can_attack = true

func _on_between_waves(next_index: int) -> void:
	_next_wave = next_index
	_wave_drops.clear()
	_checkpoint.clear()
	_clear_projectiles()
	# The strike may still have lifesteal to apply after the death signal.
	_save_run.call_deferred()

func _on_floor_cleared() -> void:
	if state != State.COMBAT:
		return
	_clear_projectiles()
	_checkpoint.clear()
	_wave_drops.clear()
	_next_wave = 0
	for position in current_floor.clear_pickups:
		_add_pickup(current_floor.clear_pickups[position], position)
	pearl_available = floor_number < floors.size()
	_enter_safe()
	if pearl_available:
		sound.play("pearl_form")
	_save_run.call_deferred()

func _enter_safe() -> void:
	state = State.SAFE
	var gate_position := ArenaLayout.EXIT_POSITION if floor_number == floors.size() else ArenaLayout.STAIRS_POSITION
	gate_armed = not _at(gate_position, ArenaLayout.LANDMARK_RADIUS)
	player.can_move = true
	player.can_attack = true
	features.enabled = true
	features.set_landmark_state(true, pearl_available)
	sound.set_music("ending" if floor_number == floors.size() else "tower")
	_on_counts_changed(0, current_floor.waves.size(), current_floor.waves.size())
	ui.show_hud()

func _add_pickup(id: String, position: Vector2) -> void:
	if id not in GameData.STACKABLE:
		if id in inventory.owned:
			return
		for pickup in pickups.get_children():
			if pickup.item_id == id:
				return
	var node := PickupScene.instantiate()
	node.item_id = id
	node.position = position
	pickups.add_child(node)

func _collect(node: Node2D) -> void:
	var id: String = node.item_id
	if not inventory.add(id):
		return
	pickups.remove_child(node)
	node.queue_free()
	sound.play("pickup")
	player.set_loadout(inventory.equipped, inventory.corruption)
	_check_codex(codex.discover_item(id))
	ui.notify_pickup(id)
	if _checkpoint.is_empty():
		_save_run()

func _check_codex(error: Error) -> void:
	if error != OK:
		ui.notify("UI_CODEX_SAVE_ERROR", {}, 3.0)

func _read_book(id: String) -> void:
	if GameData.is_book(id) and (id in codex.items or (inventory != null and id in inventory.owned)):
		_check_codex(codex.mark_read(id))
		ui.show_lore(id)

func _on_inventory_requested(operation: String, id: String) -> void:
	if ui.top_overlay() != ui.bag:
		return
	match operation:
		"equip":
			inventory.equip(id)
			player.set_loadout(inventory.equipped, inventory.corruption)
		"unequip":
			inventory.unequip(id)
			player.set_loadout(inventory.equipped, inventory.corruption)
		"read":
			_read_book(id)
		"quick":
			inventory.potion_on_quick_slot = not inventory.potion_on_quick_slot
		"drink":
			_drink_potion()
		"enhance":
			if inventory.enhance(id):
				player.set_loadout(inventory.equipped, inventory.corruption)
				sound.play("corrupt", true)
				ui.notify("UI_CORRUPTION_SUCCESS", {}, 2.0)
		"craft":
			if inventory.craft_potion():
				_check_codex(codex.discover_item("POTION"))
				sound.play("craft", true)
				ui.notify("UI_CRAFT_SUCCESS", {}, 2.0)
	if state in PLAY_STATES and operation not in ["read", "drink"]:
		_save_run()
	ui.refresh_inventory()
	_update_hud()

func _drink_potion() -> void:
	if inventory.drink(player):
		sound.play("potion", get_tree().paused)
		ui.notify("UI_DRANK_POTION", {}, 2.0)
		_save_run()
	elif inventory.count("POTION") > 0:
		ui.notify("UI_HP_FULL", {}, 2.0)
	else:
		ui.notify("UI_NO_POTIONS", {}, 2.0)

func _update_hud() -> void:
	if not is_instance_valid(player) or not ui.hud.visible:
		return
	var hint := ""
	var nearby := ""
	var near: Node2D
	if state == State.GROUNDS:
		hint = loc.text("UI_GROUND_READY" if inventory.has_weapon() else "UI_GROUND_GOAL")
	elif state == State.SAFE:
		if floor_number == floors.size():
			hint = loc.text("UI_EXIT_OPEN")
		else:
			hint = loc.text("UI_FLOOR_CLEARED" if pearl_available else "UI_ALTAR_EMPTY")
	if state in PLAY_STATES and not is_instance_valid(ghost):
		near = _near_object()
	if state == State.SAFE and pearl_available and near == null and _at(ArenaLayout.ALTAR_POSITION, ArenaLayout.LANDMARK_RADIUS):
		nearby = loc.text("UI_ALTAR_NEAR", {"interact": loc.binding("interact")})
	if near != null:
		var interact: String = loc.binding("interact")
		if near == entrance:
			nearby = loc.text("UI_GATE_NEAR", {"interact": interact})
		elif near == camp:
			nearby = loc.text("UI_CAMP_NEAR", {"interact": interact})
		else:
			nearby = loc.text("UI_PICKUP_NEAR", {"interact": interact, "item": loc.text(GameData.name_key(near.item_id))})
	ui.update_hud(player, inventory, floor_number, floors.size(), enemy_count, wave, total_waves, hint, nearby)

func _on_player_died() -> void:
	if state in PLAY_STATES:
		end_run(false)

func end_run(victory: bool) -> void:
	if state not in RUN_STATES:
		return
	state = State.VICTORY if victory else State.GAME_OVER
	player.can_move = false
	player.can_attack = false
	floor_manager.clear_enemies()
	features.enabled = false
	_clear_projectiles()
	_clear_pickups()
	sound.set_music("ending" if victory else "")
	var error := saves.invalidate()
	ui.show_result(victory, floor_number, kills, elapsed, inventory.owned)
	ui.notify("" if error == OK else "UI_SAVE_INVALIDATE_ERROR")

func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	if not enemy.drop_id.is_empty():
		_add_pickup(enemy.drop_id, enemy.position)
	sound.play("death")
	var effect := DeathEffect.new()
	effect.position = enemy.position
	actors.add_child(effect)

func _on_counts_changed(remaining: int, wave_number: int, wave_count: int) -> void:
	enemy_count = remaining
	wave = wave_number
	total_waves = wave_count

func _player_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	if player.layout.has_clear_line(player.global_position, origin, ArenaLayout.PROJECTILE_RADIUS):
		_spawn_projectile(origin, direction, damage, true)

func _enemy_projectile(origin: Vector2, direction: Vector2, damage: float, shot_speed: float, travel_range: float) -> void:
	_spawn_projectile(origin, direction, damage, false, shot_speed, travel_range)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, friendly: bool, shot_speed := -1.0, travel_range := -1.0) -> void:
	if state not in PLAY_STATES or (not friendly and state != State.COMBAT):
		return
	var projectile := ProjectileScene.instantiate()
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, friendly, player, shot_speed, travel_range)

func _clear_projectiles() -> void:
	_clear_children(projectiles)

func _clear_pickups() -> void:
	_clear_children(pickups)

func _clear_children(parent: Node) -> void:
	for node in parent.get_children():
		parent.remove_child(node)
		node.queue_free()

func _clear_world() -> void:
	floor_manager.clear_enemies()
	features.clear()
	_clear_projectiles()
	_clear_pickups()
	_clear_children(actors)
	ui.bag.inventory = null
	player = null
	ghost = null
	lord_preview = null
	_checkpoint.clear()
	_wave_drops.clear()
	_next_wave = 0
	transition_remaining = 0.0
	_on_counts_changed(0, 0, 0)

func _rng(purpose: String, floor: int, wave_index := 0, order := 0) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, purpose, floor, wave_index, order])
	return rng

func _snapshot() -> Dictionary:
	var floor_layouts := []
	for layout in layouts:
		floor_layouts.append(layout.obstacles)
	var ground := []
	for node in pickups.get_children():
		ground.append({"id": node.item_id, "position": node.position})
	return {
		"seed": seed, "phase": State.keys()[state].to_lower(), "floor": floor_number,
		"next_wave": _next_wave, "wave_drops": _wave_drops.duplicate(), "layouts": floor_layouts,
		"ground": ground, "inventory": inventory.snapshot(), "features": features.snapshot(),
		"pearl_available": pearl_available, "stair_notice_seen": stair_notice_seen, "lord_introduced": lord_introduced,
		"kills": kills, "elapsed": elapsed, "ghost_seen": ghost_seen, "transition": transition_remaining,
		"player": {"position": entrance.position if is_instance_valid(ghost) else player.position,
			"hp": player.hp, "aim": player.aim, "weapon_timers": player.weapon_timers.duplicate(),
			"invulnerability": player.invulnerability, "swing_direction": player.swing_direction,
			"sword_flash": player.sword_flash},
	}

func _write_checkpoint(data: Dictionary) -> bool:
	var error := saves.write(data, _preserve_recovery_backup)
	if error != OK:
		ui.notify("UI_SAVE_WRITE_ERROR")
	else:
		_preserve_recovery_backup = false
		if ui.status_key == "UI_SAVE_WRITE_ERROR":
			ui.notify("")
	return error == OK

func _save_run() -> bool:
	if state not in RUN_STATES:
		return true
	if state == State.COMBAT and not _checkpoint.is_empty():
		return _write_checkpoint(_checkpoint)
	return _write_checkpoint(_snapshot())

func _save_and_menu() -> void:
	if _save_run():
		show_menu()

func _quit() -> void:
	ui.settings.commit()
	if _save_run():
		get_tree().quit()
	elif ui.top_overlay() == null:
		ui.show_pause(state == State.COMBAT and floor_manager.wave_in_progress())

func resume_run() -> void:
	if state != State.MENU or _resume.is_empty() or ui.top_overlay() != null:
		return
	var data: Dictionary = _resume.data
	_clear_world()
	ui.notify("")
	seed = data.seed
	floor_number = data.floor
	inventory = _resume.inventory
	layouts.assign(_resume.layouts)
	kills = data.kills
	elapsed = data.elapsed
	ghost_seen = data.ghost_seen
	_next_wave = data.next_wave
	_wave_drops.assign(data.wave_drops)
	pearl_available = data.pearl_available
	stair_notice_seen = data.stair_notice_seen
	lord_introduced = data.lord_introduced
	_create_player()
	player.position = data.player.position
	player.hp = data.player.hp
	player.aim = data.player.aim
	player.weapon_timers = data.player.weapon_timers.duplicate()
	player.invulnerability = data.player.invulnerability
	player.sword_flash = data.player.sword_flash
	player.swing_direction = data.player.swing_direction
	for entry in data.ground:
		_add_pickup(entry.id, entry.position)
	_setup_world()
	features.restore(data.features)
	match data.phase:
		"opening":
			_enter_transition(State.OPENING, data.transition)
		"grounds":
			_enter_grounds()
		"transition":
			_enter_transition(State.TRANSITION, data.transition)
		"dialogue":
			_enter_dialogue()
		"combat":
			_enter_combat()
		"safe":
			_enter_safe()
		"ending":
			features.set_landmark_state(true, false)
			_enter_transition(State.ENDING, data.transition)
	_resume.clear()
	_update_hud()
