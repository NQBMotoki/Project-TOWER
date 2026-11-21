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
const RewardManager = preload("res://scripts/reward_manager.gd")
const LOCALES := ["zh_CN", "en_US"]
const CATEGORIES := ["menu", "hud", "transition", "narrative", "equipment", "reward", "result", "input"]
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
	var test_path := temp_dir.path_join("tower-test-%s" % Time.get_ticks_usec())
	temp_settings = test_path + ".cfg"
	temp_save = test_path + ".save"
	await _test_localization()
	_test_floor_resources()
	await _test_combat_and_equipment()
	await _test_cover()
	_test_loot_and_layouts()
	if failures.is_empty():
		for locale in LOCALES:
			await _test_full_run(locale)
		# The same entry, combat, and epilogue rules must work in a different slot.
		await _test_full_run("en_US", true)
		await _test_controls_pause_and_crafting()
		await _test_saving()
	RunSave.new(temp_save).invalidate()
	DirAccess.remove_absolute(temp_settings)
	if failures.is_empty():
		print("PASS: %d checks (localization, combat, inventory, cover, five-floor flow, persistence)" % checks)
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
	check(translation_variables.get(key) == names, "UI supplied %s for %s, expected %s" % [names, key, translation_variables.get(key)])

func _test_floor_resources() -> void:
	var game = MainScene.instantiate()
	var manager = game.get_node("FloorManager")
	check(game.floors.size() == 5, "main scene has five floors")
	for index in range(game.floors.size()):
		var floor: FloorDefinition = game.floors[index]
		var level := "floor %d" % (index + 1)
		check(floor != null, level + " has a definition")
		if floor == null:
			continue
		check(floor.epilogue.is_empty() == (index < game.floors.size() - 1), level + " ends the run only in the last slot")
		check(floor.wait_for_confirmation, level + " waits for the player at entry")
		_check_text_request(floor.tip_key, {})
		if not floor.entry_note_key.is_empty():
			_check_text_request(floor.entry_note_key, {})
		for id in floor.clear_pickups.values():
			check(GameData.is_item(id), level + " has a valid guaranteed pickup")
			_check_text_request(GameData.name_key(id), {})
			if GameData.is_book(id):
				_check_text_request(id + "_BODY", {})
		if not floor.epilogue.is_empty():
			_check_text_request(floor.epilogue + "_TITLE", {})
			_check_text_request(floor.epilogue + "_BODY", {})
		check(not floor.waves.is_empty(), level + " has combat waves")
		var enemy_types := []
		for wave in floor.waves:
			check(not wave.is_empty(), level + " has no empty waves")
			for enemy in wave:
				check(GameData.ENEMIES.has(enemy) and manager.SCENES.has(enemy), level + " can spawn " + enemy)
			enemy_types.append_array(wave)
		check(floor.clear_on_enemy_defeat.is_empty() or enemy_types.has(floor.clear_on_enemy_defeat), level + " spawns its configured clear target")
	game.free()

