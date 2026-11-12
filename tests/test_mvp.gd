extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/enemies/slime.tscn")
const GoblinScene = preload("res://scenes/enemies/goblin.tscn")
const EliteScene = preload("res://scenes/enemies/elite.tscn")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const Localization = preload("res://scripts/localization_service.gd")
const GameData = preload("res://data/game_data.gd")
const RewardManager = preload("res://scripts/reward_manager.gd")
var failures: Array[String] = []
var checks := 0
var clears := 0

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	await _test_localization()
	await _test_combat_and_upgrades()
	await _test_full_run()
	if failures.is_empty():
		print("PASS: %d checks (localization, combat, upgrades, five-floor flow, restart)" % checks)
		quit(0)
	else:
		printerr("FAILED: %d of %d checks" % [failures.size(), checks])
		quit(1)

func _test_localization() -> void:
	var temp_dir := OS.get_environment("TMPDIR")
	if temp_dir.is_empty():
		temp_dir = OS.get_environment("TEMP")
	if temp_dir.is_empty():
		temp_dir = OS.get_user_data_dir()
	var temp_settings := temp_dir.path_join("tower-test-%s.cfg" % Time.get_ticks_usec())
	var first = Localization.new()
	first.settings_path = temp_settings
	root.add_child(first)
	check(first.text("UI_MENU_START") != "UI_MENU_START", "localized menu text resolves")
	var source := FileAccess.open("res://localization/game.csv", FileAccess.READ)
	check(source != null, "translation source exists")
	if source:
		var header := source.get_csv_line()
		check(header == PackedStringArray(["keys", "zh_CN", "en_US"]), "translation source has expected locales")
		var keys := {}
		var placeholders := RegEx.new()
		placeholders.compile("\\{[^}]+\\}")
		while not source.eof_reached():
			var row := source.get_csv_line()
			if row.size() < 3:
				continue
			check(not keys.has(row[0]), "translation ID is unique: " + row[0])
			keys[row[0]] = true
			check(not row[1].is_empty() and not row[2].is_empty(), "both translations exist: " + row[0])
			var zh_vars: Array[String] = []
			var en_vars: Array[String] = []
			for found in placeholders.search_all(row[1]):
				zh_vars.append(found.get_string())
			for found in placeholders.search_all(row[2]):
				en_vars.append(found.get_string())
			zh_vars.sort()
			en_vars.sort()
			check(zh_vars == en_vars, "matching placeholders: " + row[0])
	first.set_language("en_US")
	check(first.text("UI_MENU_START") == "START GAME", "English selection takes effect")
	var second = Localization.new()
	second.settings_path = temp_settings
	root.add_child(second)
	check(second.locale == "en_US", "language selection persists")
	second.set_language("zh_CN")
	check(second.text("UI_MENU_START") == "开始游戏", "Chinese selection takes effect")
	for item in GameData.UPGRADES:
		for code in ["zh_CN", "en_US"]:
			var translation: Translation = second.translations[code]
			for suffix in ["NAME", "EFFECT", "LORE"]:
				var key: String = "ITEM_%s_%s" % [item.id, suffix]
				check(not str(translation.get_message(key)).is_empty(), "%s exists in %s" % [key, code])
	first.queue_free()
	second.queue_free()
	DirAccess.remove_absolute(temp_settings)
	await process_frame

