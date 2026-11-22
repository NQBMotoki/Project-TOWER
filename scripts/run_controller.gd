extends Node2D

const GameData = preload("res://data/game_data.gd")
const RewardManager = preload("res://scripts/reward_manager.gd")
const PlayerScene = preload("res://scenes/player/player.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const PickupScene = preload("res://scenes/world/pickup.tscn")
const GhostScene = preload("res://scenes/world/knight_ghost.tscn")
const Ghost = preload("res://scripts/knight_ghost.gd")
const DeathEffect = preload("res://scripts/death_effect.gd")

enum State { MENU, GROUNDS, TRANSITION, COMBAT, SAFE, REWARD, EPILOGUE, GAME_OVER, VICTORY }
const RUN_STATES := [State.GROUNDS, State.TRANSITION, State.COMBAT, State.SAFE, State.REWARD, State.EPILOGUE]
const BAG_STATES := [State.GROUNDS, State.TRANSITION, State.COMBAT, State.SAFE, State.REWARD]
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
var current_choices: Array[String] = []
var ghost: Node2D
var ghost_seen := false
var seed := 0
var layouts: Array[ArenaLayout] = []
var save_path := RunSave.PATH
var saves: RunSave
var _resume: Dictionary = {}
var _checkpoint: Dictionary = {}
var _next_wave := 0
var _wave_drops: Array[String] = []

func _ready() -> void:
	get_tree().auto_accept_quit = false
	saves = RunSave.new(save_path)
	ui.setup(loc)
	ui.start_pressed.connect(_request_start)
	ui.continue_pressed.connect(resume_run)
	ui.overwrite_pressed.connect(start_run)
	ui.menu_pressed.connect(show_menu)
	ui.quit_pressed.connect(_quit)
	ui.save_menu_pressed.connect(_save_and_menu)
	ui.close_requested.connect(_close_or_pause)
	ui.overlay_changed.connect(_sync_pause)
	ui.reward_selected.connect(_on_reward_selected)
	ui.inventory_requested.connect(_on_inventory_requested)
	ui.sound_preview_requested.connect(func(): sound.play("pickup", true))
	loc.preferences_changed.connect(_apply_preferences)
	loc.bindings_changed.connect(_update_hud)
	loc.language_changed.connect(_update_hud)
	loc.settings_write_failed.connect(func(): ui.notify("UI_SETTINGS_SAVE_ERROR"))
	floor_manager.floor_cleared.connect(_on_floor_cleared)
	floor_manager.enemy_killed.connect(_on_enemy_killed)
	floor_manager.before_wave.connect(_on_before_wave)
	floor_manager.between_waves.connect(_on_between_waves)
	floor_manager.counts_changed.connect(_on_counts_changed)
	floor_manager.projectile_requested.connect(_enemy_projectile)
	floor_manager.sound_requested.connect(sound.play)
	_apply_preferences()
	show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and is_node_ready():
		_quit()

func _process(delta: float) -> void:
	if state in RUN_STATES:
		elapsed += delta
	if state == State.TRANSITION and transition_remaining > 0.0:
		transition_remaining = maxf(0.0, transition_remaining - delta)
		ui.set_transition_progress(TRANSITION_TIME - transition_remaining, transition_remaining <= 0.0)
		if transition_remaining <= 0.0 and not current_floor.wait_for_confirmation:
			_begin_combat()
	if is_instance_valid(ghost):
		ghost.show_at(ghost.elapsed + delta)
		if ghost.elapsed >= Ghost.DURATION:
			_finish_ghost()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or state not in RUN_STATES:
		return
	if event.is_action_pressed("inventory") and state in BAG_STATES and not is_instance_valid(ghost):
		ui.show_inventory(inventory, player)
	elif event.is_action_pressed("quick_item") and state in BAG_STATES and not is_instance_valid(ghost):
		if inventory.potion_on_quick_slot:
			_drink_potion()
	elif state == State.TRANSITION:
		if transition_remaining > 0.0 or not (event.is_action_pressed("next") or event.is_action_pressed("interact")):
			return
		_begin_combat()
	elif event.is_action_pressed("interact") and state in [State.GROUNDS, State.COMBAT, State.SAFE] and not is_instance_valid(ghost):
		_interact()
	elif event.is_action_pressed("next") and state == State.SAFE:
		_continue_after_clear()
	else:
		return
	get_viewport().set_input_as_handled()

func _sync_pause() -> void:
	get_tree().paused = state in RUN_STATES and ui.top_overlay() != null

func _close_or_pause() -> void:
	var top: Control = ui.top_overlay()
	if top != null:
		if state == State.EPILOGUE and top == ui.lore:
			end_run(true)
		else:
			ui.pop_overlay()
	elif state in RUN_STATES:
		ui.show_pause(state == State.COMBAT and floor_manager.wave_in_progress())

func _apply_preferences() -> void:
	arena.high_quality = loc.high_quality
	grounds.high_quality = loc.high_quality
	arena.queue_redraw()
	grounds.queue_redraw()
	sound.set_volumes(loc.master_volume, loc.effects_volume)

func _request_start() -> void:
	if state == State.MENU and not _resume.is_empty():
		ui.show_overwrite()
	else:
		start_run()

func show_menu() -> void:
	state = State.MENU
	_clear_world()
	grounds.show()
	arena.floor_number = 1
	arena.layout = ArenaLayout.new()
	arena.queue_redraw()
	ui.notify("")
	var latest := saves.load_latest()
	_resume = RunSave.prepare_resume(latest.get("data"), floors)
	if _resume.is_empty():
		var backup := saves.load_backup()
		_resume = RunSave.prepare_resume(backup.get("data"), floors)
		if not _resume.is_empty():
			ui.notify("UI_SAVE_RECOVERED")
		elif latest.error != ERR_FILE_NOT_FOUND or backup.error != ERR_FILE_NOT_FOUND:
			ui.notify("UI_SAVE_INVALID")
	ui.show_menu(not _resume.is_empty())
	_sync_pause()

func start_run() -> void:
	_clear_world()
	_resume.clear()
	ui.notify("")
	seed = randi()
	floor_number = 0
	kills = 0
	elapsed = 0.0
	ghost_seen = false
	inventory = RunInventory.new()
	layouts.clear()
	current_choices.clear()
	for i in range(floors.size()):
		var layout := ArenaLayout.new()
		layout.generate(floors[i], _rng("layout", i))
		layouts.append(layout)
	_create_player()
	var fixed_pickups: Dictionary = grounds.pickups()
	for id in fixed_pickups:
		_add_pickup(id, fixed_pickups[id])
	_enter_grounds()
	player.position = grounds.get_node("Start").position
	_save_run()

func _create_player() -> void:
	player = PlayerScene.instantiate()
	player.set_equipment(inventory.equipped)
	actors.add_child(player)
	player.died.connect(_on_player_died)
	player.sound_requested.connect(sound.play)
	player.projectile_requested.connect(_player_projectile)

func _enter_grounds() -> void:
	state = State.GROUNDS
	grounds.show()
	arena.layout = ArenaLayout.new()
	player.layout = arena.layout
	player.can_move = true
	player.can_attack = false
	_guide_weapons()
	ui.show_hud()

func _interact() -> void:
	var near := _near_object()
	if near == null:
		return
	if near == entrance:
		_try_enter()
	elif near == camp:
		ui.show_lore("LORE_CAMP")
	else:
		_collect(near)

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

func _has_starting_weapons() -> bool:
	return inventory.owned.has("START_SWORD") and inventory.owned.has("START_STAFF")

func _try_enter() -> void:
	if _has_starting_weapons():
		floor_number = 1
		_start_transition()
	elif not ghost_seen:
		ghost = GhostScene.instantiate()
		ghost.position = entrance.position + Vector2(0, 42)
		for node in pickups.get_children():
			if node.item_id in GameData.STARTERS.values():
				ghost.targets.append(node.global_position)
		actors.add_child(ghost)
		player.can_move = false
		sound.play("ghost")
	else:
		ui.notify("UI_NEED_WEAPONS", {}, 2.5)

func _finish_ghost() -> void:
	ghost.queue_free()
	ghost = null
	ghost_seen = true
	player.can_move = true
	_guide_weapons()
	_save_run()

func _guide_weapons() -> void:
	for node in pickups.get_children():
		node.guided = ghost_seen and node.item_id in GameData.STARTERS.values()

func _start_transition() -> void:
	_clear_pickups()
	_checkpoint.clear()
	_wave_drops.clear()
	_next_wave = 0
	player.position = ArenaLayout.PLAYER_START
	_enter_transition(TRANSITION_TIME)
	_save_run()

func _enter_transition(remaining: float) -> void:
	state = State.TRANSITION
	_use_floor_layout()
	player.can_move = false
	player.can_attack = false
	transition_remaining = remaining
	ui.show_transition(floor_number, current_floor.tip_key, current_floor.entry_note_key)
	ui.set_transition_progress(TRANSITION_TIME - remaining, remaining <= 0.0)

func _use_floor_layout() -> void:
	grounds.hide()
	arena.floor_number = floor_number
	arena.layout = layouts[floor_number - 1]
	arena.queue_redraw()
	player.layout = arena.layout

func _begin_combat() -> void:
	_enter_combat()
	_save_run()

func _enter_combat() -> void:
	state = State.COMBAT
	_use_floor_layout()
	player.can_move = true
	player.can_attack = false
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
		var available := RewardManager.available_equipment(excluded)
		for order in range(current_floor.waves[index].size()):
			var rng := _rng("loot", floor_number, index, order)
			_wave_drops.append(RewardManager.drop_for_roll(rng.randi_range(0, 99), available, rng))
	floor_manager.wave_drops.assign(_wave_drops)
	_checkpoint = _snapshot()
	_write_checkpoint(_checkpoint)
	player.can_attack = true

func _on_between_waves(next_index: int) -> void:
	_next_wave = next_index
	_wave_drops.clear()
	_checkpoint.clear()
	_clear_projectiles()
	player.can_attack = false
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
	_enter_safe()
	_save_run.call_deferred()

func _enter_safe() -> void:
	state = State.SAFE
	_use_floor_layout()
	player.can_move = true
	player.can_attack = false
	_on_counts_changed(0, current_floor.waves.size(), current_floor.waves.size())
	ui.show_hud()

func _continue_after_clear() -> void:
	if not current_floor.epilogue.is_empty():
		_open_epilogue()
	else:
		current_choices = RewardManager.generate_choices(inventory.owned, _rng("reward", floor_number))
		_enter_reward()
	_save_run()

func _open_epilogue() -> void:
	state = State.EPILOGUE
	_use_floor_layout()
	player.can_move = false
	player.can_attack = false
	ui.show_hud()
	ui.show_lore(current_floor.epilogue, true)

func _enter_reward() -> void:
	state = State.REWARD
	_use_floor_layout()
	player.can_move = false
	player.can_attack = false
	ui.show_reward(current_choices)

func _on_reward_selected(id: String) -> void:
	if state != State.REWARD or ui.top_overlay() != null or not current_choices.has(id):
		return
	inventory.add(id)
	current_choices.clear()
	sound.play("choose")
	floor_number += 1
	_start_transition()

func _add_pickup(id: String, position: Vector2) -> void:
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
	player.set_equipment(inventory.equipped)
	if GameData.is_book(id):
		_read_book(id)
	else:
		ui.notify("UI_PICKED_UP", {"item": loc.text(GameData.name_key(id))}, 2.2)

func _read_book(id: String) -> void:
	if inventory.owned.has(id):
		inventory.mark_read(id)
		ui.show_lore(id)

func _on_inventory_requested(operation: String, id: String) -> void:
	var top: Control = ui.top_overlay()
	if top == ui.bag:
		match operation:
			"equip": inventory.equip(id)
			"unequip": inventory.unequip(id)
			"read": _read_book(id)
			"quick": inventory.potion_on_quick_slot = not inventory.potion_on_quick_slot
			"drink": _drink_potion()
		if operation in ["equip", "unequip"]:
			player.set_equipment(inventory.equipped)
	elif top == ui.crafting and operation == "craft" and inventory.craft_potion():
		sound.play("craft", true)
		ui.notify("UI_CRAFT_SUCCESS", {}, 2.0)
	ui.refresh_inventory()
	_update_hud()

func _drink_potion() -> void:
	if inventory.drink(player):
		sound.play("potion", get_tree().paused)
		ui.notify("UI_DRANK_POTION", {}, 2.0)
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
		hint = loc.text("UI_GROUND_READY" if _has_starting_weapons() else "UI_GROUND_GOAL")
	elif state == State.SAFE:
		hint = loc.text("UI_SAFE" if current_floor.epilogue.is_empty() else "UI_SAFE_EPILOGUE", {"next": loc.binding("next")})
	if state in [State.GROUNDS, State.COMBAT, State.SAFE] and not is_instance_valid(ghost):
		near = _near_object()
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
	if state == State.COMBAT:
		end_run(false)

func end_run(victory: bool) -> void:
	if state not in RUN_STATES:
		return
	state = State.VICTORY if victory else State.GAME_OVER
	player.can_move = false
	player.can_attack = false
	floor_manager.clear_enemies()
	_clear_projectiles()
	_clear_pickups()
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

func _enemy_projectile(origin: Vector2, direction: Vector2, damage: float, shot_speed: float) -> void:
	_spawn_projectile(origin, direction, damage, false, shot_speed)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, friendly: bool, shot_speed := -1.0) -> void:
	if state != State.COMBAT:
		return
	var projectile := ProjectileScene.instantiate()
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, friendly, player, shot_speed)

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
	_clear_projectiles()
	_clear_pickups()
	_clear_children(actors)
	ui.bag.inventory = null
	player = null
	ghost = null
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
		"ground": ground, "choices": current_choices.duplicate(), "inventory": inventory.snapshot(),
		"kills": kills, "elapsed": elapsed, "ghost_seen": ghost_seen, "transition": transition_remaining,
		"player": {"position": entrance.position if is_instance_valid(ghost) else player.position,
			"hp": player.hp, "aim": player.aim, "sword_timer": player.sword_timer,
			"magic_timer": player.magic_timer, "invulnerability": player.invulnerability,
			"sword_flash": player.sword_flash},
	}

func _write_checkpoint(data: Dictionary) -> bool:
	var error := saves.write(data)
	if error != OK:
		ui.notify("UI_SAVE_WRITE_ERROR")
	elif ui.status_key == "UI_SAVE_WRITE_ERROR":
		ui.notify("")
	return error == OK

func _save_run() -> bool:
	if state not in RUN_STATES:
		return true
	if state == State.COMBAT and floor_manager.wave_in_progress() and not _checkpoint.is_empty():
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
	current_choices.assign(data.choices)
	_create_player()
	player.position = data.player.position
	player.hp = data.player.hp
	player.aim = data.player.aim
	player.sword_timer = data.player.sword_timer
	player.magic_timer = data.player.magic_timer
	player.invulnerability = data.player.invulnerability
	player.sword_flash = data.player.sword_flash
	for entry in data.ground:
		_add_pickup(entry.id, entry.position)
	match data.phase:
		"grounds": _enter_grounds()
		"transition": _enter_transition(data.transition)
		"combat": _enter_combat()
		"safe": _enter_safe()
		"reward": _enter_reward()
		"epilogue": _open_epilogue()
	_resume.clear()
	_update_hud()
