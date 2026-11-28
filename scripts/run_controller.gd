extends Node2D

const Cinematics = preload("res://scripts/run_cinematics.gd")
const FloorFeatures = preload("res://scripts/floor_features.gd")
const GameData = preload("res://data/game_data.gd")
const ActorMotion = preload("res://scripts/actor_motion.gd")
const UpgradeArt = preload("res://data/upgrade_art.gd")
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
const Boons = preload("res://data/run_boons.gd")
const PlayerStats = preload("res://data/player_stats.gd")

enum State { MENU, OPENING, GROUNDS, TRANSITION, DIALOGUE, COMBAT, SAFE, ENDING, GAME_OVER, VICTORY, AFTERMATH }
const RUN_STATES := [State.OPENING, State.GROUNDS, State.TRANSITION, State.DIALOGUE, State.COMBAT, State.SAFE, State.ENDING, State.AFTERMATH]
const PLAY_STATES := [State.GROUNDS, State.COMBAT, State.SAFE]
const TRANSITIONS := [State.OPENING, State.TRANSITION, State.ENDING]
const TRANSITION_TIME := Cinematics.MAX_TIME
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
var transition_duration := 0.0
var _climb_origin := Vector2.ZERO
var _climb_active := false
var _ghost_origin := Vector2.ZERO
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
var _focused_pickup: Node2D
var _focused_pickup_key := ""
var _stair_offer: Array[String] = []
var _defeated_lord_position := ArenaLayout.LORD_INTRO_POSITION
var _crystal_touch_origin := Vector2.ZERO
var _lord_animation: Tween
var _aftermath_camera_zoom := Vector2.ONE

func _ready() -> void:
	get_tree().auto_accept_quit = false
	saves = RunSave.new(save_path)
	codex = Codex.new(codex_path)
	var codex_error := codex.load_progress()
	features = FeaturesScene.instantiate()
	add_child(features)
	move_child(features, actors.get_index())
	features.drop_requested.connect(_add_pickup)
	features.sound_requested.connect(sound.play_at)
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
	ui.dialogue_progressed.connect(_on_dialogue_progress)
	ui.boon_chosen.connect(_choose_boon)
	ui.cinematic_skipped.connect(func():
		if state == State.ENDING:
			_finish_transition())
	ui.inventory_requested.connect(_on_inventory_requested)
	ui.sound_preview_requested.connect(func(): sound.play("pickup", true))
	ui.ui_sound_requested.connect(func(kind: String): sound.play(kind, true))
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
	floor_manager.sound_requested.connect(sound.play_at)
	if floor_manager.has_signal("boss_phase_changed"):
		floor_manager.boss_phase_changed.connect(_on_boss_phase)
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
		var before := transition_duration - transition_remaining
		var minimum := 0.0
		if _needs_boon():
			minimum = transition_duration - Cinematics.choice_time(floor_number)
		transition_remaining = maxf(minimum, transition_remaining - delta)
		_update_transition(before)
		if transition_remaining <= 0.0:
			_finish_transition()
	if is_instance_valid(ghost):
		ghost.show_at(ghost.elapsed + delta)
		_update_ghost_reaction()
		if ghost.elapsed >= Ghost.DURATION:
			_finish_ghost()
	if state in PLAY_STATES and not is_instance_valid(ghost):
		_update_world_interactions()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_echo() or state not in PLAY_STATES or is_instance_valid(ghost):
		return
	if event.is_action_pressed("inventory"):
		ui.bag.magic_allowed = state != State.COMBAT
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
	sound.set_paused(get_tree().paused)
	if _lord_animation != null and _lord_animation.is_valid():
		if ui.top_overlay() == ui.dialogue:
			_lord_animation.play()
		else:
			_lord_animation.pause()

func _close_or_pause() -> void:
	var top: Control = ui.top_overlay()
	if top != null:
		if state == State.DIALOGUE and top == ui.dialogue:
			ui.show_pause()
		else:
			ui.pop_overlay()
	elif state in RUN_STATES:
		ui.show_pause()

func _apply_preferences() -> void:
	arena.high_quality = loc.high_quality
	if arena.has_method("set_lighting_quality"):
		arena.set_lighting_quality(loc.high_quality)
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
	if arena.has_method("clear_lighting"):
		arena.clear_lighting()
	sound.clear_environment()
	sound.set_combat(false)
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
	_enter_transition(State.OPENING)
	_save_run()

