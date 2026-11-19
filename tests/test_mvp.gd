extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const PlayerScene = preload("res://scenes/player/player.tscn")
const SlimeScene = preload("res://scenes/enemies/slime.tscn")
const GoblinScene = preload("res://scenes/enemies/goblin.tscn")
const ArcherScene = preload("res://scenes/enemies/archer.tscn")
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
	temp_settings = temp_dir.path_join("tower-test-%s.cfg" % Time.get_ticks_usec())
	await _test_localization()
	_test_floor_resources()
	await _test_combat_and_upgrades()
	if failures.is_empty():
		for locale in LOCALES:
			await _test_full_run(locale)
		# The same entry, combat, and epilogue rules must work in a different slot.
		await _test_full_run("en_US", true)
	DirAccess.remove_absolute(temp_settings)
	if failures.is_empty():
		print("PASS: %d checks (localization, combat, upgrades, five-floor flow, restart)" % checks)
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
		check(floor.after_clear in FloorDefinition.AfterClear.values(), level + " has a valid clear sequence")
		check((floor.after_clear == FloorDefinition.AfterClear.EPILOGUE) == (index == game.floors.size() - 1), level + " ends the run only in the last slot")
		_check_text_request(floor.tip_key, {})
		if not floor.entry_note_key.is_empty():
			_check_text_request(floor.entry_note_key, {})
		if floor.after_clear != FloorDefinition.AfterClear.REWARD:
			_check_text_request(floor.record_title_key, {})
			_check_text_request(floor.record_body_key, {})
		check(not floor.waves.is_empty(), level + " has combat waves")
		var enemy_types := []
		for wave in floor.waves:
			check(not wave.is_empty(), level + " has no empty waves")
			for enemy in wave:
				check(GameData.ENEMIES.has(enemy) and manager.SCENES.has(enemy), level + " can spawn " + enemy)
			enemy_types.append_array(wave)
		check(floor.clear_on_enemy_defeat.is_empty() or enemy_types.has(floor.clear_on_enemy_defeat), level + " spawns its configured clear target")
	game.free()

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
	check(is_equal_approx(a.hp, 14.0) and is_equal_approx(b.hp, 14.0), "one sword swing damages each enemy once and can hit multiple")
	player.hp = 80
	player.apply_upgrade(GameData.upgrade("U06"))
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

