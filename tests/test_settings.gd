extends SceneTree

const MainScene = preload("res://scenes/main.tscn")
const Controller = preload("res://scripts/run_controller.gd")

var checks := 0
var failures := 0
var profile_path := ""

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var temp_dir := OS.get_environment("TMPDIR")
	if temp_dir.is_empty():
		temp_dir = OS.get_environment("TEMP")
	if temp_dir.is_empty():
		temp_dir = OS.get_user_data_dir()
	profile_path = temp_dir.path_join("tower-settings-test-%s" % Time.get_ticks_usec())
	var game := _new_game()
	await _change_settings(game)
	game.queue_free()
	await process_frame
	game = _new_game()
	await _verify_gameplay_and_reset(game)
	game.queue_free()
	await process_frame
	RunSave.new(profile_path + ".save").invalidate()
	for extension in [".cfg", ".codex", ".codex.tmp"]:
		var file: String = profile_path + extension
		if FileAccess.file_exists(file):
			DirAccess.remove_absolute(file)
	await create_timer(0.15, true, false, true).timeout
	print("Settings and controls: %d/%d checks passed" % [checks - failures, checks])
	quit(1 if failures > 0 else 0)

func _new_game() -> Node2D:
	var game := MainScene.instantiate()
	game.save_path = profile_path + ".save"
	game.codex_path = profile_path + ".codex"
	game.get_node("Localization").settings_path = profile_path + ".cfg"
	root.add_child(game)
	return game

func _change_settings(game: Node2D) -> void:
	var ui: CanvasLayer = game.ui
	ui.menu_settings.pressed.emit()
	var options: Control = ui.settings
	_check(ui.top_overlay() == options, "Main menu opens settings")
	options.language_en.pressed.emit()
	_check(ui.menu_settings.text == game.loc.translations.en_US.get_message("UI_SETTINGS"), "English refreshes the background menu")
	options.language_zh.pressed.emit()
	_check(ui.menu_settings.text == game.loc.translations.zh_CN.get_message("UI_SETTINGS"), "Chinese refreshes the background menu")

	options.action_buttons.interact.pressed.emit()
	await _send_input(_key(KEY_W))
	_check(options.hint_key == "UI_BIND_CONFLICT" and game.loc.binding("interact") == "E", "A key in use shows a binding conflict")
	await _send_input(_key(KEY_ESCAPE))
	_check(options.capturing.is_empty() and ui.top_overlay() == options, "Escape cancels a binding capture before closing settings")
	options.action_buttons.interact.pressed.emit()
	await _send_input(_key(KEY_J))
	_check(game.loc.binding("interact") == "J", "Keyboard binding updates immediately")
	options.action_buttons.attack.pressed.emit()
	await _send_input(_mouse(MOUSE_BUTTON_MIDDLE))
	_check(InputMap.action_has_event("attack", _mouse(MOUSE_BUTTON_MIDDLE)), "Attack accepts the middle mouse button")

	options.quality_low.pressed.emit()
	options.sliders.master.value = 0.5
	options.sliders.effects.value = 0.0
	options.sliders.music.value = 0.35
	_check(not game.arena.high_quality and not game.grounds.high_quality, "Low quality updates both environments")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(0), linear_to_db(0.5)), "Master slider updates the master bus")
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Effects")), "Zero effects volume mutes the effects bus")
	_check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.35)), "Music volume updates the music bus independently")
	await _send_input(_key(KEY_ESCAPE))
	_check(ui.top_overlay() == null, "Closing settings returns to the menu")
	var saved := ConfigFile.new()
	_check(saved.load(profile_path + ".cfg") == OK, "Settings write to the isolated profile")
	_check(saved.get_value("language", "locale", "") == "zh_CN", "Language persists")
	_check(saved.get_value("controls", "attack", "") == "mouse:3" and saved.get_value("controls", "interact", "") == "key:74", "Both remap types persist")
	_check(saved.get_value("video", "quality", "") == "low", "Quality persists")
	_check(is_equal_approx(float(saved.get_value("audio", "master", -1.0)), 0.5)
		and is_zero_approx(float(saved.get_value("audio", "effects", -1.0)))
		and is_equal_approx(float(saved.get_value("audio", "music", -1.0)), 0.35), "All three volumes persist")