func _test_combat_and_equipment() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player = PlayerScene.instantiate()
	arena.add_child(player)
	player.position = Vector2(400, 300)
	player.can_attack = true
	player.crit_chance = 0.0
	player.aim = Vector2.RIGHT
	var a = SlimeScene.instantiate()
	var b = SlimeScene.instantiate()
	for enemy in [a, b]:
		enemy.setup("slime", player)
		arena.add_child(enemy)
		enemy.position = player.position + Vector2(40, 0)
		enemy.set_physics_process(false)
	player.attack_sword()
	check(is_equal_approx(a.hp, 14.0) and is_equal_approx(b.hp, 14.0), "one sword swing damages each enemy once and can hit multiple")
	player.hp = 80
	player.set_equipment({"sword": "U06", "magic": "START_STAFF"})
	player.crit_chance = 0.0
	player.attack_sword()
	check(a.alive and is_equal_approx(a.hp, 2.0) and is_equal_approx(player.hp, 80.0), "a second swing does not yet kill a slime")
	player.attack_sword()
	check(not a.alive and not b.alive and is_equal_approx(player.hp, 90.0), "sword kills heal once per enemy")
	var c = SlimeScene.instantiate()
	c.setup("slime", player)
	arena.add_child(c)
	c.position = player.position + Vector2(100, 0)
	c.set_physics_process(false)
	var projectile = ProjectileScene.instantiate()
	arena.add_child(projectile)
	projectile.setup(player.position, Vector2.RIGHT, 20.0, true, player)
	projectile._physics_process(0.25)
	check(is_equal_approx(c.hp, 6.0) and projectile.consumed, "friendly projectile hits once and is consumed")
	check(is_equal_approx(player.hp, 90.0), "friendly projectile does not hit the player")
	var hostile = ProjectileScene.instantiate()
	arena.add_child(hostile)
	hostile.setup(player.position + Vector2(50, 0), Vector2.LEFT, 10.0, false, player)
	hostile._physics_process(0.3)
	check(is_equal_approx(player.hp, 80.0) and hostile.consumed, "hostile projectile damages the player once")
	player.take_damage(10.0)
	check(is_equal_approx(player.hp, 80.0), "damage immunity prevents immediate repeat damage")
	player.invulnerability = 0.0
	c.position = player.position
	c.attack_timer = 0.0
	c.spawn_delay = 0.8
	c._behavior(0.01)
	check(is_equal_approx(player.hp, 80.0), "newly spawned enemy cannot immediately damage player")
	c.spawn_delay = 0.0
	c._behavior(0.01)
	check(is_equal_approx(player.hp, 72.0), "slime damages on contact after spawn protection")
	var goblin = GoblinScene.instantiate()
	goblin.setup("goblin", player)
	arena.add_child(goblin)
	goblin.set_physics_process(false)
	goblin.position = player.position + Vector2(35, 0)
	goblin.spawn_delay = 0.0
	goblin.attack_timer = 0.0
	goblin._behavior(0.01)
	check(goblin.windup > 0.0, "goblin telegraphs its strike")
	player.position += Vector2(120, 0)
	player.invulnerability = 0.0
	goblin._behavior(0.51)
	check(is_equal_approx(player.hp, 72.0), "moving away avoids the telegraphed strike")
	var dummy = PlayerScene.instantiate()
	arena.add_child(dummy)
	dummy.position = Vector2(320, 500)
	var cycle = SlimeScene.instantiate()
	cycle.setup("slime", dummy)
	arena.add_child(cycle)
	cycle.set_physics_process(false)
	cycle.position = dummy.position + Vector2(400, 0)
	cycle.spawn_delay = 0.0
	cycle.attack_timer = 1.0
	cycle._behavior(0.01)
	check(cycle.phase == 0, "a slime creeps while the player is far away")
	cycle.position = dummy.position + Vector2(100, 0)
	cycle.attack_timer = 1.0
	cycle._behavior(0.01)
	check(cycle.phase == 1, "a slime coils before it lunges")
	var coil_position: Vector2 = cycle.position
	cycle._behavior(0.8)
	check(cycle.phase == 2, "a coiled slime lunges")
	cycle._behavior(0.1)
	check(cycle.position.distance_to(coil_position) > 30.0, "the lunge covers ground quickly")
	cycle._behavior(0.15)
	check(cycle.phase == 3, "the lunge ends in a recovery")
	var dummy_hp: float = dummy.hp
	dummy.invulnerability = 0.0
	cycle.attack_timer = 0.0
	cycle._behavior(0.01)
	check(is_equal_approx(dummy.hp, dummy_hp), "a recovering slime cannot hurt the player")
	cycle.phase = 2
	cycle.phase_timer = 0.05
	cycle.position = dummy.position + Vector2(30, 0)
	cycle.lunge_dir = (dummy.global_position - cycle.global_position).normalized()
	cycle.attack_timer = 0.0
	cycle.spawn_delay = 0.0
	dummy.invulnerability = 0.0
	var dummy_before: float = dummy.hp
	cycle._behavior(0.05)
	check(dummy.hp < dummy_before, "the landing step of a lunge still lands contact")
	var archer = ArcherScene.instantiate()
	archer.setup("archer", dummy)
	arena.add_child(archer)
	archer.set_physics_process(false)
	archer.position = dummy.position + Vector2(300, 0)
	archer.spawn_delay = 0.0
	archer.attack_timer = 0.0
	var arrows := {"count": 0}
	archer.projectile_requested.connect(func(_o, _d, _v): arrows.count += 1)
	archer._behavior(0.01)
	check(archer.draw_timer > 0.0 and arrows.count == 0, "an archer draws before it fires")
	archer._behavior(0.85)
	check(arrows.count == 1, "an archer releases a single arrow")
	check(is_equal_approx(archer.shot_speed, 560.0), "the arrow travels faster than the player")
	archer.draw_timer = 0.0
	archer.attack_timer = 0.0
	archer.position = dummy.position + Vector2(200, 0)
	var gap_before: float = archer.position.distance_to(dummy.position)
	archer._behavior(0.1)
	check(archer.position.distance_to(dummy.position) > gap_before, "an archer backs off toward its minimum band")
	check(archer.draw_timer <= 0.0, "an archer does not shoot from inside its minimum band")
	archer.melee_timer = 0.0
	archer.attack_timer = 0.0
	archer.draw_timer = 0.0
	archer.position = dummy.position + Vector2(60, 0)
	dummy.invulnerability = 0.0
	archer._behavior(0.01)
	check(archer.melee_windup > 0.0 and archer.draw_timer <= 0.0, "an archer switches to melee when the player closes in")
	var hp_before_melee: float = dummy.hp
	archer._behavior(0.5)
	check(dummy.hp < hp_before_melee, "the melee windup lands its strike")
	archer.melee_windup = 0.0
	archer.melee_timer = 0.0
	archer.attack_timer = 2.0
	archer.position = dummy.position + Vector2(60, 0)
	archer._behavior(0.01)
	check(archer.melee_windup <= 0.0, "the archer cannot slash while the bow is recovering")
	var elite = EliteScene.instantiate()
	elite.setup("elite", player)
	arena.add_child(elite)
	elite.set_physics_process(false)
	elite.position = player.position + Vector2(200, 0)
	elite.spawn_delay = 0.0
	elite.attack_timer = 0.0
	var shots := {"count": 0}
	elite.projectile_requested.connect(func(_o, _d, _v): shots.count += 1)
	elite._behavior(0.01)
	check(shots.count == 0 and elite.telegraph > 0.0, "the elite warns before firing")
	elite._behavior(0.8)
	check(shots.count == 3, "elite fires three projectiles")
	var stats = PlayerScene.instantiate()
	arena.add_child(stats)
	var inventory := RunInventory.new()
	for id in ["START_SWORD", "START_STAFF", "U01", "U02", "U03", "U04", "U05", "U06", "U07", "U08"]:
		check(inventory.add(id), "collect unique item " + id)
	check(not inventory.add("U01"), "gear IDs cannot be owned twice")
	stats.set_equipment(inventory.equipped)
	check(stats.sword_damage == 12.0 and stats.magic_damage == 20.0, "carried equipment leaves base stats")
	stats.hp = 70.0
	stats.sword_timer = 0.31
	stats.magic_timer = 1.7
	for id in ["U01", "U02", "U03", "U04", "U07", "U08"]:
		inventory.equip(id)
	stats.set_equipment(inventory.equipped)
	check(is_equal_approx(stats.sword_damage, 18.0) and is_equal_approx(stats.magic_damage, 32.0), "weapon effects apply when equipped")
	check(is_equal_approx(stats.max_hp, 125.0) and is_equal_approx(stats.hp, 70.0), "armor adds maximum health")
	check(is_equal_approx(stats.speed, 212.75), "equipped boots increase movement speed")
	check(is_equal_approx(stats.sword_cooldown, 0.42 * 0.8), "equipped gloves reduce sword cooldown")
	check(is_equal_approx(stats.magic_cooldown, 2.4 * 0.75), "equipped ring reduces magic cooldown")
	check(is_equal_approx(stats.sword_timer, 0.31) and is_equal_approx(stats.magic_timer, 1.7), "equipping preserves current cooldown timers")
	inventory.equip("U05")
	inventory.equip("U06")
	stats.set_equipment(inventory.equipped)
	check(is_equal_approx(stats.crit_chance, 0.20) and is_equal_approx(stats.magic_cooldown, 2.4), "accessories replace each other")
	check(is_equal_approx(stats.sword_heal, 5.0) and is_equal_approx(stats.sword_damage, 12.0), "swords replace each other")
	check("U01" in inventory.owned and "U04" in inventory.owned, "replaced gear remains in the bag")
	stats.heal(999)
	check(is_equal_approx(stats.hp, stats.max_hp), "healing respects maximum health")
	inventory.unequip("U06")
	inventory.unequip("U03")
	inventory.unequip("U07")
	stats.set_equipment(inventory.equipped)
	check(inventory.equipped.sword == "START_SWORD" and inventory.equipped.magic == "START_STAFF", "unequipping replacement weapons restores starter weapons")
	check(is_equal_approx(stats.hp, 100.0) and is_equal_approx(stats.max_hp, 100.0), "removing armor clamps HP to the restored maximum")
	arena.queue_free()
	await process_frame