func _create_player() -> void:
	player = PlayerScene.instantiate()
	player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
	actors.add_child(player)
	camera = FollowCamera.instantiate()
	player.add_child(camera)
	player.died.connect(_on_player_died)
	player.sound_requested.connect(func(kind: String): sound.play_at(kind, player.global_position))
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
	var target := _interaction()
	match target.get("kind", ""):
		"pickup":
			_collect(target.node)
		"entrance":
			_try_enter()
		"camp":
			_check_codex(codex.discover_item("LORE_CAMP"))
			_read_book("LORE_CAMP")
		"altar":
			if inventory.absorb_blood_bead():
				pearl_available = false
				features.set_landmark_state(true, false)
				sound.set_altar_active(false)
				sound.play_at("pearl_pickup", ArenaLayout.ALTAR_POSITION)
				ui.notify("UI_PEARL_ABSORBED", {"count": inventory.blood_beads}, 2.5)
				_save_run()
		"crystal":
			_crystal_touch_origin = player.position
			_enter_transition(State.ENDING)
			_save_run()

func _update_world_interactions() -> void:
	if state != State.SAFE or floor_number == floors.size():
		return
	var gate_position := ArenaLayout.STAIRS_POSITION
	var at_gate := _at(gate_position, ArenaLayout.LANDMARK_RADIUS)
	if not at_gate:
		gate_armed = true
	if pearl_available and not stair_notice_seen and _at(gate_position, 92.0):
		stair_notice_seen = true
		ui.notify("UI_STAIR_FORFEIT", {}, 3.0)
	if not at_gate or not gate_armed:
		return
	floor_number += 1
	_start_floor_transition()

func _at(point: Vector2, radius: float) -> bool:
	return player.position.distance_squared_to(point) < radius * radius

func _interaction() -> Dictionary:
	var closest := {}
	if state not in PLAY_STATES or is_instance_valid(ghost):
		return closest
	var nearby: Array[Dictionary] = []
	for node in pickups.get_children():
		nearby.append({"node": node, "kind": "pickup", "position": node.global_position, "radius": PICKUP_DISTANCE + player.stats.focus_bonus})
	if state == State.GROUNDS:
		nearby.append({"kind": "entrance", "position": entrance.global_position, "radius": PICKUP_DISTANCE})
		nearby.append({"kind": "camp", "position": camp.global_position, "radius": PICKUP_DISTANCE})
	elif state == State.SAFE:
		if floor_number == floors.size():
			nearby.append({"kind": "crystal", "position": ArenaLayout.EXIT_POSITION, "radius": ArenaLayout.LANDMARK_RADIUS})
		elif pearl_available:
			nearby.append({"kind": "altar", "position": ArenaLayout.ALTAR_POSITION, "radius": ArenaLayout.LANDMARK_RADIUS})
	var distance := INF
	for entry in nearby:
		var gap: float = entry.position.distance_squared_to(player.global_position)
		if gap < minf(distance, entry.radius * entry.radius) and player.layout.has_clear_line(player.global_position, entry.position):
			distance = gap
			closest = entry
	return closest

func _focus_pickup(node: Node2D) -> void:
	var key: String = loc.binding("interact") if is_instance_valid(node) else ""
	if node == _focused_pickup and key == _focused_pickup_key:
		return
	if node != _focused_pickup and is_instance_valid(_focused_pickup) and _focused_pickup.has_method("set_focused"):
		_focused_pickup.set_focused(false)
	_focused_pickup = node
	_focused_pickup_key = key
	if is_instance_valid(node) and node.has_method("set_focused"):
		node.set_focused(true, key)

func _try_enter() -> void:
	if inventory.has_weapon():
		floor_number = 1
		_start_floor_transition()
	elif not ghost_seen:
		_show_ghost()
	else:
		ui.notify("UI_NEED_WEAPONS", {}, 2.5)

func _show_ghost(start_at := 0.0, play_entrance_sound := true) -> void:
	_ghost_origin = player.position
	# Leave the actor's approach lane open and keep both silhouettes in the shot.
	var ghost_side := -1.0 if _ghost_origin.x >= entrance.position.x else 1.0
	ghost = GhostScene.instantiate()
	ghost.position = entrance.position + Vector2(ghost_side * 68.0, 34.0)
	var starters: Dictionary = grounds.pickups()
	ghost.targets.assign([starters["START_SWORD"], starters["START_STAFF"]])
	actors.add_child(ghost)
	player.can_move = false
	player.can_attack = false
	ghost.show_at(start_at)
	_update_ghost_reaction()
	if play_entrance_sound:
		sound.play_at("ghost", ghost.global_position)