func _verify_gameplay_and_reset(game: Node2D) -> void:
	var ui: CanvasLayer = game.ui
	_check(game.loc.locale == "zh_CN" and not game.loc.high_quality and game.loc.effects_volume == 0.0, "Launch restores language, graphics and volume")
	_check(game.loc.binding("interact") == "J" and InputMap.action_has_event("attack", _mouse(MOUSE_BUTTON_MIDDLE)), "Launch restores keyboard and mouse remaps")
	ui.menu_start.pressed.emit()
	game._process(3.0)
	_check(game.state == Controller.State.GROUNDS, "Start transitions to tower grounds")
	if game.state != Controller.State.GROUNDS:
		return
	game.player.position = game.entrance.position
	await process_frame
	await process_frame
	_check(game.ghost == null and game.ui.near_label.text.contains("J"), "Approaching the gate suggests the remapped interaction")
	await _send_input(_key(KEY_J))
	_check(game.ghost != null and game.ghost.targets.size() == 2, "The introduction begins on the remapped interaction")
	if game.ghost == null:
		return
	_check(absf(game.ghost.position.x - game.player.position.x) >= 68.0,
		"The knight leaves room to read the player's reaction")
	await _send_input(_key(KEY_ESCAPE))
	_check(paused and ui.top_overlay() == ui.pause, "Pause opens while the introduction plays")
	var elapsed: float = game.elapsed
	var ghost_time: float = game.ghost.elapsed
	await create_timer(0.05).timeout
	_check(game.elapsed == elapsed and game.ghost.elapsed == ghost_time, "Pause freezes run time and the introduction")
	ui.pause.get_node("Settings").pressed.emit()
	_check(paused and ui.top_overlay() == ui.settings, "Pause reuses settings without resuming gameplay")
	await _send_input(_key(KEY_ESCAPE))
	_check(paused and ui.top_overlay() == ui.pause, "Escape returns from settings to pause")
	ui.pause.get_node("SaveMenu").pressed.emit()
	_check(game.state == Controller.State.MENU and ui.menu_continue.visible, "Saving during the introduction offers a continue")
	ui.menu_continue.pressed.emit()
	_check(game.state == Controller.State.GROUNDS and game.ghost != null and is_equal_approx(game.ghost.elapsed, ghost_time),
		"Continuing the saved introduction restores its progress")
	await _send_input(_key(KEY_ESCAPE))
	_check(paused and ui.top_overlay() == ui.pause, "Pause works after loading the introduction")
	await _send_input(_key(KEY_ESCAPE))
	_check(not paused and ui.top_overlay() == null, "Escape resumes gameplay")
	game._process(Controller.Ghost.DURATION + 0.02)
	for pickup in game.pickups.get_children():
		if pickup.item_id == "START_SWORD":
			var interaction_range := Controller.PICKUP_DISTANCE * 0.70
			game.player.position = pickup.position + Vector2.DOWN * interaction_range
			break
	await _send_input(_key(KEY_E))
	_check(not game.inventory.has_weapon(), "Old interact key has no effect")
	await _send_input(_key(KEY_J))
	_check(game.inventory.current_weapon() == "START_SWORD", "Remapped interact picks up and equips the sword")
	await _send_input(_mouse(MOUSE_BUTTON_LEFT))
	_check(game.player.weapon_timers.is_empty(), "Old mouse button cannot attack")
	await _send_input(_mouse(MOUSE_BUTTON_MIDDLE))
	_check(game.player.attack_ready_in() > 0.0, "Remapped attack performs the equipped weapon's attack")
	_verify_book(game)

	await _send_input(_key(KEY_ESCAPE))
	ui.pause.get_node("Settings").pressed.emit()
	ui.settings.reset.pressed.emit()
	_check(game.loc.binding("interact") == "E" and InputMap.action_has_event("attack", _mouse(MOUSE_BUTTON_LEFT)), "Reset restores both default input types")
	await _send_input(_key(KEY_ESCAPE))
	await _send_input(_key(KEY_ESCAPE))

func _verify_book(game: Node2D) -> void:
	var ui: CanvasLayer = game.ui
	game.inventory.add("U06")
	ui.show_inventory(game.inventory, game.player, game.codex)
	var book: Control = ui.bag
	book.selected = "U06"
	book.refresh()
	var life_row := book.comparison.get_child(18) as Label
	var life_delta := book.comparison.get_child(20) as Label
	_check(book.comparison.visible and life_row.text == game.loc.text("UI_STAT_LIFESTEAL") and life_delta.text == "+5 HP",
		"The equipment comparison shows sword-kill healing in HP")
	book.action.pressed.emit()
	_check(game.player.weapon == "U06" and game.player.stats.lifesteal == 5.0,
		"Applying the preview feeds the same kill-healing value into combat")
	book.tab_buttons[book.Page.CRAFT].pressed.emit()
	_check(book.recipe_materials.visible and book.recipe_materials.get_child_count() == 3 and book.action.disabled,
		"Crafting separates its ingredients and disables the action when they are missing")
	ui.pop_overlay()

func _send_input(event: InputEvent) -> void:
	event.pressed = true
	Input.parse_input_event(event)
	await physics_frame
	await process_frame
	var release := event.duplicate()
	release.pressed = false
	Input.parse_input_event(release)
	await process_frame

func _key(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = code
	return event

func _mouse(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	return event

func _check(condition: bool, detail: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + detail)