func _send_action(action: String) -> void:
	var press := InputEventAction.new()
	press.action = action
	press.pressed = true
	Input.parse_input_event(press)
	await process_frame
	var release := InputEventAction.new()
	release.action = action
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _test_cover() -> void:
	var arena := Node2D.new()
	root.add_child(arena)
	var player = PlayerScene.instantiate()
	arena.add_child(player)
	player.position = Vector2(463, 300)
	player.can_attack = true
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
	player.attack_sword()
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

func _test_loot_and_layouts() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var counts := {}
	var no_gear: Array[String] = []
	for i in range(100):
		var drop := RewardManager.drop_for_roll(i, no_gear, rng)
		counts[drop] = counts.get(drop, 0) + 1
	check(counts == {"": 55, "MUSHROOM": 20, "WATER": 15, "POTION": 10}, "drop roll covers the requested probability ranges and potion fallback")
	var available: Array[String] = ["U01", "U02"]
	for boundary in [[54, ""], [55, "MUSHROOM"], [74, "MUSHROOM"], [75, "WATER"], [89, "WATER"]]:
		check(RewardManager.drop_for_roll(boundary[0], available, rng) == boundary[1], "drop category boundary %d" % boundary[0])
	var first := RewardManager.drop_for_roll(90, available, rng)
	var last := RewardManager.drop_for_roll(99, available, rng)
	check(first != last and available.is_empty(), "equipment drops are reserved when planned")
	var all: Array[String] = RewardManager.available_equipment([])
	check(RewardManager.generate_choices(all, rng) == ["POTION", "MUSHROOM", "WATER"], "empty gear pool fills cards in the requested order")
	var partial := all.duplicate()
	partial.erase("U04")
	check(RewardManager.generate_choices(partial, rng) == ["U04", "POTION", "MUSHROOM"], "unowned equipment comes before supplies")
	for i in range(50):
		var choices := RewardManager.generate_choices(["U03"], rng)
		check(choices.size() == 3 and "U03" not in choices and choices[0] != choices[1] and choices[1] != choices[2] and choices[2] != choices[0], "reward cards are distinct and prefer unowned equipment")
	var game = MainScene.instantiate()
	var expected := [4, 5, 6, 7, 3]
	for i in range(game.floors.size()):
		var floor: FloorDefinition = game.floors[i]
		for example_seed in range(36):
			var layout := ArenaLayout.new()
			rng.seed = hash([example_seed, i])
			layout.generate(floor, rng)
			check(layout.obstacles.size() == expected[i], "floor %d obstacle count for seed %d" % [i + 1, example_seed])
			check(layout.connected(ArenaLayout.protected_points(floor)), "floor %d waypoints are connected at elite clearance" % [i + 1])
			var replay := ArenaLayout.new()
			rng.seed = hash([example_seed, i])
			replay.generate(floor, rng)
			check(replay.obstacles == layout.obstacles, "same run seed regenerates the same floor")
			if floor.keep_center_open:
				check(layout.obstacles.all(func(entry): return entry.rect.end.y <= 260 or entry.rect.position.y >= 459), "fifth-floor cover stays at the edges")
	game.free()

