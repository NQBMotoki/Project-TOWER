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
const RetroScore = preload("res://scripts/retro_score.gd")
const RunController = preload("res://scripts/run_controller.gd")
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
	await _test_arrow_plate_and_pot()
	_test_retro_score()
	if failures.is_empty():
		await _test_full_run("zh_CN", true)
		await _test_full_run("en_US", false)
		await _test_defeat()
	RunSave.new(temp_save).invalidate()
	for path in [temp_settings, temp_codex]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
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

func _test_retro_score() -> void:
	var lengths: Array[int] = []
	for track in ["grounds", "tower", "lord", "ending"]:
		var score := RetroScore.render(track)
		check(score.mix_rate == 22050 and not score.stereo and score.format == AudioStreamWAV.FORMAT_16_BITS, "PCM spec for " + track)
		check(score.loop_mode == AudioStreamWAV.LOOP_FORWARD and score.loop_end == score.data.size() / 2, "the loop spans " + track)
		check(score.loop_end > 2 * score.mix_rate and score.data.decode_s16(824) != 0, "score contains music for " + track)
		check(score.loop_end not in lengths, "each track has its own tempo")
		lengths.append(score.loop_end)

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
			return true
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
	check(is_instance_valid(game.ghost), "approaching unarmed triggers the knight ghost")
	game._process(4.0)
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
	var starting_seed: int = game.seed
	if checkpoints:
		game = await _restart_game(game, locale)
		check(game.state == RunController.State.TRANSITION and game.seed == starting_seed, "F1 entry resumes with the same seed")
	for floor_number in range(1, 11):
		await _finish_transition(game)
		if floor_number == 10:
			check(game.state == RunController.State.DIALOGUE and game.floor_manager.enemies.is_empty(), "the F10 opening dialogue precedes combat")
			check(is_instance_valid(game.lord_preview) and game.lord_preview.position == ArenaLayout.LORD_INTRO_POSITION, "lord is visible at the protected dialogue position")
			game.ui._advance_dialogue()
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.DIALOGUE and game.ui.dialogue_line == 0, "unfinished dialogue resumes at its first line")
			while game.state == RunController.State.DIALOGUE:
				game.ui._advance_dialogue()
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.COMBAT and game.lord_introduced, "completed dialogue does not replay on combat resume")
		check(game.floor_number == floor_number and game.state == RunController.State.COMBAT, "transitions enter the expected floor exactly once")
		for wave_idx in range(game.current_floor.waves.size()):
			_spawn_wave(game)
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
				check(game.inventory.count("WATER") > previous_water, "pickup during a wave succeeds")
				game = await _restart_game(game, locale)
				check(game.player.position == live_position and game.features.snapshot() == world_state and game.player.hp == old_hp, "position, HP and props roll back to wave opening")
				check(game.inventory.count("WATER") == previous_water and "WATER" in game.codex.items, "wave loot rolls back while discovery persists")
				_spawn_wave(game)
			if floor_number == 10:
				game.player.position = ArenaLayout.EXIT_POSITION
			await _defeat_wave(game)
			if checkpoints and floor_number == 5 and wave_idx == 0:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.COMBAT and game._next_wave == 1, "resume between elite waves starts the second wave")
		check(game.state == RunController.State.SAFE and game.player.can_move, "clear unlocks exploration before any transition")
		if floor_number == 10:
			game._update_world_interactions()
			check(game.state == RunController.State.SAFE, "killing the lord while standing on the exit requires a fresh approach")
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.SAFE and game.lord_introduced, "defeated lord and open gate restore")
			check(_collect_at(game, "LORE_F5") and game.state == RunController.State.SAFE, "summit manuscript is optional")
			game.player.position = ArenaLayout.EXIT_POSITION
			game._update_world_interactions()
			check(game.state == RunController.State.ENDING, "walking into open exit begins final transition")
			if checkpoints:
				game = await _restart_game(game, locale)
				check(game.state == RunController.State.ENDING, "final transition is resumable without replaying combat")
			break
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
	await _finish_transition(game)
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
