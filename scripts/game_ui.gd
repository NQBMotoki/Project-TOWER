extends CanvasLayer

signal start_pressed
signal quit_pressed
signal restart_pressed
signal menu_pressed
signal upgrade_selected(item: Dictionary)

const GameData = preload("res://data/game_data.gd")
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
var health_label: Label
var health_fill: ColorRect
var floor_label: Label
var enemies_label: Label
var wave_label: Label
var magic_label: Label
var magic_value: Label
var inventory_label: Label
var safe_label: Label
var near_label: Label
var menu_start: Button
var menu_quit: Button
var menu_kicker: Label
var menu_tag: Label
var menu_controls: Label
var menu_language: Label
var language_zh: Button
var language_en: Button
var lore_title: Label
var lore_body: Label
var lore_close: Label
var transition_floor: Label
var transition_tip: Label
var transition_heading: Label

func setup(service: Node) -> void:
	loc = service
	_build_theme()
	_build_ui()
	loc.language_changed.connect(_refresh_menu)
	_refresh_menu()
	show_menu()

func _build_theme() -> void:
	var theme := Theme.new()
	# A bundled OFL font keeps Chinese and English readable on both platforms.
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
	enemies_label = _label(hud, Vector2(840, 51), Vector2(180, 22), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	wave_label = _label(hud, Vector2(1018, 51), Vector2(150, 22), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	magic_label = _label(hud, Vector2(112, 629), Vector2(200, 24), 14, CYAN)
	magic_value = _label(hud, Vector2(112, 654), Vector2(200, 25), 18, INK)
	inventory_label = _label(hud, Vector2(365, 631), Vector2(803, 52), 15, MUTED, HORIZONTAL_ALIGNMENT_RIGHT, true)
	safe_label = _label(hud, Vector2(200, 558), Vector2(880, 30), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	near_label = _label(hud, Vector2(400, 515), Vector2(480, 26), 16, INK, HORIZONTAL_ALIGNMENT_CENTER)

	menu = _layer("Menu")
	_dimmer(menu, 0.81)
	_panel(menu, Rect2(320, 65, 640, 590), Color("202831"), Color("74634d"))
	menu_kicker = _label(menu, Vector2(390, 100), Vector2(500, 24), 13, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	_label(menu, Vector2(350, 129), Vector2(580, 70), 52, INK, HORIZONTAL_ALIGNMENT_CENTER).text = "T O W E R"
	menu_tag = _label(menu, Vector2(380, 205), Vector2(520, 30), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	_color(menu, Rect2(470, 252, 340, 2), Color("716049"))
	menu_controls = _label(menu, Vector2(385, 275), Vector2(510, 92), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	menu_start = _button(menu, "Start", Rect2(430, 388, 420, 48), true)
	menu_start.pressed.connect(func(): start_pressed.emit())
	menu_quit = _button(menu, "Quit", Rect2(430, 447, 420, 44))
	menu_quit.pressed.connect(func(): quit_pressed.emit())
	menu_language = _label(menu, Vector2(390, 524), Vector2(500, 24), 13, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	language_zh = _button(menu, "Chinese", Rect2(440, 556, 190, 42))
	language_zh.text = "简体中文"
	language_zh.pressed.connect(func(): loc.set_language("zh_CN"))
	language_en = _button(menu, "English", Rect2(650, 556, 190, 42))
	language_en.text = "English (US)"
	language_en.pressed.connect(func(): loc.set_language("en_US"))

	transition = _layer("Transition")
	_dimmer(transition, 0.85)
	transition_heading = _label(transition, Vector2(280, 238), Vector2(720, 27), 14, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	transition_floor = _label(transition, Vector2(280, 282), Vector2(720, 80), 44, INK, HORIZONTAL_ALIGNMENT_CENTER)
	_color(transition, Rect2(450, 386, 380, 2), Color("77654b"))
	transition_tip = _label(transition, Vector2(300, 410), Vector2(680, 85), 17, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)

	reward = _layer("Reward")
	lore = _layer("Lore")
	_dimmer(lore, 0.82)
	_panel(lore, Rect2(300, 206, 680, 308), Color("252b31"), Color("a78b5e"))
	lore_title = _label(lore, Vector2(345, 242), Vector2(590, 40), 24, GOLD, HORIZONTAL_ALIGNMENT_CENTER)
	lore_body = _label(lore, Vector2(355, 308), Vector2(570, 120), 19, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	lore_close = _label(lore, Vector2(345, 457), Vector2(590, 25), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER)
	result = _layer("Result")

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

func _refresh_menu() -> void:
	menu_kicker.text = loc.text("UI_MENU_KICKER")
	menu_tag.text = loc.text("UI_MENU_TAG")
	menu_start.text = loc.text("UI_MENU_START")
	menu_quit.text = loc.text("UI_MENU_QUIT")
	menu_language.text = loc.text("UI_MENU_LANGUAGE")
	menu_controls.text = loc.text("UI_MENU_CONTROLS", {"move": "%s %s %s %s" % [loc.binding("move_up"), loc.binding("move_left"), loc.binding("move_down"), loc.binding("move_right")], "attack": loc.binding("attack"), "magic": loc.binding("magic"), "interact": loc.binding("interact"), "next": loc.binding("next")})
	language_zh.modulate = Color.WHITE if loc.locale == "zh_CN" else Color(0.7, 0.7, 0.7)
	language_en.modulate = Color.WHITE if loc.locale == "en_US" else Color(0.7, 0.7, 0.7)

func _hide_all() -> void:
	for screen in [hud, menu, transition, reward, lore, result]:
		screen.hide()

func show_menu() -> void:
	_hide_all()
	_refresh_menu()
	menu.show()

func show_hud() -> void:
	_hide_all()
	hud.show()

func show_transition(floor_number: int) -> void:
	_hide_all()
	transition_heading.text = loc.text("UI_TRANSITION_LABEL")
	transition_floor.text = loc.text("UI_TRANSITION", {"floor": floor_number})
	transition_tip.text = loc.text("TRANSITION_TIP_%02d" % randi_range(1, 5))
	transition.show()

func update_hud(player: Node, floor_number: int, enemies: int, wave: int, total: int, safe: bool, near: bool) -> void:
	health_label.text = loc.text("UI_HEALTH", {"hp": ceili(player.hp), "max": ceili(player.max_hp)})
	health_fill.size.x = 250.0 * clampf(player.hp / player.max_hp, 0.0, 1.0)
	floor_label.text = loc.text("UI_FLOOR", {"floor": floor_number})
	enemies_label.text = loc.text("UI_ENEMIES", {"count": enemies})
	wave_label.text = loc.text("UI_WAVE", {"wave": wave, "total": total})
	magic_label.text = "%s  ·  %s" % [loc.binding("magic"), loc.text("UI_MAGIC")]
	magic_value.text = loc.text("UI_MAGIC_READY") if player.magic_timer <= 0.0 else loc.text("UI_MAGIC_WAIT", {"time": "%.1f" % player.magic_timer})
	var names: Array[String] = []
	for id in player.upgrades:
		names.append(loc.text("ITEM_%s_NAME" % id))
	inventory_label.text = loc.text("UI_INVENTORY_EMPTY") if names.is_empty() else loc.text("UI_INVENTORY", {"items": "  ·  ".join(names)})
	safe_label.text = loc.text("UI_SAFE", {"next": loc.binding("next")})
	safe_label.visible = safe
	near_label.text = loc.text("UI_READ_NEAR", {"interact": loc.binding("interact")})
	near_label.visible = safe and near

func show_lore(data: Dictionary) -> void:
	lore_title.text = loc.text(data.title)
	lore_body.text = loc.text(data.body)
	lore_close.text = loc.text("UI_LORE_CLOSE", {"interact": loc.binding("interact"), "close": loc.binding("close")})
	lore.show()

func close_lore() -> void:
	lore.hide()

func _clear_layer(screen: Control) -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()

func show_reward(choices: Array) -> void:
	_hide_all()
	_clear_layer(reward)
	_dimmer(reward, 0.90)
	_label(reward, Vector2(200, 100), Vector2(880, 48), 32, INK, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_REWARD_TITLE")
	_label(reward, Vector2(230, 156), Vector2(820, 45), 16, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("UI_REWARD_SUBTITLE")
	for i in range(choices.size()):
		var item: Dictionary = choices[i]
		var card := _button(reward, "Card%d" % i, Rect2(130 + i * 345, 226, 330, 310))
		card.pressed.connect(func(): upgrade_selected.emit(item))
		var badge := _color(card, Rect2(24, 24, 56, 56), Color("6b5946"))
		badge.color = [Color("9b7755"), Color("617f81"), Color("80667c")][i]
		_label(card, Vector2(24, 24), Vector2(56, 56), 13, INK, HORIZONTAL_ALIGNMENT_CENTER).text = item.id
		_label(card, Vector2(24, 91), Vector2(282, 45), 20, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("ITEM_%s_NAME" % item.id)
		_label(card, Vector2(24, 146), Vector2(282, 50), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("ITEM_%s_EFFECT" % item.id, {"value": GameData.effect_value(item)})
		_label(card, Vector2(24, 201), Vector2(282, 72), 14, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("ITEM_%s_LORE" % item.id)
		_label(card, Vector2(24, 280), Vector2(282, 20), 12, GOLD, HORIZONTAL_ALIGNMENT_CENTER).text = loc.text("UI_REWARD_CHOOSE")
	reward.show()

func show_result(victory: bool, floor_number: int, kills: int, elapsed: float, items: Array) -> void:
	_hide_all()
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
		names.append(loc.text("ITEM_%s_NAME" % id))
	_label(result, Vector2(370, 357), Vector2(540, 62), 16, INK, HORIZONTAL_ALIGNMENT_CENTER, true).text = loc.text("UI_RESULT_NONE") if names.is_empty() else "  ·  ".join(names)
	var restart := _button(result, "Restart", Rect2(430, 453, 420, 48), true)
	restart.text = loc.text("UI_RESTART")
	restart.pressed.connect(func(): restart_pressed.emit())
	var back := _button(result, "Back", Rect2(430, 512, 420, 44))
	back.text = loc.text("UI_BACK_MENU")
	back.pressed.connect(func(): menu_pressed.emit())
	result.show()