func _new_game(locale: String, epilogue_only := false) -> Node:
	var game = MainScene.instantiate()
	game.save_path = temp_save
	if epilogue_only:
		game.floors.assign([game.floors.back()])
	var service = game.get_node("Localization")
	service.set_script(AuditedLocalization)
	service.settings_path = temp_settings
	service.text_requested.connect(_check_text_request)
	root.add_child(game)
	game.loc.set_language(locale)
	return game

func _interact_at(game: Node, position: Vector2) -> void:
	game.player.position = position
	await _send_action("interact")

func _pickup(game: Node, id: String) -> bool:
	for item in game.pickups.get_children():
		if item.item_id == id:
			await _interact_at(game, item.position)
			return true
	return false

func _ready_transition(game: Node) -> void:
	game._process(game.transition_remaining)
	await _send_action("next")

func _spawn_wave(game: Node) -> void:
	game.floor_manager.wait_for_wave = -1.0
	game.floor_manager._spawn_wave()

func _defeat_wave(game: Node, target := "") -> void:
	for enemy in game.floor_manager.enemies.duplicate():
		if enemy.alive and (target.is_empty() or enemy.kind == target):
			enemy.take_damage(9999.0)

func _test_full_run(locale: String, epilogue_only := false) -> void:
	RunSave.new(temp_save).invalidate()
	var game := _new_game(locale, epilogue_only)
	var cleared_floors: Array[int] = []
	game.floor_manager.floor_cleared.connect(func(): cleared_floors.append(game.floor_number))
	var translation: Translation = game.loc.translations[locale]
	check(game.state == game.State.MENU and not game.ui.menu_continue.visible, "game starts at the menu without an active save")
	check(game.ui.menu_start.text == translation.get_message("UI_MENU_START"), "menu refreshes in " + locale)
	for item in GameData.UPGRADES:
		var sample: Array[String] = [item.id]
		game.ui.show_reward(sample)
		var badge: Label = game.ui.reward.get_node("Card0/IconPlaceholder").get_child(0)
		check(badge.text == translation.get_message("ITEM_%s_BADGE" % item.id), "reward badge is localized for " + item.id)
	game.ui.show_menu(false)
	game.ui.menu_start.pressed.emit()
	check(game.state == game.State.GROUNDS and game.player.can_move and not game.player.has_sword, "new run can explore the grounds")
	await _pickup(game, "START_SWORD")
	if locale == "zh_CN":
		await _interact_at(game, game.entrance.position)
		check(game.ghost != null and game.ghost.targets.size() == 1 and not game.player.can_move, "ghost points only to the missing weapon and locks movement")
		game._process(4.0)
		check(game.ghost_seen and game.player.can_move, "ghost disperses and releases movement")
		check(game.pickups.get_children().any(func(node): return node.guided and node.item_id == "START_STAFF"), "missing starter weapon stays marked")
		await _interact_at(game, game.entrance.position)
		check(game.state == game.State.GROUNDS and game.ghost == null, "gate still checks equipment after the first encounter")
	await _pickup(game, "START_STAFF")
	check(game.player.has_sword and game.player.has_staff, "both starting weapons equip on pickup")
	await _interact_at(game, game.entrance.position)
	check(game.ghost == null, "entering with both weapons skips the ghost")
	var floor_count: int = game.floors.size()
	for number in range(1, floor_count + 1):
		var floor: FloorDefinition = game.floors[number - 1]
		check(game.floor_number == number and game.state == game.State.TRANSITION, "entry transition for floor %d" % number)
		check(game.ui.transition_tip.text == translation.get_message(floor.tip_key), "floor tip appears in " + locale)
		check(game.ui.transition_note.visible == not floor.entry_note_key.is_empty(), "entry note appears according to floor configuration")
		if not floor.entry_note_key.is_empty():
			check(game.ui.transition_note.text == translation.get_message(floor.entry_note_key), "fifth-floor lintel text is present")
		check(not game.ui.transition_hint.visible, "entry prompt is hidden during the minimum time")
		await _send_action("next")
		check(game.state == game.State.TRANSITION, "early confirmation cannot skip the 2.1 s minimum")
		game._process(game.transition_remaining)
		check(game.state == game.State.TRANSITION and game.ui.transition_hint.visible, "entry title finishes and the prompt waits for input")
		await _send_action("next")
		check(game.state == game.State.COMBAT, "confirmed transition enters combat")
		var floor_text := String(translation.get_message("UI_FLOOR")).format({"floor": number, "total": floor_count})
		check(game.ui.floor_label.text == floor_text, "HUD uses the configured floor count")
		for encounter in floor.waves:
			_spawn_wave(game)
			var enemies: Array = game.floor_manager.enemies
			check(enemies.size() == encounter.size(), "wave spawns the expected number of enemies")
			if enemies.size() > 1:
				check(enemies[1].spawn_delay > enemies[0].spawn_delay, "enemy arrival remains staggered")
			var spawned := PackedStringArray()
			var previous_kills: int = game.kills
			for enemy in enemies:
				spawned.append(enemy.kind)
				check(enemy.position.distance_to(game.player.position) >= 220.0, "enemy spawns away from the starting player")
				check(game.player.layout.is_walkable(enemy.position, enemy.hit_radius), "spawn is clear of obstacles")
			check(spawned == encounter, "wave keeps existing enemy composition and order")
			var has_target := encounter.has(floor.clear_on_enemy_defeat)
			_defeat_wave(game, floor.clear_on_enemy_defeat if has_target else "")
			var actual_kills := 1 if has_target else encounter.size()
			check(game.kills - previous_kills == actual_kills, "only actual defeats affect kills or spawn loot")
		check(game.state == game.State.SAFE and game.floor_manager.enemies.is_empty(), "every floor provides post-battle exploration")
		check(game.player.can_move and not game.player.can_attack, "clear phase supports exploration without attacking")
		for id in floor.clear_pickups.values():
			check(await _pickup(game, id), "floor grants guaranteed pickup " + id)
			if GameData.is_book(id):
				check(game.ui.top_overlay() == game.ui.lore and game.inventory.read.has(id), "new record opens and becomes read")
				check(game.ui.lore_title.text == translation.get_message(id + "_TITLE"), "record title appears in " + locale)
				check(game.ui.lore_body.text == translation.get_message(id + "_BODY"), "record body appears in " + locale)
				await _send_action("close")
				check(game.ui.top_overlay() == null and not paused, "Esc closes only the reading panel")
		await _send_action("next")
		if not floor.epilogue.is_empty():
			check(game.state == game.State.EPILOGUE and game.ui.lore.visible, "continuing on the final floor opens the epilogue")
			check(game.ui.lore_title.text == translation.get_message(floor.epilogue + "_TITLE"), "epilogue title appears in " + locale)
			check(game.ui.lore_body.text == translation.get_message(floor.epilogue + "_BODY"), "epilogue body appears in " + locale)
			var bindings := {"next": game.loc.binding("next"), "interact": game.loc.binding("interact"), "close": game.loc.binding("close")}
			var hint := String(translation.get_message("UI_EPILOGUE_RESULTS")).format(bindings)
			check(game.ui.lore_close.text == hint, "epilogue shows all three results keys")
			await _send_action("interact" if locale == "zh_CN" else "next")
			check(game.state == game.State.VICTORY and game.ui.result.visible, "closing the epilogue displays victory")
			break
		check(game.state == game.State.REWARD and game.current_choices.size() == 3, "three reward cards are shown")
		var selected: String = game.current_choices[0]
		var gear: Dictionary = game.inventory.equipped.duplicate()
		game.ui.reward.get_node("Card0").pressed.emit()
		check(game.inventory.owned.has(selected), "chosen equipment goes to the bag")
		check(game.inventory.equipped == gear, "choosing a reward leaves worn gear unchanged")
	check(cleared_floors == range(1, floor_count + 1) and game.kills > 0, "run completes all floors and retains defeat counts")
	check(not FileAccess.file_exists(temp_save) and not FileAccess.file_exists(temp_save + ".bak"), "victory invalidates the primary and backup")
	game.ui.result.get_node("Restart").pressed.emit()
	check(game.state == game.State.GROUNDS and game.kills == 0 and game.inventory.owned.is_empty() and game.player.hp == 100, "restart creates a fresh tower grounds run")
	game.queue_free()
	await process_frame