func _update_ghost_reaction() -> void:
	var reaction: float = smoothstep(0.1, 0.68, ghost.elapsed)
	var away := entrance.position.direction_to(_ghost_origin)
	if away.is_zero_approx():
		away = Vector2.DOWN
	player.position = player.layout.move_actor(_ghost_origin, away * (17.0 * reaction), ArenaLayout.PLAYER_RADIUS)
	var look_at: Vector2 = ghost.look_target()
	player.set_cinematic_pose(player.position.direction_to(look_at), Vector2.ZERO,
		smoothstep(0.0, 1.12, ghost.elapsed) if ghost.elapsed < 1.12 else -1.0)

func _finish_ghost() -> void:
	ghost.queue_free()
	ghost = null
	ghost_seen = true
	player.clear_cinematic_pose()
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
	if floor_number > 1:
		_climb_origin = player.position
		_climb_active = true
		_stair_offer = Boons.offer(seed, floor_number, inventory.owned, inventory.boon_history,
			PlayerStats.WEAPONS, inventory.equipped.get("weapon", ""))
	else:
		_arrive_on_floor()
	_enter_transition(State.TRANSITION)
	_save_run()

func _arrive_on_floor() -> void:
	_climb_active = false
	player.clear_cinematic_pose()
	player.reset_floor_effects()
	player.position = ArenaLayout.PLAYER_START
	_setup_world()

func _needs_boon() -> bool:
	return state == State.TRANSITION and _stair_offer.size() == 3 and not inventory.boon_history.has(floor_number)

func _choose_boon(id: String) -> void:
	if not _needs_boon() or id not in _stair_offer or not ui.boon_panel.visible or ui.top_overlay() != null:
		return
	if not inventory.choose_boon(floor_number, id):
		return
	if not _save_run():
		inventory.boon_history.erase(floor_number)
		return
	player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
	sound.play_at("corruption_confirm", player.global_position)
	ui.hide_boons()

func _enter_transition(phase: State, remaining := -1.0) -> void:
	state = phase
	player.can_move = false
	player.can_attack = false
	features.enabled = false
	var phase_name: String = State.keys()[phase].to_lower()
	transition_duration = Cinematics.duration(phase_name, floor_number, floors.size())
	transition_remaining = transition_duration if remaining < 0.0 else remaining
	sound.set_altar_active(false)
	sound.set_combat(false)
	match phase:
		State.OPENING:
			grounds.hide()
			features.hide()
			actors.hide()
			pickups.hide()
			sound.set_music("grounds")
			ui.show_special_transition("TRANSITION_GROUNDS_TITLE", "TRANSITION_GROUNDS_TIP")
		State.ENDING:
			features.disarm_traps()
			_clear_projectiles()
			ui.show_ending_story()
			if transition_duration - transition_remaining >= Cinematics.CREDITS_TIME:
				sound.set_music("ending")
			else:
				sound.set_floor_music(floor_number)
				sound.set_quiet()
		_:
			sound.set_floor_music(floor_number)
			var show_map := floor_number in [1, floors.size()]
			ui.show_transition(floor_number, "FLOOR_NAME_%02d" % floor_number, current_floor.tip_key,
				current_floor.entry_note_key, show_map, _climb_active)
	_update_transition()