func _test_combat_and_upgrades() -> void:
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
	check(is_equal_approx(a.hp, 10.0) and is_equal_approx(b.hp, 10.0), "one sword swing damages each enemy once and can hit multiple")
	player.hp = 80
	player.apply_upgrade(GameData.upgrade("U06"))
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
	check(is_equal_approx(c.hp, 2.0) and projectile.consumed, "friendly projectile hits once and is consumed")
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
	check(shots.count == 3, "elite fires three projectiles")
	var stats = PlayerScene.instantiate()
	arena.add_child(stats)
	stats.apply_upgrade(GameData.upgrade("U01"))
	stats.apply_upgrade(GameData.upgrade("U01"))
	stats.apply_upgrade(GameData.upgrade("U03"))
	stats.apply_upgrade(GameData.upgrade("U07"))
	stats.apply_upgrade(GameData.upgrade("U08"))
	check(is_equal_approx(stats.sword_damage, 24.0) and is_equal_approx(stats.magic_damage, 32.0), "damage upgrades stack")
	check(is_equal_approx(stats.max_hp, 125.0) and is_equal_approx(stats.hp, 125.0), "armor increases maximum and heals")
	check(is_equal_approx(stats.speed, 212.75), "boots increase movement speed")
	for i in range(10):
		stats.apply_upgrade(GameData.upgrade("U02"))
		stats.apply_upgrade(GameData.upgrade("U04"))
		stats.apply_upgrade(GameData.upgrade("U05"))
	check(is_equal_approx(stats.sword_cooldown, 0.22), "sword cooldown respects minimum")
	check(is_equal_approx(stats.magic_cooldown, 1.0), "magic cooldown respects minimum")
	check(is_equal_approx(stats.crit_chance, 0.6), "critical chance respects maximum")
	stats.heal(999)
	check(is_equal_approx(stats.hp, stats.max_hp), "healing respects maximum health")
	for i in range(50):
		var choices: Array = RewardManager.generate_choices(3)
		var ids: Array = choices.map(func(item): return item.id)
		check(choices.size() == 3 and ids[0] != ids[1] and ids[1] != ids[2] and ids[0] != ids[2], "reward options are distinct")
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

func _test_full_run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	game.floor_manager.floor_cleared.connect(func(): clears += 1)
	check(game.state == game.State.MENU, "game starts in menu")
	game.start_run()
	for floor_number in range(1, 6):
		check(game.floor_number == floor_number and game.state == game.State.TRANSITION, "floor transition %d" % floor_number)
		game._begin_combat()
		check(game.state == game.State.COMBAT, "floor %d enters combat" % floor_number)
		var waves: Array = GameData.FLOORS[floor_number - 1]
		for wave_index in range(waves.size()):
			game.floor_manager.wait_for_wave = -1.0
			game.floor_manager._spawn_wave()
			check(game.floor_manager.enemies.size() == waves[wave_index].size(), "floor %d wave %d spawns" % [floor_number, wave_index + 1])
			for enemy in game.floor_manager.enemies.duplicate():
				check(enemy.global_position.distance_to(game.player.global_position) >= 220.0, "enemy spawns away from player")
				check(enemy.spawn_delay > 0.0, "enemy has spawn protection")
			for enemy in game.floor_manager.enemies.duplicate():
				if is_instance_valid(enemy) and enemy.alive:
					enemy.take_damage(9999.0)
			if wave_index + 1 < waves.size():
				check(game.state == game.State.COMBAT and not game.floor_manager.cleared, "no reward between waves")
		if floor_number == 5:
			check(game.state == game.State.VICTORY, "elite death triggers victory")
			break
		if floor_number in [1, 3]:
			check(game.state == game.State.SAFE, "floor %d offers safe reading" % floor_number)
			game.player.position = GameData.LORE[floor_number].position
			await _send_action("interact")
			check(game.lore_open and not game.player.can_move, "record opens and blocks movement")
			await _send_action("next")
			check(game.state == game.State.SAFE and game.lore_open, "open record blocks reward input")
			await _send_action("close")
			check(not game.lore_open and game.player.can_move, "escape closes the record")
			await _send_action("interact")
			check(game.lore_open, "record can be reread")
			await _send_action("interact")
			check(not game.lore_open, "interaction closes the record")
			await _send_action("next")
		check(game.state == game.State.REWARD, "floor %d enters reward" % floor_number)
		check(game.current_choices.size() == 3, "three reward cards shown")
		if game.current_choices.is_empty():
			game.queue_free()
			await process_frame
			return
		var item: Dictionary = game.current_choices[0]
		game._on_upgrade_selected(item)
		check(game.player.upgrades.size() == floor_number, "exactly one upgrade applied per floor")
	check(clears == 5, "floor cleared emits exactly once per floor")
	check(game.kills > 0 and game.player.upgrades.size() == 4, "victory retains run statistics")
	game.start_run()
	check(game.floor_number == 1 and game.kills == 0 and game.player.upgrades.is_empty() and game.player.hp == 100, "restart resets run")
	game._begin_combat()
	game.player.take_damage(999)
	check(game.state == game.State.GAME_OVER, "player death produces defeat")
	game.start_run()
	check(game.state == game.State.TRANSITION and game.player.alive, "restart after defeat creates a live player")
	game.queue_free()
	await process_frame