func _send_binding(event: InputEvent) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event

func _test_controls_pause_and_crafting() -> void:
	RunSave.new(temp_save).invalidate()
	var game := _new_game("en_US")
	var ui: CanvasLayer = game.ui
	ui.menu_settings.pressed.emit()
	var options: Control = ui.settings
	check(ui.top_overlay() == options, "main menu opens shared settings")
	options.action_buttons.interact.pressed.emit()
	await _send_binding(_key(KEY_W))
	check(options.hint_key == "UI_BIND_CONFLICT" and game.loc.binding("interact") == "E", "an occupied binding reports a conflict")
	await _send_binding(_key(KEY_ESCAPE))
	check(options.capturing.is_empty() and ui.top_overlay() == options, "Esc cancels binding before closing settings")
	options.action_buttons.interact.pressed.emit()
	await _send_binding(_key(KEY_J))
	check(game.loc.binding("interact") == "J", "keyboard remapping takes effect immediately")
	options.action_buttons.magic.pressed.emit()
	var middle := InputEventMouseButton.new()
	middle.button_index = MOUSE_BUTTON_MIDDLE
	await _send_binding(middle)
	check(InputMap.action_has_event("magic", middle), "mouse binding is editable")
	options.quality_low.pressed.emit()
	options.sliders.master.value = 0.5
	options.sliders.effects.value = 0.0
	check(not game.arena.high_quality and not game.grounds.high_quality, "low quality disables both environments' optional effects")
	check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "master slider updates the master bus")
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "zero effects level mutes the effects bus")
	options.language_zh.pressed.emit()
	check(ui.menu_settings.text == game.loc.translations.zh_CN.get_message("UI_SETTINGS"), "switching languages refreshes the menu under settings")
	await _send_binding(_key(KEY_ESCAPE))
	var persisted := ConfigFile.new()
	check(persisted.load(temp_settings) == OK and persisted.get_value("language", "locale") == "zh_CN", "settings retain the language section")
	check(persisted.get_value("audio", "master") == 0.5 and persisted.get_value("audio", "effects") == 0.0, "both volumes persist")
	check(persisted.get_value("video", "quality") == "low" and persisted.get_value("controls", "interact") == "key:74", "graphics quality and remapping persist")
	game.queue_free()
	await process_frame
	game = _new_game("zh_CN")
	ui = game.ui
	check(game.loc.binding("interact") == "J" and not game.loc.high_quality and game.loc.effects_volume == 0.0, "preferences restore on launch")
	game.ui.menu_start.pressed.emit()
	game.player.position = game.entrance.position
	await _send_binding(_key(KEY_E))
	check(game.ghost == null, "old interact binding has been removed")
	await _send_binding(_key(KEY_J))
	check(game.ghost != null and game.ghost.targets.size() == 2, "new binding works at the gate with both weapons missing")
	await _send_binding(_key(KEY_ESCAPE))
	check(paused and ui.top_overlay() == ui.pause, "Esc pauses the ghost sequence and opens pause")
	var ghost_time: float = game.ghost.elapsed
	var elapsed: float = game.elapsed
	await create_timer(0.1).timeout
	check(game.ghost.elapsed == ghost_time and game.elapsed == elapsed, "pause freezes the cutscene and elapsed run time")
	ui.pause.get_node("Settings").pressed.emit()
	check(ui.top_overlay() == ui.settings and paused, "pause and main menu use the same settings panel")
	ui.settings.reset.pressed.emit()
	ui.settings.quality_high.pressed.emit()
	ui.settings.sliders.master.value = 1.0
	ui.settings.sliders.effects.value = 1.0
	check(game.loc.binding("interact") == "E" and game.loc.binding("magic") == game.loc.text("UI_MOUSE_RIGHT"), "restoring defaults restores both input types")
	await _send_binding(_key(KEY_ESCAPE))
	check(ui.top_overlay() == ui.pause and paused, "Esc returns from settings to pause")
	await _send_binding(_key(KEY_ESCAPE))
	check(not paused, "Esc closes pause and resumes play")
	game._process(4.0)
	await _pickup(game, "MUSHROOM")
	await _pickup(game, "WATER")
	await _pickup(game, "LORE_KIT")
	check(ui.top_overlay() == ui.lore and ui.lore_body.scroll_active, "found book uses the scrollable reader")
	await _send_action("close")
	await _send_action("inventory")
	check(ui.top_overlay() == ui.bag and paused, "B opens and freezes the backpack context")
	ui.inventory_requested.emit("read", "LORE_KIT")
	check(ui.top_overlay() == ui.lore and ui.lore_id == "LORE_KIT", "a collected book can be reopened from the bag")
	await _send_action("close")
	check(ui.top_overlay() == ui.bag and paused, "closing a reread returns to the bag")
	ui.bag.craft.pressed.emit()
	check(ui.top_overlay() == ui.crafting and not ui.craft_button.disabled, "bag opens the recipe in a second panel")
	ui.craft_button.pressed.emit()
	check(game.inventory.count("MUSHROOM") == 0 and game.inventory.count("WATER") == 0 and game.inventory.count("POTION") == 1, "brewing deducts exactly one of each ingredient")
	check(not game.inventory.craft_potion() and ui.craft_button.disabled, "missing ingredients leave quantities unchanged")
	await _send_action("close")
	check(ui.top_overlay() == ui.bag, "Esc closes just the crafting panel")
	ui.inventory_requested.emit("quick", "POTION")
	await _send_action("close")
	await _send_action("quick_item")
	check(game.inventory.count("POTION") == 1 and ui.status_key == "UI_HP_FULL", "full health preserves the potion")
	game.player.hp = 42
	await _send_action("quick_item")
	check(game.player.hp == 72 and game.inventory.count("POTION") == 0, "Q consumes one bound potion and restores 30 HP")
	game.inventory.add("POTION")
	await _send_action("inventory")
	ui.inventory_requested.emit("drink", "POTION")
	check(game.player.hp == 100 and game.inventory.count("POTION") == 0, "backpack potion caps HP at the maximum")
	await _send_action("close")
	await _pickup(game, "START_SWORD")
	await _pickup(game, "START_STAFF")
	await _interact_at(game, game.entrance.position)
	await _send_action("inventory")
	var remaining: float = game.transition_remaining
	await create_timer(0.1).timeout
	check(game.transition_remaining == remaining, "bag freezes the floor title animation")
	await _send_action("close")
	await _ready_transition(game)
	_spawn_wave(game)
	game.player.aim = Vector2.LEFT
	game.player.cast_magic()
	var projectiles: Array = game.projectiles.get_children()
	check(not projectiles.is_empty(), "combat has an active projectile before pausing")
	await _send_action("close")
	var enemy: Node2D = game.floor_manager.enemies[0]
	var enemy_position := enemy.position
	var spawn_time: float = enemy.spawn_delay
	var projectile: Node2D = projectiles[0]
	var shot_position := projectile.position
	var shot_life: float = projectile.lifetime
	var cooldown: float = game.player.magic_timer
	var position: Vector2 = game.player.position
	elapsed = game.elapsed
	Input.action_press("move_right")
	await create_timer(0.12).timeout
	Input.action_release("move_right")
	check(game.player.position == position and game.player.magic_timer == cooldown and game.elapsed == elapsed, "pause freezes movement and timers")
	check(enemy.position == enemy_position and enemy.spawn_delay == spawn_time and projectile.position == shot_position and projectile.lifetime == shot_life, "pause freezes enemies and projectiles")
	check(ui.pause_rolls_back, "pause shows the current wave rollback note")
	await _send_action("close")
	await _send_action("inventory")
	check(ui.top_overlay() == ui.bag, "B opens the bag during combat")
	await _send_action("close")
	game.queue_free()
	await process_frame