func _update_transition(previous := -1.0) -> void:
	var time := transition_duration - transition_remaining
	if state == State.ENDING:
		_update_ending(time, previous)
		return
	var arrival := Cinematics.arrival_time(floor_number) if not _stair_offer.is_empty() else Cinematics.STAIR_CLIMB_END
	if _climb_active:
		var choice := Cinematics.choice_time(floor_number)
		var charged := not _stair_offer.is_empty()
		var travel := time
		if charged and floor_number == 2:
			travel = time if time < 0.70 else 0.70 + maxf(0.0, time - choice)
		var travel_end := 1.42 if charged and floor_number == 2 else arrival
		var progress := smoothstep(0.0, travel_end, travel)
		player.position = _climb_origin.lerp(ArenaLayout.STAIRS_POSITION + Vector2(0, -57), progress)
		var startled := -1.0
		var walking := progress < 1.0 and not (charged and floor_number == 2 and time >= 0.70 and time <= choice)
		if charged and floor_number == 2 and time >= 0.95 and time <= choice:
			startled = smoothstep(0.95, choice, time)
		player.set_cinematic_pose(Vector2.UP, Vector2.UP * 95.0 if walking else Vector2.ZERO, startled)
		if charged:
			var chest := player.get_global_transform_with_canvas() * Vector2(0, -29)
			ui.story_effects.show_stairs(time, chest, floor_number == 2, not loc.high_quality)
			var charge_time := 0.70 if floor_number == 2 else 0.09
			if previous >= 0.0 and previous < charge_time and time >= charge_time:
				sound.play_at("corruption_enter", player.global_position)
			if time >= choice and _needs_boon():
				ui.show_boons(_stair_offer, inventory)
		if time >= arrival:
			ui.story_effects.clear()
			_arrive_on_floor()
	ui.set_transition_progress(time, transition_duration, arrival)

func _update_ending(time: float, previous: float) -> void:
	var touch := time >= Cinematics.TOUCH_TIME
	var approach := ArenaLayout.EXIT_POSITION.direction_to(_crystal_touch_origin)
	if approach.is_zero_approx():
		approach = Vector2.DOWN
	var touching_distance := minf(21.0, _crystal_touch_origin.distance_to(ArenaLayout.EXIT_POSITION))
	var contact := ArenaLayout.EXIT_POSITION + approach * touching_distance
	if player.layout.is_walkable(contact, ArenaLayout.PLAYER_RADIUS):
		player.position = _crystal_touch_origin.lerp(contact, smoothstep(0.0, 0.27, time))
	var look := player.position.direction_to(ArenaLayout.EXIT_POSITION)
	player.set_cinematic_pose(look if not look.is_zero_approx() else Vector2.UP, Vector2.ZERO,
		-1.0, "windup" if not touch else "", smoothstep(0.0, Cinematics.TOUCH_TIME, time))
	_crystal_state("activated" if touch else "ready")
	var fade := 1.0 - smoothstep(Cinematics.TOUCH_TIME, Cinematics.SKY_TIME, time)
	var shake := 12.0 * fade if touch and loc.high_quality else 0.0
	camera.offset = Vector2(sin(time * 79.0), cos(time * 61.0)) * shake
	var crystal := player.get_canvas_transform() * (ArenaLayout.EXIT_POSITION + Vector2(0, -20))
	ui.set_ending_progress(time, crystal)
	if previous >= 0.0:
		if previous < Cinematics.TOUCH_TIME and touch:
			sound.play_at("crystal_touch", ArenaLayout.EXIT_POSITION)
			sound.play_at("crystal_rumble", ArenaLayout.EXIT_POSITION)
		if previous < Cinematics.SKY_TIME and time >= Cinematics.SKY_TIME:
			sound.play("sky_darkening")
		if previous < Cinematics.CREDITS_TIME and time >= Cinematics.CREDITS_TIME:
			sound.set_music("ending")
			sound.clear_environment()

func _finish_transition() -> void:
	match state:
		State.OPENING:
			_enter_grounds()
			_save_run()
		State.TRANSITION:
			_stair_offer.clear()
			if ui.status_key == "UI_STAIR_FORFEIT":
				ui.notify("")
			if floor_number == floors.size() and not lord_introduced:
				_enter_dialogue()
			else:
				_enter_combat()
			_save_run()
		State.ENDING:
			camera.offset = Vector2.ZERO
			end_run(true)

func _setup_world(view_floor := -1) -> void:
	var displayed := floor_number if view_floor < 0 else view_floor
	features.show()
	actors.show()
	pickups.show()
	grounds.visible = displayed == 0
	arena.visible = displayed > 0
	arena.floor_number = displayed
	arena.layout = ArenaLayout.new() if displayed == 0 else layouts[displayed - 1]
	player.layout = arena.layout
	features.setup(player, player.layout, displayed, seed)
	if arena.has_method("setup_lighting"):
		arena.setup_lighting(displayed, player.layout)
	var fires: Array = grounds.fire_positions() if displayed == 0 else arena.fire_positions()
	sound.set_environment(displayed, player, fires)
	camera.reset_smoothing()
	arena.queue_redraw()

