extends CanvasLayer

signal start_pressed
signal continue_pressed
signal overwrite_pressed
signal quit_pressed
signal menu_pressed
signal save_menu_pressed
signal close_requested
signal overlay_changed
signal sound_preview_requested
signal reward_selected(id: String)
signal inventory_requested(operation: String, id: String)

const GameData = preload("res://data/game_data.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const InventoryPanel = preload("res://scripts/inventory_panel.gd")
const RevealScene = preload("res://scenes/world/floor_reveal.tscn")
const INK := Color("e8e1d3")
const MUTED := Color("a8a99f")
const GOLD := Color("e9be73")
const CYAN := Color("92c9d9")

var loc: Node
var root: Control
var hud: Control
var menu: Control
var transition: Control
var reward: Control
var lore: Control
var result: Control
var pause: Control
var overwrite: Control
var settings: Control
var bag: Control
var crafting: Control
var overlays: Array[Control] = []
var _static_text: Array = []

var health_label: Label
var health_fill: ColorRect
var floor_label: Label
var enemies_label: Label
var wave_label: Label
var magic_label: Label
var magic_value: Label
var inventory_label: Label
var quick_label: Label
var safe_label: Label
var near_label: Label
var status_label: Label
var status_panel: Panel
var status_key := ""
var status_values: Dictionary = {}
var status_remaining := 0.0

var menu_start: Button
var menu_continue: Button
var menu_controls: Label
var menu_settings: Button
var menu_quit: Button
var resume_available := false
var pause_hint: Label
var pause_rolls_back := false
var lore_title: Label
var lore_body: RichTextLabel
var lore_close: Label
var lore_done: Button
var lore_id := ""
var reading_epilogue := false
var transition_floor: Label
var transition_tip: Label
var transition_note: Label
var transition_hint: Label
var transition_reveal: Node2D
var transition_label_data: Dictionary = {}
var displayed_choices: Array[String] = []
var recipe: Label
var recipe_stock: Label
var craft_button: Button

func setup(service: Node) -> void:
	loc = service
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_theme()
	_build_ui()
	loc.language_changed.connect(_refresh_text)
	loc.bindings_changed.connect(_refresh_text)
	loc.preferences_changed.connect(settings.refresh)
	_refresh_text()
	show_menu(false)

func _build_theme() -> void:
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/NotoSansSC-Regular.ttf")
	theme.default_font_size = 17
	var view := Control.new()
	view.name = "Interface"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.theme = theme
	add_child(view)
	root = view

func _build_ui() -> void:
	hud = _layer("HUD")
	health_label = _label(hud, Vector2(112, 22), Vector2(340, 26), 16, INK)
	_color(hud, Rect2(112, 52, 250, 10), Color("252c31"))
	health_fill = _color(hud, Rect2(112, 52, 250, 10), Color("d97364"))
	floor_label = _label(hud, Vector2(810, 20), Vector2(358, 27), 18, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	enemies_label = _label(hud, Vector2(840, 51), Vector2(176, 22), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	wave_label = _label(hud, Vector2(1018, 51), Vector2(150, 22), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	magic_label = _label(hud, Vector2(112, 630), Vector2(260, 23), 14, CYAN)
	magic_value = _label(hud, Vector2(112, 654), Vector2(220, 25), 18, INK)
	inventory_label = _label(hud, Vector2(840, 629), Vector2(328, 25), 15, GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	quick_label = _label(hud, Vector2(810, 655), Vector2(358, 24), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	safe_label = _label(hud, Vector2(389, 651), Vector2(502, 33), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	near_label = _label(hud, Vector2(415, 616), Vector2(450, 33), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)

	menu = _layer("Menu")
	_dimmer(menu, 0.76)
	_panel(menu, Rect2(343, 62, 594, 596), Color("202831"), Color("8c7554"))
	_localize(_label(menu, Vector2(367, 106), Vector2(546, 76), 54, INK, HORIZONTAL_ALIGNMENT_CENTER), "UI_MENU_TITLE")
	_localize(_label(menu, Vector2(377, 188), Vector2(526, 36), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER), "UI_MENU_TAG")
	_color(menu, Rect2(474, 244, 332, 1), Color("716049"))
	menu_continue = _text_button(menu, "Continue", Rect2(445, 278, 390, 47), "UI_MENU_CONTINUE", func(): continue_pressed.emit(), true)
	menu_start = _text_button(menu, "Start", Rect2(445, 336, 390, 47), "UI_MENU_START", func(): start_pressed.emit(), true)
	menu_settings = _text_button(menu, "Settings", Rect2(445, 394, 390, 43), "UI_SETTINGS", show_settings)
	menu_quit = _text_button(menu, "Quit", Rect2(445, 448, 390, 43), "UI_MENU_QUIT", func(): quit_pressed.emit())
	menu_controls = _label(menu, Vector2(382, 519), Vector2(516, 95), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)

	transition = _layer("Transition")
	_dimmer(transition, 0.88)
	_localize(_label(transition, Vector2(280, 202), Vector2(720, 27), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER), "UI_TRANSITION_LABEL")
	transition_floor = _label(transition, Vector2(280, 246), Vector2(720, 83), 50, INK, HORIZONTAL_ALIGNMENT_CENTER)
	transition_reveal = RevealScene.instantiate()
	transition_reveal.position = Vector2(640, 359)
	transition.add_child(transition_reveal)
	transition_tip = _label(transition, Vector2(310, 384), Vector2(660, 75), 19, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	transition_note = _label(transition, Vector2(300, 476), Vector2(680, 77), 16, Color("c2a06a"), HORIZONTAL_ALIGNMENT_CENTER, true)
	transition_hint = _label(transition, Vector2(300, 572), Vector2(680, 32), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER)

	reward = _layer("Reward")
	result = _layer("Result")
	pause = _make_overlay("Pause")
	_dimmer(pause, 0.77)
	_panel(pause, Rect2(356, 151, 568, 432), Color("202831"), Color("8c7554"))
	_localize(_label(pause, Vector2(390, 174), Vector2(500, 51), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER), "UI_PAUSED")
	_text_button(pause, "Resume", Rect2(432, 251, 416, 47), "UI_RESUME", func(): close_requested.emit(), true)
	_text_button(pause, "Settings", Rect2(432, 312, 416, 43), "UI_SETTINGS", show_settings)
	_text_button(pause, "SaveMenu", Rect2(432, 369, 416, 43), "UI_SAVE_MENU", func(): save_menu_pressed.emit())
	pause_hint = _label(pause, Vector2(394, 436), Vector2(492, 106), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)

	overwrite = _make_overlay("Overwrite")
	_dimmer(overwrite, 0.81)
	_panel(overwrite, Rect2(318, 216, 644, 288), Color("202831"), Color("8c7554"))
	_localize(_label(overwrite, Vector2(364, 243), Vector2(552, 46), 27, GOLD, HORIZONTAL_ALIGNMENT_CENTER), "UI_OVERWRITE_TITLE")
	_localize(_label(overwrite, Vector2(370, 305), Vector2(540, 78), 17, INK, HORIZONTAL_ALIGNMENT_CENTER, true), "UI_OVERWRITE_BODY")
	_text_button(overwrite, "Cancel", Rect2(364, 417, 266, 47), "UI_CANCEL", func(): close_requested.emit())
	_text_button(overwrite, "Confirm", Rect2(650, 417, 266, 47), "UI_OVERWRITE_CONFIRM", func(): overwrite_pressed.emit(), true)

	settings = SettingsPanel.new()
	_add_overlay(settings, "Settings")
	settings.setup(self, loc)
	bag = InventoryPanel.new()
	_add_overlay(bag, "Inventory")
	bag.setup(self, loc)
	bag.item_requested.connect(func(operation: String, id: String): inventory_requested.emit(operation, id))
	bag.crafting_requested.connect(show_crafting)

	crafting = _make_overlay("Crafting")
	_dimmer(crafting, 0.84)
	_panel(crafting, Rect2(303, 182, 674, 356), Color("212932"), Color("8c7554"))
	_localize(_label(crafting, Vector2(344, 207), Vector2(592, 49), 28, GOLD, HORIZONTAL_ALIGNMENT_CENTER), "UI_CRAFT_TITLE")
	recipe = _label(crafting, Vector2(344, 280), Vector2(592, 45), 20, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	recipe_stock = _label(crafting, Vector2(344, 338), Vector2(592, 45), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	craft_button = _text_button(crafting, "Brew", Rect2(649, 432, 286, 47), "UI_CRAFT_POTION",
		func(): inventory_requested.emit("craft", "POTION"), true)
	_text_button(crafting, "Back", Rect2(344, 432, 286, 47), "UI_BACK", func(): close_requested.emit())

	lore = _make_overlay("Lore")
	_dimmer(lore, 0.85)
	_panel(lore, Rect2(252, 102, 776, 516), Color("252b31"), Color("a78b5e"))
	lore_title = _label(lore, Vector2(300, 129), Vector2(680, 48), 26, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_color(lore, Rect2(302, 189, 676, 1), Color("74614b"))
	lore_body = RichTextLabel.new()
	lore_body.name = "Body"
	lore_body.position = Vector2(307, 212)
	lore_body.size = Vector2(666, 267)
	lore_body.add_theme_font_size_override("normal_font_size", 19)
	lore_body.add_theme_color_override("default_color", INK)
	lore_body.add_theme_constant_override("line_separation", 7)
	lore_body.selection_enabled = true
	lore_body.scroll_active = true
	lore.add_child(lore_body)
	lore_close = _label(lore, Vector2(300, 492), Vector2(680, 27), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	lore_done = _button(lore, "Done", Rect2(467, 539, 346, 44), true)
	lore_done.pressed.connect(func(): close_requested.emit())

	var status := _layer("Status")
	status_panel = _panel(status, Rect2(328, 12, 624, 46), Color("2d343d"), Color("a28660"))
	status_label = _label(status_panel, Vector2(13, 0), Vector2(598, 46), 15, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	status_panel.hide()

func _layer(layer_name: String) -> Control:
	var container := Control.new()
	container.name = layer_name
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	return container

func _dimmer(parent: Control, alpha: float) -> void:
	_color(parent, Rect2(0, 0, 1280, 720), Color(0.04, 0.06, 0.09, alpha))

func _color(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _panel(parent: Control, rect: Rect2, bg: Color, border: Color) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	return panel

func _label(parent: Control, pos: Vector2, dimensions: Vector2, font_size: int, color: Color, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT, multiline := false) -> Label:
	var label := Label.new()
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if multiline:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _button(parent: Control, node_name: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", Color("171b20") if primary else INK)
	button.add_theme_color_override("font_hover_color", Color("171b20") if primary else Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("d9b477") if primary else Color("303943")
	normal.border_color = Color("e4c28b") if primary else Color("6c6458")
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(3)
	var hover := normal.duplicate()
	hover.bg_color = Color("f2ce90") if primary else Color("45515a")
	hover.border_color = GOLD
	var pressed := hover.duplicate()
	pressed.bg_color = Color("b48c59") if primary else Color("252e35")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)
	parent.add_child(button)
	return button

func _localize(control: Control, key: String) -> void:
	_static_text.append([control, key])

func _text_button(parent: Control, node_name: String, rect: Rect2, key: String, callback: Callable, primary := false) -> Button:
	var button := _button(parent, node_name, rect, primary)
	_localize(button, key)
	button.pressed.connect(callback)
	return button

func _make_overlay(layer_name: String) -> Control:
	var screen := _layer(layer_name)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	return screen

func _add_overlay(screen: Control, layer_name: String) -> void:
	screen.name = layer_name
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(screen)

func top_overlay() -> Control:
	return null if overlays.is_empty() else overlays.back()

func _push(screen: Control) -> void:
	var previous := top_overlay()
	if previous != null:
		previous.hide()
	overlays.append(screen)
	screen.show()
	overlay_changed.emit()

func pop_overlay() -> void:
	if overlays.is_empty():
		return
	var screen: Control = overlays.pop_back()
	if screen == settings:
		settings.dismiss()
	screen.hide()
	var previous := top_overlay()
	if previous != null:
		previous.show()
	overlay_changed.emit()

func _input(event: InputEvent) -> void:
	var top := top_overlay()
	if top == settings and settings.capture(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	var reading_close := top == lore and (event.is_action_pressed("interact") or (reading_epilogue and event.is_action_pressed("next")))
	var bag_close := top == bag and event.is_action_pressed("inventory")
	if event.is_action_pressed("close") or reading_close or bag_close:
		get_viewport().set_input_as_handled()
		close_requested.emit()

func _show_base(active: Control) -> void:
	while not overlays.is_empty():
		pop_overlay()
	for screen in [hud, menu, transition, reward, result]:
		screen.visible = screen == active
	for screen in [pause, overwrite, settings, bag, crafting, lore]:
		screen.hide()

func show_menu(has_save: bool) -> void:
	resume_available = has_save
	_show_base(menu)
	menu_continue.visible = has_save
	menu_start.position.y = 336 if has_save else 291
	menu_settings.position.y = 394 if has_save else 349
	menu_quit.position.y = 448 if has_save else 403
	menu_controls.position.y = 519 if has_save else 488

func show_settings() -> void:
	settings.refresh()
	_push(settings)

func show_pause(rolls_back: bool) -> void:
	pause_rolls_back = rolls_back
	_refresh_pause()
	_push(pause)

func _refresh_pause() -> void:
	pause_hint.text = loc.text("UI_SAVE_ROLLBACK" if pause_rolls_back else "UI_SAVE_HERE")

func show_overwrite() -> void:
	_push(overwrite)

func show_hud() -> void:
	_show_base(hud)

func show_transition(floor_number: int, tip_key: String, note_key: String) -> void:
	_show_base(transition)
	transition_label_data = {"floor": floor_number, "tip": tip_key, "note": note_key}
	_refresh_transition()
	set_transition_progress(0.0, false)
	transition.show()

func _refresh_transition() -> void:
	if transition_label_data.is_empty():
		return
	transition_floor.text = loc.text("UI_TRANSITION", {"floor": transition_label_data.floor})
	transition_tip.text = loc.text(transition_label_data.tip)
	var note: String = transition_label_data.note
	transition_note.text = "" if note.is_empty() else loc.text(note)
	transition_note.visible = not note.is_empty()
	transition_hint.text = loc.text("UI_TRANSITION_CONTINUE", {"next": loc.binding("next")})

func set_transition_progress(time: float, ready: bool) -> void:
	var fade := smoothstep(0.0, 0.56, time)
	var reveal := smoothstep(0.22, 1.08, time)
	transition.modulate.a = fade
	transition_floor.modulate.a = reveal
	transition_floor.position.y = 246 + (1.0 - reveal) * 18.0
	transition_reveal.show_at(reveal)
	transition_hint.visible = ready

func update_hud(player: Node, model: RunInventory, floor_number: int, floor_count: int, enemies: int,
		wave: int, total: int, hint: String, nearby: String) -> void:
	var outside := floor_number == 0
	health_label.text = loc.text("UI_HEALTH", {"hp": ceili(player.hp), "max": ceili(player.max_hp)})
	health_fill.size.x = 250.0 * clampf(player.hp / player.max_hp, 0.0, 1.0)
	floor_label.text = loc.text("UI_TOWER_GROUNDS") if outside else loc.text("UI_FLOOR", {"floor": floor_number, "total": floor_count})
	enemies_label.visible = not outside
	wave_label.visible = not outside
	enemies_label.text = loc.text("UI_ENEMIES", {"count": enemies})
	wave_label.text = loc.text("UI_WAVE", {"wave": wave, "total": total})
	magic_label.visible = not outside
	magic_value.visible = not outside
	magic_label.text = "%s  ·  %s" % [loc.binding("magic"), loc.text("UI_MAGIC")]
	magic_value.text = loc.text("UI_MAGIC_READY") if player.magic_timer <= 0.0 else loc.text("UI_MAGIC_WAIT", {"time": "%.1f" % player.magic_timer})
	inventory_label.text = loc.text("UI_BAG_HUD", {"bag": loc.binding("inventory")})
	quick_label.visible = model.potion_on_quick_slot
	quick_label.text = loc.text("UI_QUICK_HUD", {"quick": loc.binding("quick_item"), "count": model.count("POTION")})
	safe_label.text = hint
	near_label.text = nearby

func show_inventory(model: RunInventory, player: Node2D) -> void:
	bag.show_inventory(model, player)
	_push(bag)

func show_crafting() -> void:
	refresh_inventory()
	_push(crafting)

func refresh_inventory() -> void:
	if bag.inventory == null:
		return
	bag.refresh()
	recipe.text = loc.text("UI_RECIPE")
	recipe_stock.text = loc.text("UI_RECIPE_STOCK", {
		"mushrooms": bag.inventory.count("MUSHROOM"), "water": bag.inventory.count("WATER"),
		"potions": bag.inventory.count("POTION"),
	})
	craft_button.disabled = not bag.inventory.can_craft()

func show_lore(id: String, epilogue := false) -> void:
	lore_id = id
	reading_epilogue = epilogue
	_refresh_lore()
	lore_body.scroll_to_line(0)
	_push(lore)

func _refresh_lore() -> void:
	if lore_id.is_empty():
		return
	lore_title.text = loc.text(lore_id + "_TITLE")
	lore_body.text = loc.text(lore_id + "_BODY")
	var bindings := {"interact": loc.binding("interact"), "close": loc.binding("close")}
	if reading_epilogue:
		bindings["next"] = loc.binding("next")
	lore_close.text = loc.text("UI_EPILOGUE_RESULTS" if reading_epilogue else "UI_LORE_CLOSE", bindings)
	lore_done.text = loc.text("UI_VIEW_RESULTS" if reading_epilogue else "UI_CLOSE")

func _clear_layer(screen: Control) -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()

func show_reward(choices: Array[String]) -> void:
	displayed_choices = choices.duplicate()
	_show_base(reward)
	_build_reward()

func _build_reward() -> void:
	_clear_layer(reward)
	_dimmer(reward, 0.90)
	_label(reward, Vector2(200, 100), Vector2(880, 48), 32, INK, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_REWARD_TITLE")
	_label(reward, Vector2(230, 156), Vector2(820, 45), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("UI_REWARD_SUBTITLE")
	for i in range(displayed_choices.size()):
		var id := displayed_choices[i]
		var item := GameData.upgrade(id)
		var card := _button(reward, "Card%d" % i, Rect2(130 + i * 345, 226, 330, 310))
		card.pressed.connect(func(): reward_selected.emit(id))
		var badge := _color(card, Rect2(24, 24, 66, 56), [Color("9b7755"), Color("617f81"), Color("80667c")][i])
		badge.name = "IconPlaceholder"
		var badge_key := "ITEM_%s_BADGE" % id if not item.is_empty() else "UI_SUPPLIES"
		_label(badge, Vector2.ZERO, badge.size, 12, INK, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text(badge_key)
		_label(card, Vector2(24, 91), Vector2(282, 45), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text(GameData.name_key(id))
		var description: String
		if not item.is_empty():
			description = loc.text("ITEM_%s_EFFECT" % id, {"value": GameData.effect_value(item)})
			_label(card, Vector2(24, 200), Vector2(282, 70), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("ITEM_%s_LORE" % id)
		elif id == "POTION":
			description = loc.text("ITEM_POTION_EFFECT", {"value": int(GameData.POTION_HEAL)})
		else:
			description = loc.text("UI_ITEM_INGREDIENT")
		_label(card, Vector2(24, 146), Vector2(282, 50), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, true).text = description
		_label(card, Vector2(24, 277), Vector2(282, 24), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_REWARD_CHOOSE")

func show_result(victory: bool, floor_number: int, kills: int, elapsed: float, items: Array[String]) -> void:
	_show_base(result)
	_clear_layer(result)
	_dimmer(result, 0.90)
	_panel(result, Rect2(320, 78, 640, 565), Color("202831"), Color("8a7657"))
	_label(result, Vector2(350, 112), Vector2(580, 50), 30, GOLD, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_VICTORY" if victory else "UI_DEFEAT")
	_label(result, Vector2(360, 165), Vector2(560, 32), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_VICTORY_SUB" if victory else "UI_DEFEAT_SUB")
	var stats := [["UI_RESULT_FLOOR", str(floor_number)], ["UI_RESULT_KILLS", str(kills)], ["UI_RESULT_TIME", "%02d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]]]
	for i in range(stats.size()):
		_label(result, Vector2(365 + i * 185, 238), Vector2(180, 25), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text(stats[i][0])
		_label(result, Vector2(365 + i * 185, 269), Vector2(180, 35), 23, INK, HORIZONTAL_ALIGNMENT_CENTER).text = stats[i][1]
	_label(result, Vector2(360, 328), Vector2(560, 24), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_RESULT_ITEMS")
	var names: Array[String] = []
	for id in items:
		if not GameData.upgrade(id).is_empty():
			names.append(loc.text(GameData.name_key(id)))
	_label(result, Vector2(370, 357), Vector2(540, 70), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("UI_RESULT_NONE") if names.is_empty() else "  ·  ".join(names)
	var restart := _button(result, "Restart", Rect2(430, 453, 420, 48), true)
	restart.text = loc.text("UI_RESTART")
	restart.pressed.connect(func(): start_pressed.emit())
	var back := _button(result, "Back", Rect2(430, 512, 420, 44))
	back.text = loc.text("UI_BACK_MENU")
	back.pressed.connect(func(): menu_pressed.emit())

func _refresh_text() -> void:
	for entry in _static_text:
		entry[0].text = loc.text(entry[1])
	menu_controls.text = loc.text("UI_MENU_CONTROLS", {
		"move": "%s %s %s %s" % [loc.binding("move_up"), loc.binding("move_left"), loc.binding("move_down"), loc.binding("move_right")],
		"attack": loc.binding("attack"), "magic": loc.binding("magic"), "interact": loc.binding("interact"), "next": loc.binding("next"),
	})
	settings.refresh()
	_refresh_pause()
	_refresh_transition()
	refresh_inventory()
	_refresh_lore()
	if reward.visible:
		_build_reward()
	if status_remaining > 0.0:
		notify("")
	else:
		_refresh_status()

func notify(key: String, values: Dictionary = {}, seconds := 0.0) -> void:
	status_key = key
	status_values = values
	status_remaining = seconds
	_refresh_status()

func _refresh_status() -> void:
	status_panel.visible = not status_key.is_empty()
	status_label.text = loc.text(status_key, status_values) if status_panel.visible else ""

func _process(delta: float) -> void:
	if status_remaining > 0.0:
		status_remaining -= delta
		if status_remaining <= 0.0:
			notify("")