func _restart_game(game: Node) -> Node:
	game.queue_free()
	await process_frame
	var reopened := _new_game("en_US")
	check(reopened.ui.menu_continue.visible, "new instance detects the saved run")
	reopened.ui.menu_continue.pressed.emit()
	return reopened

func _test_saving() -> void:
	var save := RunSave.new(temp_save)
	save.invalidate()
	var game := _new_game("en_US")
	game.ui.menu_start.pressed.emit()
	await _pickup(game, "START_SWORD")
	await _pickup(game, "LORE_ORDER")
	await _send_action("close")
	var outside_position: Vector2 = game.player.position
	await _send_action("close")
	game.ui.pause.get_node("SaveMenu").pressed.emit()
	check(game.state == game.State.MENU and game.ui.menu_continue.visible, "pause saves and returns to menu")
	var saved_seed: int = save.load_latest().data.seed
	game.ui.menu_start.pressed.emit()
	check(game.ui.top_overlay() == game.ui.overwrite, "replacing a valid save requires confirmation")
	await _send_action("close")
	check(save.load_latest().data.seed == saved_seed, "cancelling replacement preserves the save")
	game = await _restart_game(game)
	check(game.state == game.State.GROUNDS and game.inventory.owned.has("START_SWORD") and game.inventory.read.has("LORE_ORDER"), "grounds progress retains equipment and read records")
	check(game.player.position == outside_position and game.inventory.equipped.sword == "START_SWORD", "grounds snapshot restores position and equipped starter")
	await _interact_at(game, game.entrance.position)
	check(game.ghost != null, "ghost can be triggered before the run is suspended")
	game._save_run()
	game = await _restart_game(game)
	check(game.ghost == null and not game.ghost_seen and game.player.position == game.entrance.position, "closing during the ghost returns to the gate")
	await _send_action("interact")
	check(game.ghost != null and game.ghost.targets.size() == 1, "unfinished ghost can be triggered again")
	game._process(4.0)
	await _pickup(game, "START_STAFF")
	await _pickup(game, "MUSHROOM")
	await _pickup(game, "WATER")
	await _interact_at(game, game.entrance.position)
	game._process(0.8)
	var transition_time: float = game.transition_remaining
	game._save_run()
	var layout_before: Array = game.arena.layout.obstacles.duplicate(true)
	game = await _restart_game(game)
	check(game.state == game.State.TRANSITION and is_equal_approx(game.transition_remaining, transition_time), "floor transition resumes with its remaining time")
	check(game.arena.layout.obstacles == layout_before, "restored layout keeps the exact saved cover")
	await _ready_transition(game)
	_spawn_wave(game)
	var drops: Array = game.floor_manager.enemies.map(func(enemy): return enemy.drop_id)
	var snapshot: Dictionary = save.load_latest().data
	game.inventory.add("U06")
	game.inventory.equip("U06")
	game.player.set_equipment(game.inventory.equipped)
	game.inventory.craft_potion()
	game.player.take_damage(62)
	game.inventory.drink(game.player)
	game.floor_manager.enemies[0].take_damage(999)
	game.player.magic_timer = 2.25
	game.player.position = Vector2(320, 300)
	check(game.kills == 1 and game.player.hp == 68 and "U06" in game.inventory.owned, "wave changed statistics, health, and gear before suspension")
	game._save_run()
	check(save.load_latest().data == snapshot, "mid-wave saving writes the original checkpoint")
	game = await _restart_game(game)
	check(game.state == game.State.COMBAT and game.kills == 0 and game.player.hp == 100, "resume rolls back this wave's damage and kills")
	check(game.inventory.snapshot() == snapshot.inventory and game.player.position == snapshot.player.position, "resume rolls back gear, crafting, positions and potion use")
	check(is_equal_approx(game.player.magic_timer, snapshot.player.magic_timer) and game.pickups.get_child_count() == snapshot.ground.size(), "resume restores cooldown and ground items")
	game.floor_manager._process(0.1)
	check(game.floor_manager.enemies.map(func(enemy): return enemy.drop_id) == drops, "same wave resumes with the same preassigned drops")
	_defeat_wave(game)
	check(game.state == game.State.COMBAT and game.floor_manager.wait_for_wave > 0.0, "completed first wave leads to the next wave")
	var earned: int = game.kills
	if game.pickups.get_child_count() > 0:
		await _interact_at(game, game.pickups.get_child(0).position)
	var preserved: Dictionary = game.inventory.snapshot()
	var between_ground: Array = game._snapshot().ground
	game._save_run()
	game = await _restart_game(game)
	check(game.floor_manager.wave_index == 0 and game.floor_manager.enemies.is_empty() and game.kills == earned, "between-wave resume keeps completed wave and prepares second")
	check(game.inventory.snapshot() == preserved and game._snapshot().ground == between_ground, "between-wave resume preserves pickups and remaining drops")
	_spawn_wave(game)
	_defeat_wave(game)
	var earned_at_clear: int = game.kills
	await _pickup(game, "LORE_F1")
	await _send_action("close")
	game._save_run()
	var explored: Dictionary = game._snapshot()
	game = await _restart_game(game)
	check(game.state == game.State.SAFE and game.kills == earned_at_clear and game.inventory.read.has("LORE_F1"), "clear exploration resumes with the read book")
	check(game.inventory.snapshot() == explored.inventory and game._snapshot().ground == explored.ground, "clear exploration restores bag and ground")
	await _send_action("next")
	var choices: Array[String] = game.current_choices.duplicate()
	game = await _restart_game(game)
	check(game.state == game.State.REWARD and game.current_choices == choices, "reward resume keeps all three cards and their order")
	check(game.arena.layout.obstacles == layout_before, "reward resume keeps the floor layout")
	var temp_dir := temp_save + ".tmp"
	DirAccess.make_dir_absolute(temp_dir)
	var before_error: Dictionary = save.load_latest().data
	await _send_action("close")
	game.ui.pause.get_node("SaveMenu").pressed.emit()
	check(game.state == game.State.REWARD and game.ui.status_key == "UI_SAVE_WRITE_ERROR", "write failure stays in the game and shows a localized error")
	check(save.load_latest().data == before_error, "failed write leaves the current save intact")
	DirAccess.remove_absolute(temp_dir)
	await _send_action("close")
	game.ui.reward.get_node("Card0").pressed.emit()
	await _ready_transition(game)
	_spawn_wave(game)
	game.player.take_damage(999)
	check(game.state == game.State.GAME_OVER and not FileAccess.file_exists(temp_save) and not FileAccess.file_exists(temp_save + ".bak"), "death invalidates the active save and backup")
	game.show_menu()
	check(not game.ui.menu_continue.visible, "death removes the continue entry")
	game.start_run()
	game._save_run()
	var corrupt := FileAccess.open(temp_save, FileAccess.WRITE)
	corrupt.store_string("bad save")
	corrupt.close()
	game.show_menu()
	check(game.ui.status_key == "UI_SAVE_RECOVERED" and game.ui.menu_continue.visible, "damaged primary offers a verified backup with a notice")
	DirAccess.remove_absolute(temp_save + ".bak")
	game.show_menu()
	check(game.ui.status_key == "UI_SAVE_INVALID" and not game.ui.menu_continue.visible, "unrecoverable damage warns and disables Continue")
	game.queue_free()
	await process_frame