func _enter_dialogue(start_line := 0, aftermath := false) -> void:
	state = State.AFTERMATH if aftermath else State.DIALOGUE
	player.can_move = false
	player.can_attack = false
	features.enabled = false
	sound.set_floor_music(floor_number)
	sound.set_combat(false)
	_crystal_state("dormant")
	_check_codex(codex.discover_enemy("lord"))
	_spawn_lord_preview(aftermath)
	if aftermath:
		_frame_aftermath()
	ui.show_hud()
	ui.anchor_dialogue(lord_preview)
	var lines := Cinematics.LORD_DEFEATED if aftermath else Cinematics.LORD_DIALOGUE
	var speakers: Array[String] = []
	speakers.resize(lines.size())
	speakers.fill("ENEMY_LORD_NAME")
	ui.show_dialogue(lines, speakers, start_line)
	_update_lord_pose(start_line)

func _frame_aftermath() -> void:
	var player_at: Vector2 = player.global_position
	var lord_at := lord_preview.global_position
	var crystal_at := ArenaLayout.EXIT_POSITION
	var subjects := Rect2(player_at - Vector2(36, 60), Vector2(72, 84))
	subjects = subjects.merge(Rect2(lord_at - Vector2(46, 78), Vector2(92, 102)))
	subjects = subjects.merge(Rect2(crystal_at - Vector2(48, 88), Vector2(96, 112)))
	var available := get_viewport().get_visible_rect().size - Vector2(96, 88)
	_aftermath_camera_zoom = camera.zoom
	var fit := available / subjects.size
	var scale := minf(camera.zoom.x, minf(fit.x, fit.y))
	var half_view := available / (2.0 * scale)
	var center := player_at.clamp(subjects.end - half_view, subjects.position + half_view)
	camera.zoom = Vector2.ONE * scale
	camera.offset = center - player_at
	camera.reset_smoothing()
	camera.force_update_scroll()

func _spawn_lord_preview(aftermath: bool) -> void:
	lord_preview = Sprite2D.new()
	lord_preview.name = "LordPreview"
	lord_preview.texture = UpgradeArt.frame("lord", "s", "idle", 0)
	var has_frames := lord_preview.texture != null
	if not has_frames:
		lord_preview.texture = EditionArt.icon("lord")
	lord_preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if has_frames:
		lord_preview.scale = Vector2.ONE * (ArenaLayout.ELITE_RADIUS / 17.0)
		lord_preview.offset.y = -24.0
	elif lord_preview.texture != null:
		var size := lord_preview.texture.get_size()
		lord_preview.scale = Vector2.ONE * (ArenaLayout.ELITE_RADIUS * 2.7 / maxf(size.x, size.y))
	lord_preview.position = _defeated_lord_position if aftermath else ArenaLayout.LORD_INTRO_POSITION
	actors.add_child(lord_preview)

func _show_defeated_lord() -> void:
	_spawn_lord_preview(true)
	var frame := UpgradeArt.frame("lord", "s", "defeated", 4)
	if frame != null:
		lord_preview.texture = frame

func _on_dialogue_progress(line: int) -> void:
	_update_lord_pose(line)
	_save_run()

func _update_lord_pose(line: int) -> void:
	if not is_instance_valid(lord_preview):
		return
	if _lord_animation != null:
		_lord_animation.kill()
	var point_at_crystal := state == State.AFTERMATH and line >= 1
	var look_at := ArenaLayout.EXIT_POSITION if point_at_crystal else lord_preview.position
	player.set_cinematic_pose(player.position.direction_to(look_at), Vector2.ZERO,
		-1.0, "idle", 1.0 if point_at_crystal else 0.0)
	var direction := ActorMotion.direction_name(lord_preview.position.direction_to(player.position))
	var pose := "defeated" if state == State.AFTERMATH else "gesture"
	var count := UpgradeArt.frame_count("lord", direction, pose)
	if count <= 0:
		pose = "hurt" if state == State.AFTERMATH else "idle"
		count = UpgradeArt.frame_count("lord", direction, pose)
	var sprite := lord_preview
	var first := 2 if point_at_crystal else 0
	var animate := func(progress: float):
		if is_instance_valid(sprite):
			var frame := roundi(lerpf(float(first), float(count - 1), progress))
			sprite.texture = UpgradeArt.frame("lord", direction, pose, frame)
	animate.call(0.0)
	_lord_animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_lord_animation.tween_method(animate, 0.0, 1.0, 0.7 if state == State.AFTERMATH else 0.48)
	if state == State.DIALOGUE and line == 0 and loc.high_quality:
		camera.offset = Vector2(0, -125)
		_lord_animation.parallel().tween_property(camera, "offset", Vector2.ZERO, 0.72).set_trans(Tween.TRANS_SINE)