func _test_full_run(locale: String, epilogue_only := false) -> void:
	var game = MainScene.instantiate()
	if epilogue_only:
		game.floors.assign([game.floors.back()])
	var service = game.get_node("Localization")
	service.set_script(AuditedLocalization)
	service.settings_path = temp_settings
	service.text_requested.connect(_check_text_request)
	root.add_child(game)
	var cleared_floors: Array[int] = []
	game.floor_manager.floor_cleared.connect(func(): cleared_floors.append(game.floor_number))
	check(game.state == game.State.MENU, "game starts in menu")
	var language_button: Button = game.ui.language_zh if locale == "zh_CN" else game.ui.language_en
	language_button.pressed.emit()
	var translation: Translation = service.translations[locale]
	check(game.ui.menu_start.text == translation.get_message("UI_MENU_START"), "menu refreshes in " + locale)
	for item in GameData.UPGRADES:
		game.ui.show_reward([item])
	game.ui.show_menu()
	game.ui.menu_start.pressed.emit()
	var floor_count: int = game.floors.size()
	for floor_number in range(1, floor_count + 1):
		var floor: FloorDefinition = game.floors[floor_number - 1]
		check(game.floor_number == floor_number and game.state == game.State.TRANSITION, "floor transition %d" % floor_number)
		check(game.ui.transition_tip.text == translation.get_message(floor.tip_key), "floor tip appears in " + locale)
		check(game.wait_for_input == floor.wait_for_confirmation, "transition uses the configured confirmation rule")
		if floor.wait_for_confirmation:
			check(game.ui.transition_note.visible and game.ui.transition_note.text == translation.get_message(floor.entry_note_key), "entry note appears in " + locale)
			check(game.ui.transition_hint.visible, "confirmation prompt is shown")
			await _send_action("next")
			check(game.state == game.State.TRANSITION, "entry note has a minimum reading time")
			game._process(game.transition_remaining)
			check(game.state == game.State.TRANSITION, "entry note still waits when the timer expires")
			await _send_action("next")
		else:
			game._process(game.transition_remaining)
		check(not game.wait_for_input, "entering combat clears the transition wait")
		check(game.state == game.State.COMBAT, "floor %d enters combat" % floor_number)
		if floor_number == 1:
			game.player.cast_magic()
			game._process(0.0)
			var floor_text := String(translation.get_message("UI_FLOOR")).format({"floor": floor_number, "total": floor_count})
			check(game.ui.floor_label.text == floor_text, "HUD uses the run's configured floor count")
		for wave_index in range(floor.waves.size()):
			var wave := floor.waves[wave_index]
			game.floor_manager.wait_for_wave = -1.0
			game.floor_manager._spawn_wave()
			check(game.floor_manager.enemies.size() == wave.size(), "floor %d wave %d spawns" % [floor_number, wave_index + 1])
			if game.floor_manager.enemies.size() > 1:
				check(game.floor_manager.enemies[1].spawn_delay > game.floor_manager.enemies[0].spawn_delay, "wave spawns are staggered")
			var has_target := wave.has(floor.clear_on_enemy_defeat)
			var spawned_kinds := PackedStringArray()
			for enemy in game.floor_manager.enemies.duplicate():
				spawned_kinds.append(enemy.kind)
				check(enemy.global_position.distance_to(game.player.global_position) >= 220.0, "enemy spawns away from player")
				check(enemy.spawn_delay > 0.0, "enemy has spawn protection")
			check(spawned_kinds == wave, "wave uses configured enemy types in order")
			for enemy in game.floor_manager.enemies.duplicate():
				if enemy.alive and (not has_target or enemy.kind == floor.clear_on_enemy_defeat):
					enemy.take_damage(9999.0)
			if has_target:
				check(game.floor_manager.cleared and game.floor_manager.enemies.is_empty(), "defeating the clear target despawns surviving enemies")
				break
			if wave_index + 1 < floor.waves.size():
				check(game.state == game.State.COMBAT and not game.floor_manager.cleared, "no reward between waves")
		if floor.after_clear == FloorDefinition.AfterClear.EPILOGUE:
			check(game.state == game.State.SAFE and game.lore_open, "defeating the keeper opens the closing record")
			check(not game.player.can_move and not game.player.can_attack, "the closing record locks movement and attacks")
			check(game.ui.lore_title.text == translation.get_message(floor.record_title_key), "epilogue title appears in " + locale)
			check(game.ui.lore_body.text == translation.get_message(floor.record_body_key), "epilogue body appears in " + locale)
			await _send_action("interact" if locale == "zh_CN" else "next")
			check(game.state == game.State.VICTORY, "closing the final record ends the run in victory")
			check(game.ui.result.visible, "victory screen is visible")
			break
		if floor.after_clear == FloorDefinition.AfterClear.OPTIONAL_RECORD:
			check(game.state == game.State.SAFE and game.arena.lore_position == floor.record_position, "optional record appears at its configured location")
			if floor_number != 2 or locale == "zh_CN":
				await _test_optional_record(game, floor, translation)
			await _send_action("next")
		check(game.state == game.State.REWARD, "floor %d enters reward" % floor_number)
		check(game.current_choices.size() == 3, "three reward cards shown")
		if game.current_choices.is_empty():
			game.queue_free()
			await process_frame
			return
		game.ui.reward.get_node("Card0").pressed.emit()
		check(game.player.upgrades.size() == floor_number, "exactly one upgrade applied per floor")
	check(cleared_floors == range(1, floor_count + 1), "floor cleared emits exactly once per floor")
	check(game.kills > 0 and game.player.upgrades.size() == floor_count - 1, "victory retains run statistics")
	game.ui.result.get_node("Restart").pressed.emit()
	check(game.floor_number == 1 and game.kills == 0 and game.player.upgrades.is_empty() and game.player.hp == 100, "restart resets run")
	game._begin_combat()
	game.player.take_damage(999)
	check(game.state == game.State.GAME_OVER, "player death produces defeat")
	game.start_run()
	check(game.state == game.State.TRANSITION and game.player.alive, "restart after defeat creates a live player")
	game.queue_free()
	await process_frame

func _test_optional_record(game: Node, floor: FloorDefinition, translation: Translation) -> void:
	game.player.position = floor.record_position
	await _send_action("interact")
	check(game.lore_open and not game.player.can_move, "record opens and blocks movement")
	check(game.ui.lore_title.text == translation.get_message(floor.record_title_key), "optional record title appears in " + translation.locale)
	check(game.ui.lore_body.text == translation.get_message(floor.record_body_key), "optional record body appears in " + translation.locale)
	await _send_action("next")
	check(game.state == game.State.SAFE and game.lore_open, "open record blocks reward input")
	await _send_action("close")
	check(not game.lore_open and game.player.can_move, "escape closes the record")
	await _send_action("interact")
	check(game.lore_open, "record can be reread")
	await _send_action("interact")
	check(not game.lore_open, "interaction closes the record")
