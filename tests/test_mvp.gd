extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/enemies/slime.tscn")
const GoblinScene = preload("res://scenes/enemies/goblin.tscn")
const ArcherScene = preload("res://scenes/enemies/archer.tscn")
const MageScene = preload("res://scenes/enemies/skeleton.tscn")
const EliteScene = preload("res://scenes/enemies/elite.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const Localization = preload("res://scripts/localization_service.gd")
const GameData = preload("res://data/game_data.gd")
const PlayerStats = preload("res://data/player_stats.gd")
const FloorFeatures = preload("res://scripts/floor_features.gd")
const WorldSettings = preload("res://data/complete_world.gd")
const Sound = preload("res://scripts/sound_manager.gd")
const RunController = preload("res://scripts/run_controller.gd")
const Boons = preload("res://data/run_boons.gd")
const LOCALES := ["zh_CN", "en_US"]
const CATEGORIES := ["menu", "hud", "transition", "narrative", "equipment", "inventory", "codex", "settings", "result", "input"]
const STRING_STATUSES := ["placeholder", "draft", "approved"]

class AuditedLocalization extends "res://scripts/localization_service.gd":
	signal text_requested(key: String, values: Dictionary)

	func text(key: String, values: Dictionary = {}) -> String:
		text_requested.emit(key, values)
		return super.text(key, values)

var failures: Array[String] = []
var checks := 0
var temp_settings: String
var temp_save: String
var temp_codex: String
var translation_variables: Dictionary = {}
var checked_calls: Dictionary = {}

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	var temp_dir := OS.get_environment("TMPDIR")
	if temp_dir.is_empty():
		temp_dir = OS.get_environment("TEMP")
	if temp_dir.is_empty():
		temp_dir = OS.get_user_data_dir()
	var test_path := temp_dir.path_join("tower-complete-test-%s" % Time.get_ticks_usec())
	temp_settings = test_path + ".cfg"
	temp_save = test_path + ".save"
	temp_codex = test_path + ".codex"
	await _test_localization()
	_test_floor_resources()
	await _test_cover()
	await _test_weapons_and_stats()
	await _test_corruption_cards()
	await _test_arrow_plate_and_pot()
	await _test_recorded_audio()
	if failures.is_empty():
		await _test_full_run("zh_CN", true)
		await _test_full_run("en_US", false)
		await _test_defeat()
	RunSave.new(temp_save).invalidate()
	for path in [temp_settings, temp_codex]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	# Playback stop is consumed by the audio thread after the last scene exits.
	await create_timer(0.15, true, false, true).timeout
	if failures.is_empty():
		print("PASS: %d checks (10 floors, 11 enemies, bilingual text, combat, world, crafting, corruption, saves and endings)" % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)

func _test_localization() -> void:
	var first = Localization.new()
	first.settings_path = temp_settings
	root.add_child(first)
	_test_string_table(first.translations)
	first.set_language("en_US")
	var english: Translation = first.translations.get("en_US")
	check(english != null and first.locale == "en_US" and first.text("UI_MENU_START") == english.get_message("UI_MENU_START"), "English selection takes effect")
	var second = Localization.new()
	second.settings_path = temp_settings
	root.add_child(second)
	check(second.locale == "en_US", "language selection persists")
	second.set_language("zh_CN")
	var chinese: Translation = second.translations.get("zh_CN")
	check(chinese != null and second.locale == "zh_CN" and second.text("UI_MENU_START") == chinese.get_message("UI_MENU_START"), "Chinese selection takes effect")
	first.queue_free()
	second.queue_free()
	await process_frame

func _test_string_table(translations: Dictionary) -> void:
	var source := FileAccess.open("res://localization/game.csv", FileAccess.READ)
	check(source != null, "translation source exists")
	if source == null:
		return
	var header := source.get_csv_line()
	var expected := PackedStringArray(["keys", "zh_CN", "en_US", "_category", "_context", "_status"])
	check(header == expected, "translation source has the six agreed columns")
	if header != expected:
		return
	var candidate := OS.get_cmdline_user_args().has("--candidate")
	var placeholders := RegEx.create_from_string("\\{([a-z_][a-z0-9_]*)\\}")
	while not source.eof_reached():
		var row := source.get_csv_line()
		if row.is_empty() or row == PackedStringArray([""]):
			continue
		check(row.size() == header.size(), "six CSV fields for %s" % row[0])
		if row.size() != header.size():
			continue
		var key := row[0]
		check(not key.is_empty() and not translation_variables.has(key), "translation ID is nonempty and unique: " + key)
		check(row[3] in CATEGORIES, "valid category for " + key)
		check(not row[4].strip_edges().is_empty(), "context exists for " + key)
		check(row[5] in STRING_STATUSES, "valid status for " + key)
		if candidate:
			check(row[5] != "placeholder", "candidate rejects placeholder text for " + key)
		var names := _placeholder_names(placeholders, row[1])
		translation_variables[key] = names
		check(names == _placeholder_names(placeholders, row[2]), "matching placeholders in both locales: " + key)
		check(names == _placeholder_names(placeholders, row[4]), "context documents each placeholder: " + key)
		for column in [1, 2]:
			var message := row[column].c_unescape()
			var description := "%s in %s" % [key, header[column]]
			var remainder := placeholders.sub(message, "", true)
			check(not remainder.contains("{") and not remainder.contains("}"), "valid placeholder syntax for " + description)
			check(not message.strip_edges().is_empty(), "nonempty translation for " + description)
			var translation: Translation = translations.get(header[column])
			check(translation != null and translation.get_message(key) == message, "imported translation matches CSV for " + description)
	check(not translation_variables.is_empty(), "string table contains entries")

func _placeholder_names(pattern: RegEx, message: String) -> Array[String]:
	var names: Array[String] = []
	for token in pattern.search_all(message):
		var name := token.get_string(1)
		if not names.has(name):
			names.append(name)
	names.sort()
	return names

func _check_text_request(key: String, values: Dictionary) -> void:
	var names: Array[String] = []
	names.assign(values.keys())
	names.sort()
	var signature := "%s %s" % [key, names]
	if checked_calls.has(signature):
		return
	checked_calls[signature] = true
	check(translation_variables.has(key), "UI used a String ID in the CSV: " + key)
	var required: Array = translation_variables.get(key, [])
	check(required.all(func(name: String): return name in names), "UI supplied %s for %s, expected %s" % [names, key, translation_variables.get(key)])

func _test_cover() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player = PlayerScene.instantiate()
	arena.add_child(player)
	player.position = Vector2(463, 300)
	player.can_attack = true
	player.set_loadout({"weapon": "START_SWORD"}, {})
	player.aim = Vector2.RIGHT
	var definition := FloorDefinition.new()
	definition.obstacle_count = 1
	var wall := Rect2(480, 250, 28, 120)
	check(player.layout.restore([{"rect": wall, "kind": "wall"}], definition), "test cover leaves the arena connected")
	check(player.layout.move_actor(player.position, Vector2(200, 0), 16.0).x < wall.position.x, "swept movement cannot cross cover")
	var archer = ArcherScene.instantiate()
	archer.setup("archer", player)
	arena.add_child(archer)
	archer.position = Vector2(526, 300)
	archer.spawn_delay = 0.0
	archer.set_physics_process(false)
	var archer_hp: float = archer.hp
	player.attack()
	check(archer.hp == archer_hp, "cover blocks the player's sword")
	archer.melee_dir = Vector2.LEFT
	archer._melee_strike()
	check(player.hp == player.max_hp, "cover blocks a ranged enemy's melee")
	archer.move_by(Vector2(-180, 0))
	check(archer.position.x > wall.end.x, "cover blocks enemy movement and knockback")
	for friendly in [true, false]:
		var projectile = ProjectileScene.instantiate()
		arena.add_child(projectile)
		var origin: Vector2 = player.position if friendly else archer.position
		var direction := Vector2.RIGHT if friendly else Vector2.LEFT
		projectile.setup(origin, direction, 20.0, friendly, player)
		projectile._physics_process(0.4)
		check(projectile.consumed, "projectile hits cover with a large physics step")
		check(archer.hp == archer_hp and player.hp == player.max_hp, "cover protects both actors from projectiles")
	var goblin = GoblinScene.instantiate()
	goblin.setup("goblin", player)
	arena.add_child(goblin)
	goblin.set_physics_process(false)
	goblin.position = Vector2(562, 300)
	goblin.spawn_delay = 0.0
	for i in range(190):
		goblin._physics_process(1.0 / 60.0)
	check(goblin.sees_player() and goblin.position.distance_to(player.position) < 58.0, "goblin follows a walkable route around the wall")
	player.position = Vector2(360, 303)
	for kind in ["archer", "skeleton"]:
		var enemy = archer if kind == "archer" else MageScene.instantiate()
		if enemy != archer:
			enemy.setup(kind, player)
			arena.add_child(enemy)
			enemy.set_physics_process(false)
		enemy.position = Vector2(622, 300)
		enemy.spawn_delay = 0.0
		enemy.attack_timer = 0.0
		var shots := {"count": 0, "clear": false}
		enemy.projectile_requested.connect(func(origin, _direction, _value):
			shots.count += 1
			shots.clear = player.layout.has_clear_line(origin, player.global_position))
		enemy._physics_process(1.0 / 60.0)
		check(shots.count == 0 and not enemy.sees_player(), kind + " cannot start a ranged attack through cover")
		for i in range(650):
			enemy._physics_process(1.0 / 60.0)
			if shots.count > 0:
				break
		check(shots.count > 0 and shots.clear, kind + " repositions to find a firing line")
	goblin.position = Vector2(415, 300)
	var rush_radius := 24.0
	var stopped_reach: float = goblin.clear_reach(Vector2.RIGHT, 120.0, goblin.hit_radius) - ArenaLayout.MOTION_MARGIN
	var outline: PackedVector2Array = goblin._rush_outline(Vector2.RIGHT, stopped_reach, rush_radius)
	check(not Geometry2D.triangulate_polygon(outline).is_empty()
		and Geometry2D.is_point_in_polygon(Vector2(stopped_reach + 5.0, 0), outline)
		and not Geometry2D.is_point_in_polygon(Vector2(67, 0), outline),
		"charge warning follows the hit area up to the wall and trims the blocked tip")
	goblin.position = Vector2(449, 388)
	outline = goblin._rush_outline(Vector2.RIGHT, 120.0, rush_radius)
	check(not Geometry2D.triangulate_polygon(outline).is_empty()
		and Geometry2D.is_point_in_polygon(Vector2(42, -15), outline)
		and not Geometry2D.is_point_in_polygon(Vector2(42, -21), outline),
		"charge warning clips the entire flank along cover and keeps open ground visible")
	arena.queue_free()
	await process_frame

func _test_floor_resources() -> void:
	var game = MainScene.instantiate()
	check(game.floors.size() == 10, "the main scene loads all ten floors")
	var roster := [
		["slime"],
		["slime", "goblin"],
		["slime", "goblin", "skeleton"],
		["slime", "goblin", "skeleton", "archer"],
		["elite"],
		["ghost", "corrupted_slime"],
		["ghost", "corrupted_slime", "corrupted_goblin"],
		["ghost", "corrupted_slime", "corrupted_goblin", "corrupted_skeleton"],
		["ghost", "corrupted_slime", "corrupted_goblin", "corrupted_skeleton", "corrupted_archer"],
		["lord"],
	]
	for index in range(game.floors.size()):
		var definition: FloorDefinition = game.floors[index]
		var encountered: Dictionary = {}
		_check_text_request(definition.tip_key, {})
		check(not definition.waves.is_empty(), "F%d has combat" % (index + 1))
		for group in definition.waves:
			check(not group.is_empty(), "every wave has enemies")
			for kind in group:
				check(kind in roster[index], "F%d may spawn %s" % [index + 1, kind])
				encountered[kind] = true
		check(encountered.size() == roster[index].size(), "F%d spawns all listed enemies" % (index + 1))
		for salt in range(48):
			var rng := RandomNumberGenerator.new()
			rng.seed = hash([index, salt])
			var layout := ArenaLayout.new()
			layout.generate(definition, rng, index + 1)
			var landmarks := ArenaLayout.protected_points(definition)
			check(layout.obstacles.size() == definition.obstacle_count and layout.connected(landmarks), "seeded cover preserves all F%d routes" % (index + 1))
			var reloaded := ArenaLayout.new()
			check(reloaded.restore(layout.obstacles, definition), "seeded layout passes save validation")
		for id in definition.clear_pickups.values():
			check(GameData.is_item(id), "floor item is registered: " + id)
			_check_text_request(GameData.name_key(id), {})
	for id in GameData.BOOKS:
		for suffix in ["TITLE", "BODY", "DESC"]:
			_check_text_request("%s_%s" % [id, suffix], {})
	for id in GameData.ENEMIES:
		var name_key := "ENEMY_%s_NAME" % id.to_upper()
		var desc_key := "ENEMY_%s_DESC" % id.to_upper()
		_check_text_request(name_key, {})
		_check_text_request(desc_key, GameData.ENEMIES[id])
	game.free()

func _test_weapons_and_stats() -> void:
	var inventory := RunInventory.new()
	var player = PlayerScene.instantiate()
	root.add_child(player)
	check(inventory.add("START_SWORD") and inventory.current_weapon() == "START_SWORD", "first pickup equips the sword")
	check(inventory.add("START_STAFF") and inventory.current_weapon() == "START_SWORD", "second weapon stays in the bag")
	player.set_loadout(inventory.equipped, inventory.corruption)
	player.can_attack = true
	player.aim = Vector2.RIGHT
	player.attack()
	check(player.attack_ready_in() > 0.0, "sword swing starts its own interval")
	var remaining: float = player.attack_ready_in()
	inventory.equip("START_STAFF")
	player.set_loadout(inventory.equipped, inventory.corruption)
	var cast := [0]
	player.projectile_requested.connect(func(_origin, _heading, _damage): cast[0] += 1)
	player.attack()
	check(cast[0] == 1 and player.attack_ready_in() > remaining, "the same attack input uses a staff with distinct cooldown")
	inventory.equip("START_SWORD")
	player.set_loadout(inventory.equipped, inventory.corruption)
	check(is_equal_approx(player.attack_ready_in(), remaining), "switching back preserves the sword timer")
	check(not inventory.enhance("max_hp"), "upgrade without a bead does nothing")
	inventory.absorb_blood_bead()
	check(inventory.enhance("max_hp") and inventory.blood_beads == 0, "one bead buys one rank")
	inventory.add("U07")
	inventory.equip("U07")
	player.set_loadout(inventory.equipped, inventory.corruption)
	check(player.max_hp == 135.0, "corruption and armor add to the same health cap")
	inventory.unequip("U07")
	player.set_loadout(inventory.equipped, inventory.corruption)
	check(player.max_hp == 110.0, "changing out of armor retains corruption")
	for i in range(4):
		inventory.absorb_blood_bead()
		inventory.enhance("max_hp")
	inventory.absorb_blood_bead()
	check(not inventory.enhance("max_hp") and inventory.blood_beads == 1, "rank cap preserves an unspent bead")
	inventory.add("MUSHROOM")
	check(not inventory.craft_potion() and inventory.count("MUSHROOM") == 1, "failed craft leaves ingredients untouched")
	inventory.add("WATER")
	check(inventory.craft_potion() and inventory.count("POTION") == 1 and inventory.stacks.size() == 1, "craft takes ingredients and adds potion together")
	player.queue_free()
	await process_frame

func _test_corruption_cards() -> void:
	for weapon in ["START_SWORD", "START_STAFF"]:
		for run_seed in range(24):
			var inventory := RunInventory.new()
			inventory.add(weapon)
			for floor_number in range(2, 11):
				var options := Boons.offer(run_seed, floor_number, inventory.owned, inventory.boon_history, PlayerStats.WEAPONS, weapon)
				check(options.size() == 3 and options[0] != options[1] and options[1] != options[2] and options[2] != options[0],
					"three unique corruption options at every stair")
				check(options == Boons.offer(run_seed, floor_number, inventory.owned, inventory.boon_history, PlayerStats.WEAPONS, weapon),
					"corruption options repeat on identical inputs")
				var unavailable := "RUNE" if weapon == "START_SWORD" else "KEEN"
				check(unavailable not in options, "a single weapon never offers unusable weapon damage")
				check(options.any(func(id: String): return Boons._weapon_mode(id, false).is_empty()),
					"all corruption offers include a benefit independent of loadout")
				var tactical := options.filter(func(id: String): return not Boons.CARDS[id].has("stats"))
				var numerical := options.filter(func(id: String): return Boons.CARDS[id].has("stats"))
				check(not tactical.is_empty() and not numerical.is_empty(), "stacked mechanics retain both card families")
				if not tactical.is_empty():
					var choice: String = tactical[0]
					check(inventory.choose_boon(floor_number, choice) and not inventory.choose_boon(floor_number, choice),
						"each stair accepts one rank even with repeat input")
	var player := PlayerScene.instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.position = Vector2(646, 325)
	player.set_loadout({"weapon": "START_SWORD"}, {"max_hp": 1}, {"HIDE": 1, "WARD": 1, "RECOVERY": 1, "SURVIVOR": 1})
	check(player.max_hp == 118.0, "corruption and blood bead enhancement share actual stat calculation")
	player.take_damage(10.0, "trap")
	check(player.hp == 90.0 and not player.boon_triggers.has("ward_used"), "traps do not consume the first-hit ward")
	player.invulnerability = 0.0
	player.take_damage(10.0, "enemy")
	check(player.hp == 83.0 and player.boon_triggers.ward_used, "first direct hit receives the ward discount")
	player.hp = 30.0
	player.drink_potion()
	check(player.hp == 72.0 and player.boon_triggers.recovery_used, "survivor and once-per-room dusk recovery combine")
	player.hp = 30.0
	player.drink_potion()
	check(player.hp == 64.0, "dusk recovery only applies on the first eligible drink")
	player.reset_floor_effects()
	check(player.boon_triggers.is_empty(), "room-limited mechanisms reset on arrival")
	for weapon: String in ["START_SWORD", "START_STAFF"]:
		player.reset_floor_effects()
		player.set_loadout({"weapon": weapon}, {}, {"AFTERSTEP": 1})
		player.can_attack = true
		player.attack()
		var recovery: float = player.boon_triggers.get("step_delay", 0.0)
		check(recovery > 0.0 and not player.boon_triggers.has("step_speed"), "Afterstep waits for weapon recovery")
		player._physics_process(recovery * 0.5)
		check(not player.boon_triggers.has("step_speed"), "no speed increase during the attack animation")
		player._physics_process(recovery * 0.51)
		check(player.boon_triggers.get("step_speed", 0.0) > 1.25, "Afterstep activates at the end of weapon recovery")
	player.free()
	await process_frame

func _test_arrow_plate_and_pot() -> void:
	var world := Node2D.new()
	root.add_child(world)
	var player = PlayerScene.instantiate()
	world.add_child(player)
	var features = load("res://scenes/world/floor_features.tscn").instantiate()
	world.add_child(features)
	features.setup(player, player.layout, 0, 81)
	features.enabled = true
	var baseline: Dictionary = features.snapshot()
	check(FloorFeatures.validate_snapshot(baseline, player.layout, 0, 81), "floor state passes validation")
	var pot: Node2D = features.pots[0].node
	pot.take_damage(1.0)
	check(not pot.alive, "pot damage breaks the pot")
	var broken: Dictionary = features.snapshot()
	check(broken != baseline and features.restore(broken) and features.snapshot() == broken, "pot break persists only once")
	player.position = features.plates[0].position
	features._physics_process(0.02)
	features._physics_process(WorldSettings.PLATE_WARNING + 0.02)
	var moving_arrow: Dictionary = features.snapshot()
	check(features.arrows.size() == 1 and features.restore(moving_arrow) and features.snapshot() == moving_arrow, "active trap arrow restores on the same frame of its flight")
	world.queue_free()
	await process_frame

func _test_recorded_audio() -> void:
	var sound := Sound.new()
	root.add_child(sound)
	for key in ["grounds", "ending", "altar", "cadence"]:
		var score := sound._read_ogg("music", key)
		check(score != null and score.loop == (key in ["grounds", "ending"]), "music loop metadata for " + key)
	for key in ["tower", "elite", "rift", "lord"]:
		sound._start_score(key)
		var stems := sound.music_player.stream as AudioStreamSynchronized
		check(stems != null and stems.stream_count == 4, "four synchronized parts for " + key)
		for i in stems.stream_count:
			var clip := stems.get_sync_stream(i) as AudioStreamOggVorbis
			check(clip != null and clip.loop and is_equal_approx(clip.get_length(), stems.get_length()), "aligned loop for %s part %d" % [key, i])
	for key in ["sword", "footstep", "magic", "hit_bone", "hit_metal", "hit_flesh", "trap_warn"]:
		var variants := sound._effect(key) as AudioStreamRandomizer
		check(variants != null and variants.streams_count >= 3 and variants.playback_mode == AudioStreamRandomizer.PLAYBACK_RANDOM_NO_REPEATS, "distinct consecutive takes for " + key)
		var take := variants.get_stream(0) as AudioStreamWAV
		check(take.mix_rate == 44100 and not take.stereo and take.format == AudioStreamWAV.FORMAT_16_BITS, "uncompressed spatial Foley for " + key)
	for bus in [Sound.AMBIENCE_BUS, Sound.ROOM_BUS, Sound.PRIORITY_BUS]:
		check(AudioServer.get_bus_send(AudioServer.get_bus_index(bus)) == Sound.EFFECTS_BUS, "effects slider includes " + bus)
	sound.queue_free()
	await process_frame

func _new_game(locale: String) -> Node:
	var game = MainScene.instantiate()
	game.save_path = temp_save
	game.codex_path = temp_codex
	var loc := AuditedLocalization.new()
	loc.name = "Localization"
	loc.settings_path = temp_settings
	game.get_node("Localization").free()
	game.add_child(loc)
	loc.text_requested.connect(_check_text_request)
	root.add_child(game)
	loc.set_language(locale)
	return game

func _restart_game(game: Node, locale: String) -> Node:
	game._save_and_menu()
	check(game.state == RunController.State.MENU and game.ui.menu_continue.visible, "the normal pause save flow returns to a resumable menu")
	game.free()
	paused = false
	await process_frame
	var next := _new_game(locale)
	next.ui.continue_pressed.emit()
	return next

func _finish_transition(game: Node) -> void:
	game._process(game.TRANSITION_TIME)
	if game.ui.boon_panel.visible:
		check(game._stair_offer.size() == 3 and not game.player.can_move, "stair transition waits for three-way corruption")
		var choice: String = game._stair_offer[0]
		game.ui.boon_chosen.emit(choice)
		game.ui.boon_chosen.emit(choice)
		check(game.inventory.boon_history.get(game.floor_number) == choice, "a destination grants exactly one corruption")
		game._process(game.TRANSITION_TIME)
	await process_frame

func _spawn_wave(game: Node) -> void:
	game.floor_manager._process(3.0)
	check(game.floor_manager.wave_in_progress(), "expected wave spawns via FloorManager")

func _defeat_wave(game: Node) -> void:
	for enemy in game.floor_manager.enemies.duplicate():
		enemy.set_spawn_delay(0.0)
		enemy.take_damage(100000.0)
	await process_frame

func _collect_at(game: Node, id: String) -> bool:
	for node in game.pickups.get_children():
		if node.item_id == id:
			game.player.position = node.position
			game._update_world_interactions()
			check(node.get_parent() == game.pickups, "walking onto an item does not collect it")
			game._interact()
			return node.get_parent() != game.pickups
	return false

func _test_full_run(locale: String, checkpoints: bool) -> void:
	var game = _new_game(locale)
	check(game.ui.menu.visible and not game.grounds.visible and not game.arena.visible, "title page is independent of the live world")
	game.ui.start_pressed.emit()
	check(game.state == RunController.State.OPENING and not game.grounds.visible, "start leads to tower-front transition before showing the grounds")
	if checkpoints:
		game = await _restart_game(game, locale)
		check(game.state == RunController.State.OPENING, "the opening transition resumes once")
	await _finish_transition(game)
	check(game.state == RunController.State.GROUNDS, "opening leads to free control at the tower front")
	check(game.camera.zoom.is_equal_approx(Vector2(1.35, 1.35)), "camera shows 20 percent more world on each axis")
	game.player.position = game.entrance.position
	game._update_world_interactions()
	check(not is_instance_valid(game.ghost), "approaching the tower door leaves the player in control")
	if checkpoints:
		game._interact()
		check(is_instance_valid(game.ghost), "interacting unarmed triggers the knight ghost")
		game._process(1.4)
		game = await _restart_game(game, locale)
		check(is_instance_valid(game.ghost) and game.ghost.elapsed >= 1.4 and not game.player.can_move,
			"resuming the knight scene restores the gesture and input lock")
		game._process(RunController.Ghost.DURATION + 0.02)
		check(game.ghost_seen and not is_instance_valid(game.ghost), "ghost ends with a persistent weapon hint")
	var first_weapon := "START_SWORD" if checkpoints else "START_STAFF"
	check(_collect_at(game, first_weapon) and game.inventory.current_weapon() == first_weapon, "one picked-up weapon activates immediately")
	check(_collect_at(game, "LORE_KIT") and game.ui.top_overlay() == null, "manuscript pickup does not pause or open text")
	game.ui.show_inventory(game.inventory, game.player, game.codex)
	game.ui.inventory_requested.emit("read", "LORE_KIT")
	check(game.ui.top_overlay() == game.ui.lore and "LORE_KIT" in game.codex.read, "opening manuscript marks it read")
	game.ui.pop_overlay()
	game.ui.pop_overlay()
	game.player.position = game.entrance.position
	game._interact()
	check(game.state == RunController.State.TRANSITION and game.floor_number == 1, "equipping either starter permits entry")
	check(not is_instance_valid(game.ghost) and game.ghost_seen == checkpoints, "having a weapon skips the ghost when the player goes straight to the gate")
	var starting_seed: int = game.seed
	if checkpoints:
		var legacy: Dictionary = game.saves.load_latest().data
		legacy.transition = 1.55
		check(not RunSave.prepare_resume(legacy, game.floors).is_empty(), "version 2 saves from a 2.1 second transition are still accepted")
		game = await _restart_game(game, locale)
		check(game.state == RunController.State.TRANSITION and game.seed == starting_seed, "F1 entry resumes with the same seed")
	for floor_number in range(1, 11):
		await _finish_transition(game)
		if floor_number == 10:
			check(game.state == RunController.State.DIALOGUE and game.floor_manager.enemies.is_empty(), "the F10 opening dialogue precedes combat")
			check(game.features.get_node_or_null("SummitCrystal") != null, "the summit crystal exists before combat")
			check(is_instance_valid(game.lord_preview) and game.lord_preview.position == ArenaLayout.LORD_INTRO_POSITION, "lord is visible at the protected dialogue position")
			game.ui._advance_dialogue()
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.DIALOGUE and game.ui.dialogue_line == 1, "unfinished dialogue resumes on the same line")
			while game.state == RunController.State.DIALOGUE:
				game.ui._advance_dialogue()
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.COMBAT and game.lord_introduced, "completed dialogue does not replay on combat resume")
		check(game.floor_number == floor_number and game.state == RunController.State.COMBAT, "transitions enter the expected floor exactly once")
		if floor_number == 5:
			check(game.current_floor.waves.size() == 1, "F5 has one miniboss encounter")
			if checkpoints:
				var former: Dictionary = game._snapshot()
				former.next_wave = 1
				former.wave_drops = ["WATER"]
				var migrated := RunSave.prepare_resume(former, game.floors)
				check(not migrated.is_empty() and migrated.data.next_wave == 0, "legacy second elite wave restores the single boss")
		for wave_idx in range(game.current_floor.waves.size()):
			_spawn_wave(game)
			if floor_number == 5:
				var boss: Node2D = game.floor_manager.boss()
				boss.set_spawn_delay(0.0)
				game._spawn_projectile(game.player.position, Vector2.RIGHT, 12.0, false)
				game._spawn_projectile(game.player.position, Vector2.RIGHT, 12.0, true)
				game._spawn_projectile(game.player.position, Vector2.RIGHT, 12.0, false)
				var shots: Array[Node] = game.projectiles.get_children()
				shots[2].trap_arrow = true
				var hp: float = game.player.hp
				boss.take_damage(boss.max_hp * 0.46)
				shots[0]._physics_process(0.01)
				check(boss.boss_stage == 2 and shots[0].consumed and not shots[0].visible and game.player.hp == hp,
					"boss phase transition hides and disarms the previous phase shots immediately")
				check(not shots[1].consumed and not shots[2].consumed,
					"boss phase transition leaves player shots and trap arrows active")
			if floor_number == 10:
				check(game.floor_manager.enemies[0].position == ArenaLayout.LORD_INTRO_POSITION, "boss enters combat at its dialogue position")
			if checkpoints and floor_number == 2 and wave_idx == 0:
				var live_position: Vector2 = game.player.position
				var world_state: Dictionary = game.features.snapshot()
				var old_hp: float = game.player.hp
				game.player.take_damage(4.0)
				game.features.pots[0].node.take_damage(1.0)
				var previous_water: int = game.inventory.count("WATER")
				game._add_pickup("WATER", game.player.position)
				game._update_world_interactions()
				check(game.inventory.count("WATER") == previous_water, "live pickup needs interaction")
				game._interact()
				check(game.inventory.count("WATER") > previous_water, "pickup during a wave succeeds")
				game = await _restart_game(game, locale)
				check(game.player.position == live_position and game.features.snapshot() == world_state and game.player.hp == old_hp, "position, HP and props roll back to wave opening")
				check(game.inventory.count("WATER") == previous_water and "WATER" in game.codex.items, "wave loot rolls back while discovery persists")
				_spawn_wave(game)
			if floor_number == 10:
				game.player.position = ArenaLayout.EXIT_POSITION
			await _defeat_wave(game)
		if floor_number == 10:
			check(game.state == RunController.State.AFTERMATH and not game.player.can_move, "defeating the lord starts its last bubbles")
			check(game.ui.speaker_keys == ["ENEMY_LORD_NAME", "ENEMY_LORD_NAME", "ENEMY_LORD_NAME"], "the protagonist is silent after the fight")
			game.ui._advance_dialogue()
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.AFTERMATH and game.ui.dialogue_line == 1,
					"resuming after the lord's defeat continues the right bubble")
			while game.state == RunController.State.AFTERMATH:
				game.ui._advance_dialogue()
			game._update_world_interactions()
			check(game.state == RunController.State.SAFE and game.player.can_move, "the crystal awaits an explicit touch even when under the player")
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.SAFE and game.lord_introduced, "defeated lord and open gate restore")
			check(_collect_at(game, "LORE_F5") and game.state == RunController.State.SAFE, "summit manuscript is optional")
			game.player.position = ArenaLayout.EXIT_POSITION
			game._update_world_interactions()
			check(game.state == RunController.State.SAFE, "approaching the crystal does not trigger it")
			var live_arrow := ProjectileScene.instantiate()
			game.features.add_child(live_arrow)
			live_arrow.trap_arrow = true
			live_arrow.setup(game.player.position, Vector2.DOWN, 40.0, false, game.player)
			game.features.arrows.append(live_arrow)
			var before_touch: float = game.player.hp
			game._interact()
			check(game.state == RunController.State.ENDING, "interacting with the crystal begins the ending")
			live_arrow._physics_process(0.05)
			check(live_arrow.consumed and game.features.arrows.is_empty() and game.player.hp == before_touch,
				"touching the crystal cancels in-flight trap arrows before the locked ending")
			if checkpoints:
				var defeated_at: Vector2 = game.lord_preview.position
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.ENDING and is_instance_valid(game.lord_preview)
					and game.lord_preview.position == defeated_at,
					"resuming before the crystal impact keeps the defeated lord at the saved position")
				game._process(1.7)
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.ENDING, "final transition is resumable without replaying combat")
			break
		check(game.state == RunController.State.SAFE and game.player.can_move, "clear unlocks exploration before any transition")
		check(game.pearl_available, "one bead forms after clearing a nonfinal floor")
		if checkpoints and floor_number == 1:
			game = await _restart_game(game, locale)
			check(game.pearl_available and game.inventory.blood_beads == 0, "unclaimed altar resumes")
			check(_collect_at(game, "MUSHROOM") and _collect_at(game, "WATER"), "clear rewards give materials")
		if floor_number != 3:
			var before: int = game.inventory.blood_beads
			game.player.position = ArenaLayout.ALTAR_POSITION
			game._interact()
			game._interact()
			check(game.inventory.blood_beads == before + 1 and not game.pearl_available, "the altar can be absorbed once")
		if checkpoints and floor_number == 1:
			game = await _restart_game(game, locale)
			check(not game.pearl_available and game.inventory.blood_beads == 1, "claimed but unspent bead resumes")
			var material_counts: Dictionary = game.inventory.stacks.duplicate()
			game.ui.show_inventory(game.inventory, game.player, game.codex)
			game.ui.inventory_requested.emit("enhance", "max_hp")
			game.ui.inventory_requested.emit("enhance", "max_hp")
			check(game.inventory.corruption.max_hp == 1 and game.ui.magic_feedback_active(),
				"successful bead purchase plays one enhancement sequence")
			game.ui.inventory_requested.emit("craft", "")
			game.ui.pop_overlay()
			game = await _restart_game(game, locale)
			check(game.player.max_hp == 110.0 and game.inventory.blood_beads == 0, "spent bead, upgrade and health cap restore")
			var potions: int = material_counts.get("POTION", 0) + 1
			check(game.inventory.count("POTION") == potions, "the crafted potion restores")
			for id in GameData.POTION_RECIPE:
				check(game.inventory.count(id) == material_counts[id] - GameData.POTION_RECIPE[id], "craft consumption restores for " + id)
			var run: RunSave = game.saves
			var malformed: Dictionary = run.load_latest().data
			malformed.phase = "invalid"
			check(run.write(malformed) == OK, "write a hash-valid but malformed primary save")
			game.show_menu()
			check(game.ui.menu_continue.visible and game.ui.status_key == "UI_SAVE_RECOVERED", "invalid primary falls back to the same run")
			game.ui.continue_pressed.emit()
			check(game.seed == starting_seed and game.inventory.count("POTION") == potions, "recovered backup preserves the same run")
			check(game._save_run(), "first write after backup recovery succeeds")
			check(not RunSave.prepare_resume(run.load_backup().data, game.floors).is_empty(), "recovery keeps the last valid backup")
			var damaged := FileAccess.open(run.path, FileAccess.WRITE)
			damaged.store_string("corrupted")
			damaged.close()
			game.show_menu()
			check(game.ui.menu_continue.visible and game.ui.status_key == "UI_SAVE_RECOVERED", "backup also survives a second unreadable primary")
			game.ui.continue_pressed.emit()
		if floor_number == 3:
			game.player.position = ArenaLayout.STAIRS_POSITION + Vector2(0, 65.0)
			game._update_world_interactions()
			check(game.ui.status_key == "UI_STAIR_FORFEIT", "unclaimed bead warns on approach to the stairs")
		game.player.position = ArenaLayout.STAIRS_POSITION
		game._update_world_interactions()
		check(game.state == RunController.State.TRANSITION and game.floor_number == floor_number + 1, "walking up stairs advances one level")
		if checkpoints and floor_number == 1:
			game._process(0.36)
			check(game.arena.floor_number == 1 and game.player.position.y < ArenaLayout.STAIRS_POSITION.y,
				"the ordinary transition follows the hero through the departing arch")
			game = await _restart_game(game, locale)
			check(game.state == RunController.State.TRANSITION and game.arena.floor_number == 1,
				"resuming partway through the climb restores the departing geometry")
			game._process(3.0)
			var offer: Array[String] = game._stair_offer.duplicate()
			game = await _restart_game(game, locale)
			check(game.ui.boon_panel.visible and game._stair_offer == offer, "three candidates and waiting step restore exactly")
			var old_checkpoint: Dictionary = game.saves.load_latest().data.duplicate(true)
			old_checkpoint.stair_offer = Boons.legacy_offer(game.seed, 2, game.inventory.owned,
				game.inventory.boon_history, PlayerStats.WEAPONS)
			check(not RunSave.prepare_resume(old_checkpoint, game.floors).is_empty(),
				"saved offers from the first 0.4.0-dev build keep their exact cards")
			game.ui.boon_chosen.emit(offer[0])
			game = await _restart_game(game, locale)
			check(game.inventory.boon_history.get(2) == offer[0] and not game.ui.boon_panel.visible,
				"the selected corruption survives a restart before entering F2")
	await _finish_transition(game)
	check(game.inventory.boon_history.size() == 9, "exactly nine stair choices in a complete run")
	check(game.state == RunController.State.VICTORY and game.ui.result.visible, "only the ending transition completes victory")
	check(game.saves.load_latest().error == ERR_FILE_NOT_FOUND and game.saves.load_backup().error == ERR_FILE_NOT_FOUND, "victory retires the run and backup")
	check(game.codex.enemies.size() == GameData.ENEMIES.size(), "all eleven enemy discoveries survive completion")
	game.ui.menu_pressed.emit()
	game.ui.codex_pressed.emit()
	game.ui.inventory_requested.emit("read", "LORE_KIT")
	check(game.ui.top_overlay() == game.ui.lore, "main menu allows cross-run rereading")
	game.free()
	paused = false
	await process_frame

func _test_defeat() -> void:
	var game := _new_game("en_US")
	game.start_run()
	await _finish_transition(game)
	game.player.take_damage(1000.0)
	check(game.state == RunController.State.GAME_OVER and game.ui.result.visible, "lethal damage triggers defeat even outside combat")
	check(game.saves.load_latest().error == ERR_FILE_NOT_FOUND, "defeat retires the current run")
	game.ui.start_pressed.emit()
	check(game.state == RunController.State.OPENING and game.inventory.owned.is_empty() and game.inventory.blood_beads == 0, "restart resets the run's items and beads")
	check("LORE_KIT" in game.codex.read, "restart retains codex reading history")
	game.ui.menu_pressed.emit()
	game.ui.start_pressed.emit()
	check(game.ui.top_overlay() == game.ui.overwrite, "starting over an incomplete run requires confirmation")
	game.free()
	paused = false
	await process_frame