func _finish_lord_dialogue() -> void:
	if _lord_animation != null:
		_lord_animation.kill()
	camera.offset = Vector2.ZERO
	player.clear_cinematic_pose()
	if state == State.AFTERMATH:
		camera.zoom = _aftermath_camera_zoom
		var frame := UpgradeArt.frame("lord", "s", "defeated", 4)
		if is_instance_valid(lord_preview) and frame != null:
			lord_preview.texture = frame
		_enter_safe()
		_save_run()
		return
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
	sound.set_combat(false)
	sound.set_floor_music(floor_number)
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
		var available := EnemyLoot.available_equipment(excluded, floor_number)
		var style: String = player.weapon_data().get("range_type", "")
		for order in range(current_floor.waves[index].size()):
			var rng := _rng("loot", floor_number, index, order)
			var roll := 99 if floor_number == 5 and order == 0 else rng.randi_range(0, 99)
			_wave_drops.append(EnemyLoot.drop_for_roll(roll, available, rng, style))
	floor_manager.wave_drops.assign(_wave_drops)
	sound.set_combat(true)
	_checkpoint = _snapshot()
	_write_checkpoint(_checkpoint)
	player.can_move = true
	player.can_attack = true

func _on_between_waves(next_index: int) -> void:
	sound.set_combat(false)
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
	if floor_number == floors.size():
		_enter_dialogue(0, true)
		_save_run.call_deferred()
		return
	_enter_safe()
	sound.play_cadence()
	sound.play_at("gate_open", ArenaLayout.STAIRS_POSITION)
	if pearl_available:
		sound.play_at("pearl_form", ArenaLayout.ALTAR_POSITION)
	_save_run.call_deferred()

func _enter_safe() -> void:
	state = State.SAFE
	var gate_position := ArenaLayout.EXIT_POSITION if floor_number == floors.size() else ArenaLayout.STAIRS_POSITION
	gate_armed = not _at(gate_position, ArenaLayout.LANDMARK_RADIUS)
	player.can_move = true
	player.can_attack = true
	features.enabled = true
	features.set_landmark_state(true, pearl_available)
	_crystal_state("ready")
	sound.set_floor_music(floor_number)
	sound.set_quiet()
	sound.set_altar_active(pearl_available)
	_on_counts_changed(0, current_floor.waves.size(), current_floor.waves.size())
	ui.show_hud()

func _crystal_state(value: String) -> void:
	if floor_number == floors.size() and features.has_method("set_crystal_state"):
		features.set_crystal_state(value)

func _on_boss_phase(_kind: String, phase: int) -> void:
	sound.set_boss_stage(phase)
	for projectile in projectiles.get_children():
		if not projectile.friendly and not projectile.trap_arrow:
			projectile.cancel()

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
	sound.play_at("pickup", node.position)
	player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
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
		"equip", "unequip":
			var changed := inventory.equip(id) if operation == "equip" else inventory.unequip(id)
			if changed:
				player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
				sound.play("equip", true)
		"read":
			_read_book(id)
		"quick":
			inventory.potion_on_quick_slot = not inventory.potion_on_quick_slot
		"drink":
			_drink_potion()
		"enhance":
			if state != State.COMBAT and not ui.magic_feedback_active() and inventory.enhance(id):
				player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
				if not _save_run():
					inventory.blood_beads += 1
					inventory.corruption[id] -= 1
					if inventory.corruption[id] == 0:
						inventory.corruption.erase(id)
					player.set_loadout(inventory.equipped, inventory.corruption, inventory.boon_levels())
					ui.refresh_inventory()
					return
				sound.play("magic_enhance", true)
				ui.play_magic_feedback(id)
				ui.notify("UI_CORRUPTION_SUCCESS", {}, 2.0)
		"craft":
			if inventory.craft_potion():
				_check_codex(codex.discover_item("POTION"))
				sound.play("craft", true)
				ui.notify("UI_CRAFT_SUCCESS", {}, 2.0)
	if state in PLAY_STATES and operation not in ["read", "drink", "enhance"]:
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
		_focus_pickup(null)
		return
	var hint := ""
	var nearby := ""
	if state == State.GROUNDS:
		hint = loc.text("UI_GROUND_READY" if inventory.has_weapon() else "UI_GROUND_GOAL")
	elif state == State.SAFE:
		if floor_number == floors.size():
			hint = loc.text("UI_EXIT_OPEN")
		else:
			hint = loc.text("UI_FLOOR_CLEARED" if pearl_available else "UI_ALTAR_EMPTY")
	var target := _interaction()
	_focus_pickup(target.get("node"))
	var interact: String = loc.binding("interact")
	match target.get("kind", ""):
		"entrance":
			nearby = loc.text("UI_GATE_NEAR" if inventory.has_weapon() or ghost_seen else "UI_GATE_UNARMED", {"interact": interact})
		"camp":
			nearby = loc.text("UI_CAMP_NEAR", {"interact": interact})
		"altar":
			nearby = loc.text("UI_ALTAR_NEAR", {"interact": interact})
		"crystal":
			nearby = loc.text("UI_F10_CRYSTAL_TOUCH", {"interact": interact})
		"pickup":
			nearby = loc.text("UI_PICKUP_NEAR", {"interact": interact, "item": loc.text(GameData.name_key(target.node.item_id))})
	ui.update_hud(player, inventory, floor_number, floors.size(), enemy_count, wave, total_waves, hint, nearby)
	if floor_manager.has_method("boss"):
		ui.update_boss(floor_manager.boss())

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
	sound.clear_environment()
	sound.set_combat(false)
	sound.set_music("ending" if victory else "")
	var error := saves.invalidate()
	ui.show_result(victory, floor_number, kills, elapsed, inventory.owned)
	ui.notify("" if error == OK else "UI_SAVE_INVALIDATE_ERROR")

func _on_enemy_killed(enemy: Node) -> void:
	kills += 1
	player.on_enemy_defeated()
	if not enemy.drop_id.is_empty():
		_add_pickup(enemy.drop_id, enemy.position)
	sound.play_at("death", enemy.global_position)
	if enemy.kind == "lord":
		_defeated_lord_position = enemy.position
		return
	var effect := DeathEffect.new()
	effect.kind = enemy.kind
	effect.direction = ActorMotion.direction_name(enemy.facing)
	effect.body_scale = enemy.hit_radius / 17.0
	effect.position = enemy.position
	actors.add_child(effect)

func _on_counts_changed(remaining: int, wave_number: int, wave_count: int) -> void:
	enemy_count = remaining
	wave = wave_number
	total_waves = wave_count

func _player_projectile(origin: Vector2, direction: Vector2, damage: float) -> void:
	if player.layout.has_clear_line(player.global_position, origin, ArenaLayout.PROJECTILE_RADIUS):
		var data: Dictionary = player.weapon_data()
		_spawn_projectile(origin, direction, damage, true, data.get("projectile_speed", -1.0), data.get("reach", -1.0))

func _enemy_projectile(origin: Vector2, direction: Vector2, damage: float, shot_speed: float, travel_range: float) -> void:
	_spawn_projectile(origin, direction, damage, false, shot_speed, travel_range)

func _spawn_projectile(origin: Vector2, direction: Vector2, damage: float, friendly: bool, shot_speed := -1.0, travel_range := -1.0) -> void:
	if state not in PLAY_STATES or (not friendly and state != State.COMBAT):
		return
	var projectile := ProjectileScene.instantiate()
	projectile.impact_sound.connect(sound.play_at)
	if friendly:
		projectile.weapon_id = player.weapon
		projectile.attack_token = player.attack_serial
	projectiles.add_child(projectile)
	projectile.setup(origin, direction, damage, friendly, player, shot_speed, travel_range)

func _clear_projectiles() -> void:
	_clear_children(projectiles)

func _clear_pickups() -> void:
	_focus_pickup(null)
	_clear_children(pickups)

func _clear_children(parent: Node) -> void:
	for node in parent.get_children():
		parent.remove_child(node)
		node.queue_free()

func _clear_world() -> void:
	if _lord_animation != null:
		_lord_animation.kill()
		_lord_animation = null
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
	_climb_active = false
	_stair_offer.clear()
	_defeated_lord_position = ArenaLayout.LORD_INTRO_POSITION
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
	var saved_position := player.position
	var world: Dictionary = features.snapshot()
	if _climb_active:
		# The climb is presentation over the departing floor. Its checkpoint already targets the next floor.
		saved_position = ArenaLayout.PLAYER_START
		world = FloorFeatures.fresh_snapshot(layouts[floor_number - 1], floor_number, seed)
	elif is_instance_valid(ghost):
		saved_position = _ghost_origin
	var snapshot := {
		"seed": seed, "phase": State.keys()[state].to_lower(), "floor": floor_number,
		"next_wave": _next_wave, "wave_drops": _wave_drops.duplicate(), "layouts": floor_layouts,
		"ground": ground, "inventory": inventory.snapshot(), "features": world,
		"pearl_available": pearl_available, "stair_notice_seen": stair_notice_seen, "lord_introduced": lord_introduced,
		"kills": kills, "elapsed": elapsed, "ghost_seen": ghost_seen, "transition": transition_remaining,
		"player": {"position": saved_position,
			"hp": player.hp, "aim": player.aim, "weapon_timers": player.weapon_timers.duplicate(),
			"invulnerability": player.invulnerability, "swing_direction": player.swing_direction,
			"sword_flash": player.sword_flash},
	}
	if is_instance_valid(ghost):
		snapshot["ghost_time"] = ghost.elapsed
	if state in [State.DIALOGUE, State.AFTERMATH]:
		snapshot["dialogue_line"] = ui.dialogue_line
	if not _stair_offer.is_empty() and state == State.TRANSITION:
		snapshot["stair_offer"] = _stair_offer.duplicate()
		snapshot["climb_origin"] = _climb_origin
	if floor_number == floors.size() and state in [State.AFTERMATH, State.SAFE, State.ENDING]:
		snapshot["defeated_lord"] = _defeated_lord_position
	if state == State.ENDING:
		snapshot["crystal_origin"] = _crystal_touch_origin
	snapshot.player["boon_triggers"] = player.boon_triggers.duplicate()
	return snapshot

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
	if is_queued_for_deletion():
		return
	ui.settings.commit()
	if _save_run():
		# Free the scene before the asynchronous mixer releases its last playback.
		var tree := get_tree()
		queue_free()
		tree.create_timer(0.15, true, false, true).timeout.connect(tree.quit)
	elif ui.top_overlay() == null:
		ui.show_pause()

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
	_stair_offer.assign(data.get("stair_offer", []))
	_climb_origin = data.get("climb_origin", Vector2.ZERO)
	_climb_active = data.phase == "transition" and not _stair_offer.is_empty() and (
		Cinematics.duration("transition", floor_number, floors.size()) - data.transition < Cinematics.arrival_time(floor_number))
	_defeated_lord_position = data.get("defeated_lord", ArenaLayout.LORD_INTRO_POSITION)
	_crystal_touch_origin = data.get("crystal_origin", data.player.position)
	_create_player()
	player.position = data.player.position
	player.hp = data.player.hp
	player.aim = data.player.aim
	player.weapon_timers = data.player.weapon_timers.duplicate()
	player.invulnerability = data.player.invulnerability
	player.sword_flash = data.player.sword_flash
	player.swing_direction = data.player.swing_direction
	player.boon_triggers = data.player.get("boon_triggers", {}).duplicate()
	for entry in data.ground:
		_add_pickup(entry.id, entry.position)
	_setup_world(floor_number - 1 if _climb_active else -1)
	if _climb_active:
		features.set_landmark_state(true, false)
	else:
		features.restore(data.features)
	match data.phase:
		"opening":
			_enter_transition(State.OPENING, data.transition)
		"grounds":
			_enter_grounds()
			if data.has("ghost_time"):
				_show_ghost(data.ghost_time, false)
		"transition":
			_enter_transition(State.TRANSITION, data.transition)
		"dialogue":
			_enter_dialogue(data.get("dialogue_line", 0))
		"aftermath":
			_enter_dialogue(data.get("dialogue_line", 0), true)
		"combat":
			_enter_combat()
		"safe":
			if floor_number == floors.size():
				_show_defeated_lord()
			_enter_safe()
		"ending":
			_show_defeated_lord()
			features.set_landmark_state(true, false)
			_enter_transition(State.ENDING, data.transition)
	_resume.clear()
	_update_hud()
