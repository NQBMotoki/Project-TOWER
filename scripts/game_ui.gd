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
signal codex_pressed
signal dialogue_finished
signal inventory_requested(operation: String, id: String)

const GameData = preload("res://data/game_data.gd")
const EditionArt = preload("res://data/edition_art.gd")
const EnvironmentArt = preload("res://data/edition_environment.gd")
const SettingsPanel = preload("res://scripts/settings_panel.gd")
const InventoryPanel = preload("res://scripts/inventory_panel.gd")
const RevealScene = preload("res://scenes/world/floor_reveal.tscn")
const TitleScene = preload("res://scenes/ui/title_screen.tscn")
const INK := Color("efe8d8")
const MUTED := Color("b6ae9f")
const GOLD := Color("dbad82")
const BLOOD := Color("e56368")
const STONE := Color("1b1d21")
const INSET := Color("121417")
const EDGE := Color("645349")
const RULE := Color("48413a")

const HP_BAR_WIDTH := 180.0

var loc: Node
var root: Control
var hud: Control
var menu: Control
var menu_column: MarginContainer
var transition: Control
var lore: Control
var result: Control
var pause: Control
var overwrite: Control
var settings: Control
var bag: Control
var dialogue: Control
var overlays: Array[Control] = []
var _static_text: Array = []
var _panel_texture: Texture2D

var health_label: Label
var health_fill: ColorRect
var health_icon: TextureRect
var floor_label: Label
var enemies_label: Label
var wave_label: Label
var weapon_label: Label
var weapon_value: Label
var inventory_label: Label
var quick_label: Label
var safe_label: Label
var near_label: Label
var hint_panel: Panel
var weapon_panel: Panel
var shortcuts_panel: Panel
var status_label: Label
var status_panel: Panel
var status_marker: ColorRect
var status_key := ""
var status_values: Dictionary = {}
var status_remaining := 0.0
var pickup_label: Label
var pickup_panel: Panel
var pickup_icon: TextureRect
var pickup_queue: Array[Dictionary] = []
var pickup_current: Dictionary = {}
var pickup_remaining := 0.0

var menu_start: Button
var menu_continue: Button
var menu_settings: Button
var menu_codex: Button
var menu_quit: Button
var resume_available := false
var pause_hint: Label
var pause_rolls_back := false
var lore_title: Label
var lore_body: RichTextLabel
var lore_close: Label
var lore_done: Button
var lore_id := ""
var dialogue_speaker: Label
var dialogue_text: RichTextLabel
var dialogue_button: Button
var dialogue_keys: Array[String] = []
var speaker_keys: Array[String] = []
var dialogue_line := 0
var transition_floor: Label
var transition_tip: Label
var transition_note: Label
var transition_reveal: Node2D
var transition_label_data: Dictionary = {}

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
	_command_styles(theme, &"Button", Color("242629"), EDGE, INK)
	theme.set_type_variation(&"PrimaryButton", &"Button")
	_command_styles(theme, &"PrimaryButton", Color("5a3f36"), GOLD.darkened(0.12), INK)
	theme.set_type_variation(&"TitleButton", &"Button")
	_command_styles(theme, &"TitleButton", Color(0.10, 0.11, 0.13, 0.84), EDGE, INK)
	theme.set_type_variation(&"TitlePrimaryButton", &"PrimaryButton")
	_command_styles(theme, &"TitlePrimaryButton", Color("614336"), GOLD, INK)
	for type in [&"TitleButton", &"TitlePrimaryButton"]:
		for state in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
			var style := theme.get_stylebox(state, type)
			style.content_margin_left = 16.0
			style.content_margin_right = 16.0
	theme.set_type_variation(&"BloodButton", &"Button")
	_command_styles(theme, &"BloodButton", Color("48292e"), BLOOD.darkened(0.24), INK)
	theme.set_type_variation(&"TabButton", &"Button")
	_command_styles(theme, &"TabButton", STONE, STONE, MUTED)
	var active_tab := _box(Color("342a27"))
	active_tab.content_margin_left = 14.0
	active_tab.content_margin_right = 14.0
	active_tab.border_width_bottom = 2
	active_tab.border_color = GOLD
	theme.set_stylebox(&"pressed", &"TabButton", active_tab)
	theme.set_stylebox(&"hover_pressed", &"TabButton", active_tab)
	theme.set_color(&"font_pressed_color", &"TabButton", INK)
	for state in [&"normal", &"hover", &"disabled"]:
		var tab_style := theme.get_stylebox(state, &"TabButton")
		tab_style.content_margin_left = 14.0
		tab_style.content_margin_right = 14.0
	_panel_texture = EnvironmentArt.tile(EnvironmentArt.MASONRY)
	var list_panel := _box(INSET, RULE)
	list_panel.content_margin_left = 7
	list_panel.content_margin_top = 7
	list_panel.content_margin_right = 7
	list_panel.content_margin_bottom = 7
	theme.set_stylebox(&"panel", &"ItemList", list_panel)
	theme.set_stylebox(&"selected", &"ItemList", _box(Color("342a25")))
	theme.set_stylebox(&"selected_focus", &"ItemList", _box(Color("3b2e27"), GOLD.darkened(0.30)))
	theme.set_stylebox(&"cursor", &"ItemList", _box(Color.TRANSPARENT, GOLD))
	theme.set_stylebox(&"cursor_unfocused", &"ItemList", _box(Color.TRANSPARENT))
	theme.set_color(&"font_selected_color", &"ItemList", INK)
	theme.set_color(&"guide_color", &"ItemList", Color("302d29"))
	for scrollbar in [&"VScrollBar", &"HScrollBar"]:
		theme.set_stylebox(&"scroll", scrollbar, _box(INSET))
		theme.set_stylebox(&"grabber", scrollbar, _box(EDGE))
		theme.set_stylebox(&"grabber_highlight", scrollbar, _box(GOLD.darkened(0.25)))
		theme.set_stylebox(&"grabber_pressed", scrollbar, _box(GOLD))
	var track := _box(Color("3b3530"))
	track.content_margin_top = 2
	track.content_margin_bottom = 2
	var fill := track.duplicate() as StyleBoxFlat
	fill.bg_color = GOLD.darkened(0.23)
	theme.set_stylebox(&"slider", &"HSlider", track)
	theme.set_stylebox(&"grabber_area", &"HSlider", fill)
	theme.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	var thumb := Image.create_empty(8, 16, false, Image.FORMAT_RGBA8)
	thumb.fill(GOLD)
	var thumb_texture := ImageTexture.create_from_image(thumb)
	theme.set_icon(&"grabber", &"HSlider", thumb_texture)
	theme.set_icon(&"grabber_highlight", &"HSlider", thumb_texture)
	var view := Control.new()
	view.name = "Interface"
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	view.theme = theme
	add_child(view)
	root = view

func _build_ui() -> void:
	hud = _layer("HUD")
	var hud_backing := Color(0.064, 0.067, 0.076, 0.92)
	_panel(hud, Rect2(32, 24, 212, 54), hud_backing, Color.TRANSPARENT)
	_panel(hud, Rect2(1000, 24, 248, 54), hud_backing, Color.TRANSPARENT)
	weapon_panel = _panel(hud, Rect2(32, 637, 289, 59), hud_backing, Color.TRANSPARENT)
	shortcuts_panel = _panel(hud, Rect2(1029, 637, 219, 59), hud_backing, Color.TRANSPARENT)
	hint_panel = _panel(hud, Rect2(369, 595, 542, 101), hud_backing, Color.TRANSPARENT)
	health_icon = TextureRect.new()
	health_icon.name = "HealthIcon"
	health_icon.position = Vector2(48, 36)
	health_icon.size = Vector2(18, 18)
	health_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	health_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	health_icon.texture = EditionArt.icon("ui_health")
	health_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(health_icon)
	var health_x := 73.0 if health_icon.texture != null else 48.0
	health_label = _label(hud, Vector2(health_x, 33), Vector2(228.0 - health_x, 25), 16, INK)
	_color(hud, Rect2(48, 61, HP_BAR_WIDTH, 5), Color("422529"))
	health_fill = _color(hud, Rect2(48, 61, HP_BAR_WIDTH, 5), BLOOD)
	floor_label = _label(hud, Vector2(1016, 31), Vector2(216, 22), 17, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	enemies_label = _label(hud, Vector2(1016, 53), Vector2(94, 18), 13, MUTED)
	wave_label = _label(hud, Vector2(1105, 53), Vector2(127, 18), 13, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	weapon_label = _label(hud, Vector2(48, 643), Vector2(257, 24), 16, INK)
	weapon_value = _label(hud, Vector2(48, 667), Vector2(257, 21), 14, MUTED)
	inventory_label = _label(hud, Vector2(1045, 643), Vector2(187, 24), 15, INK, HORIZONTAL_ALIGNMENT_RIGHT)
	quick_label = _label(hud, Vector2(1045, 667), Vector2(187, 21), 14, MUTED, HORIZONTAL_ALIGNMENT_RIGHT)
	safe_label = _label(hud, Vector2(389, 647), Vector2(502, 36), 15, MUTED, HORIZONTAL_ALIGNMENT_CENTER, true)
	near_label = _label(hud, Vector2(389, 603), Vector2(502, 38), 17, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)

	_build_title()

	transition = _layer("Transition")
	_dimmer(transition, 0.88)
	transition_floor = _label(transition, Vector2(280, 246), Vector2(720, 83), 50, INK, HORIZONTAL_ALIGNMENT_CENTER)
	transition_reveal = RevealScene.instantiate()
	transition_reveal.position = Vector2(640, 359)
	transition.add_child(transition_reveal)
	transition_tip = _label(transition, Vector2(310, 384), Vector2(660, 75), 18, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	transition_note = _label(transition, Vector2(300, 476), Vector2(680, 77), 16, GOLD, HORIZONTAL_ALIGNMENT_CENTER, true)

	result = _layer("Result")
	pause = _make_overlay("Pause")
	_dimmer(pause, 0.77)
	_panel(pause, Rect2(404, 161, 472, 398))
	_localize(_label(pause, Vector2(436, 188), Vector2(408, 43), 27, INK), "UI_PAUSED")
	_text_button(pause, "Resume", Rect2(436, 251, 408, 44), "UI_RESUME", func(): close_requested.emit(), true)
	_text_button(pause, "Settings", Rect2(436, 306, 408, 42), "UI_SETTINGS", show_settings)
	_text_button(pause, "SaveMenu", Rect2(436, 358, 408, 42), "UI_SAVE_MENU", func(): save_menu_pressed.emit())
	pause_hint = _label(pause, Vector2(436, 425), Vector2(408, 100), 15, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)

	overwrite = _make_overlay("Overwrite")
	_dimmer(overwrite, 0.81)
	_panel(overwrite, Rect2(334, 211, 612, 298))
	_localize(_label(overwrite, Vector2(368, 241), Vector2(544, 43), 26, INK), "UI_OVERWRITE_TITLE")
	_localize(_label(overwrite, Vector2(368, 305), Vector2(544, 78), 16, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true), "UI_OVERWRITE_BODY")
	_text_button(overwrite, "Cancel", Rect2(368, 420, 263, 43), "UI_CANCEL", func(): close_requested.emit())
	_text_button(overwrite, "Confirm", Rect2(649, 420, 263, 43), "UI_OVERWRITE_CONFIRM", func(): overwrite_pressed.emit(), true)

	settings = SettingsPanel.new()
	_add_overlay(settings, "Settings")
	settings.setup(self, loc)
	bag = InventoryPanel.new()
	_add_overlay(bag, "Inventory")
	bag.setup(self, loc)
	bag.item_requested.connect(func(operation: String, id: String): inventory_requested.emit(operation, id))
	lore = _make_overlay("Lore")
	_dimmer(lore, 0.85)
	_panel(lore, Rect2(248, 89, 784, 542))
	lore_title = _label(lore, Vector2(286, 118), Vector2(708, 49), 27, INK, HORIZONTAL_ALIGNMENT_LEFT, true)
	_color(lore, Rect2(286, 181, 708, 1), RULE)
	lore_body = RichTextLabel.new()
	lore_body.name = "Body"
	lore_body.position = Vector2(286, 204)
	lore_body.size = Vector2(708, 316)
	lore_body.add_theme_font_size_override("normal_font_size", 19)
	lore_body.add_theme_color_override("default_color", INK)
	lore_body.add_theme_constant_override("line_separation", 7)
	lore_body.selection_enabled = true
	lore_body.scroll_active = true
	lore.add_child(lore_body)
	lore_close = _label(lore, Vector2(286, 551), Vector2(454, 40), 14, MUTED)
	lore_done = _button(lore, "Done", Rect2(788, 550, 206, 43), true)
	lore_done.pressed.connect(func(): close_requested.emit())

	dialogue = _make_overlay("Dialogue")
	_dimmer(dialogue, 0.47)
	_panel(dialogue, Rect2(264, 410, 752, 272))
	dialogue_speaker = _label(dialogue, Vector2(298, 430), Vector2(684, 36), 22, GOLD)
	dialogue_text = RichTextLabel.new()
	dialogue_text.position = Vector2(298, 482)
	dialogue_text.size = Vector2(684, 109)
	dialogue_text.add_theme_font_size_override("normal_font_size", 18)
	dialogue_text.add_theme_color_override("default_color", INK)
	dialogue_text.add_theme_constant_override("line_separation", 5)
	dialogue.add_child(dialogue_text)
	dialogue_button = _button(dialogue, "NextLine", Rect2(761, 606, 221, 43), true)
	dialogue_button.pressed.connect(_advance_dialogue)

	var status := _layer("Status")
	status_panel = _panel(status, Rect2(400, 21, 480, 48), INSET, EDGE)
	status_marker = _color(status_panel, Rect2(0, 0, 3, 48), GOLD)
	status_label = _label(status_panel, Vector2(17, 0), Vector2(446, 48), 15, INK, HORIZONTAL_ALIGNMENT_CENTER, true)
	status_panel.hide()
	pickup_panel = _panel(status, Rect2(440, 82, 400, 40), INSET, Color.TRANSPARENT)
	pickup_icon = TextureRect.new()
	pickup_icon.position = Vector2(11, 8)
	pickup_icon.size = Vector2(24, 24)
	pickup_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pickup_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	pickup_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pickup_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pickup_panel.add_child(pickup_icon)
	pickup_label = _label(pickup_panel, Vector2(44, 0), Vector2(344, 40), 14, MUTED, HORIZONTAL_ALIGNMENT_LEFT, true)
	pickup_panel.hide()

func _build_title() -> void:
	menu = TitleScene.instantiate()
	root.add_child(menu)
	menu_column = menu.get_node("%Column")
	var title: Label = menu.get_node("%Title")
	title.add_theme_color_override("font_color", INK)
	title.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.50))
	title.add_theme_constant_override("shadow_offset_y", 2)
	_localize(title, "UI_MENU_TITLE")
	menu_continue = _bind_title_button("Continue", "UI_MENU_CONTINUE", func(): continue_pressed.emit(), "ui_continue")
	menu_continue.theme_type_variation = &"TitlePrimaryButton"
	menu_start = _bind_title_button("Start", "UI_MENU_START", func(): start_pressed.emit(), "ui_new")
	menu_settings = _bind_title_button("Settings", "UI_SETTINGS", show_settings, "ui_settings")
	menu_codex = _bind_title_button("Codex", "UI_CODEX_TITLE", func(): codex_pressed.emit(), "ui_codex")
	menu_quit = _bind_title_button("Quit", "UI_MENU_QUIT", func(): quit_pressed.emit())

func _bind_title_button(node_name: String, key: String, callback: Callable, icon_id := "") -> Button:
	var button: Button = menu.get_node("%%%s" % node_name)
	button.theme_type_variation = &"TitleButton"
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_localize(button, key)
	button.pressed.connect(callback)
	if not icon_id.is_empty():
		_set_command_icon(button, icon_id, 21)
	return button

func _set_command_icon(button: Button, icon_id: String, size: int) -> void:
	button.icon = EditionArt.icon(icon_id)
	button.add_theme_constant_override("icon_max_width", size)
	button.add_theme_constant_override("h_separation", 9)

func _layer(layer_name: String) -> Control:
	var container := Control.new()
	container.name = layer_name
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(container)
	return container

func _dimmer(parent: Control, alpha: float) -> void:
	_color(parent, Rect2(0, 0, 1280, 720), Color(0.027, 0.027, 0.032, alpha))

func _color(parent: Control, rect: Rect2, color: Color) -> ColorRect:
	var node := ColorRect.new()
	node.position = rect.position
	node.size = rect.size
	node.color = color
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func _box(bg: Color, border := Color.TRANSPARENT) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(0 if border.a == 0.0 else 1)
	style.set_corner_radius_all(5)
	return style

func _panel(parent: Control, rect: Rect2, bg := STONE, border := EDGE) -> Panel:
	var panel := Panel.new()
	panel.position = rect.position
	panel.size = rect.size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _box(bg, border)
	var is_slate := bg == STONE
	if is_slate:
		style.set_corner_radius_all(9)
		style.shadow_size = 12
		style.shadow_offset = Vector2(0, 5)
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.39)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	if is_slate and _panel_texture != null:
		var material := TextureRect.new()
		material.name = "SlateTexture"
		material.texture = _panel_texture
		material.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		material.stretch_mode = TextureRect.STRETCH_TILE
		material.modulate = Color(0.91, 0.95, 1.0, 0.077)
		material.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(material)
		material.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		material.offset_left = 5.0
		material.offset_top = 5.0
		material.offset_right = -5.0
		material.offset_bottom = -5.0
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

func _command_styles(theme: Theme, type: StringName, bg: Color, border: Color, ink: Color) -> void:
	theme.set_stylebox(&"normal", type, _box(bg, border))
	var hover := _box(bg.lightened(0.14), GOLD.lightened(0.12))
	hover.shadow_size = 5
	hover.shadow_offset = Vector2(0, 2)
	hover.shadow_color = Color(0.0, 0.0, 0.0, 0.38)
	theme.set_stylebox(&"hover", type, hover)
	theme.set_stylebox(&"pressed", type, _box(Color("3b2d27"), GOLD))
	theme.set_stylebox(&"hover_pressed", type, _box(Color("44332a"), GOLD))
	theme.set_stylebox(&"disabled", type, _box(INSET, RULE))
	var focus := _box(Color.TRANSPARENT, GOLD.lightened(0.20))
	focus.set_border_width_all(2)
	theme.set_stylebox(&"focus", type, focus)
	theme.set_color(&"font_color", type, ink)
	theme.set_color(&"font_hover_color", type, INK)
	theme.set_color(&"font_pressed_color", type, INK)
	theme.set_color(&"font_focus_color", type, INK)
	theme.set_color(&"font_disabled_color", type, Color("827b70"))

func _button(parent: Control, node_name: String, rect: Rect2, primary := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.position = rect.position
	button.size = rect.size
	button.focus_mode = Control.FOCUS_ALL
	button.theme_type_variation = &"PrimaryButton" if primary else &"Button"
	button.add_theme_font_size_override("font_size", 16)
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
	if menu.visible:
		menu_column.hide()
	_refresh_pickup_notice()
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
	elif menu.visible:
		_focus_title()
	_refresh_pickup_notice()
	overlay_changed.emit()

func _input(event: InputEvent) -> void:
	var top := top_overlay()
	if top == settings and settings.capture(event):
		get_viewport().set_input_as_handled()
		return
	if event.is_echo():
		return
	if top == dialogue:
		if event.is_action_pressed("close"):
			get_viewport().set_input_as_handled()
			show_pause(false)
		elif event.is_action_pressed("next") or event.is_action_pressed("interact"):
			get_viewport().set_input_as_handled()
			_advance_dialogue()
		return
	var reading_close := top == lore and event.is_action_pressed("interact")
	var bag_close := top == bag and event.is_action_pressed("inventory")
	if event.is_action_pressed("close") or reading_close or bag_close:
		get_viewport().set_input_as_handled()
		close_requested.emit()

func _show_base(active: Control) -> void:
	while not overlays.is_empty():
		pop_overlay()
	for screen in [hud, menu, transition, result]:
		screen.visible = screen == active
	for screen in [pause, overwrite, settings, bag, lore, dialogue]:
		screen.hide()
	_refresh_pickup_notice()

func show_menu(has_save: bool) -> void:
	resume_available = has_save
	clear_pickup_notices()
	_show_base(menu)
	menu_continue.visible = has_save
	menu_start.theme_type_variation = &"TitleButton" if has_save else &"TitlePrimaryButton"
	_focus_title()

func _focus_title() -> void:
	menu_column.show()
	var focused := menu_continue if resume_available else menu_start
	focused.grab_focus()

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
	transition_label_data = {"floor": floor_number, "tip": tip_key, "note": note_key, "title": ""}
	_refresh_transition()
	set_transition_progress(0.0, false)
	transition.show()

func show_special_transition(title_key: String, tip_key: String) -> void:
	_show_base(transition)
	transition_label_data = {"floor": 0, "tip": tip_key, "note": "", "title": title_key}
	_refresh_transition()
	set_transition_progress(0.0, false)
	transition.show()

func _refresh_transition() -> void:
	if transition_label_data.is_empty():
		return
	var title: String = transition_label_data.title
	transition_floor.text = loc.text("UI_TRANSITION", {"floor": transition_label_data.floor}) if title.is_empty() else loc.text(title)
	transition_tip.text = "" if transition_label_data.tip.is_empty() else loc.text(transition_label_data.tip)
	var note: String = transition_label_data.note
	transition_note.text = "" if note.is_empty() else loc.text(note)
	transition_note.visible = not note.is_empty()

func set_transition_progress(time: float, _ready_to_leave: bool) -> void:
	var fade := smoothstep(0.0, 0.56, time)
	var reveal := smoothstep(0.22, 1.08, time)
	transition.modulate.a = fade
	transition_floor.modulate.a = reveal
	transition_floor.position.y = 246 + (1.0 - reveal) * 18.0
	transition_reveal.show_at(reveal)

func update_hud(player: Node, model: RunInventory, floor_number: int, floor_count: int, enemies: int,
		wave: int, total: int, hint: String, nearby: String) -> void:
	var outside := floor_number == 0
	health_label.text = loc.text("UI_HEALTH", {"hp": ceili(player.hp), "max": ceili(player.max_hp)})
	health_fill.size.x = HP_BAR_WIDTH * clampf(player.hp / player.max_hp, 0.0, 1.0)
	floor_label.text = loc.text("UI_TOWER_GROUNDS") if outside else loc.text("UI_FLOOR", {"floor": floor_number, "total": floor_count})
	enemies_label.visible = not outside and wave > 0
	wave_label.visible = not outside and wave > 0
	enemies_label.text = loc.text("UI_ENEMIES", {"count": enemies})
	wave_label.text = loc.text("UI_WAVE", {"wave": wave, "total": total})
	var equipped := model.current_weapon()
	var attack_data: Dictionary = player.weapon_data()
	weapon_label.text = loc.text("UI_WEAPON_UNARMED") if equipped.is_empty() else loc.text(GameData.name_key(equipped))
	weapon_label.position.y = 654 if attack_data.is_empty() else 643
	weapon_panel.position.y = 647 if attack_data.is_empty() else 637
	weapon_panel.size.y = 49 if attack_data.is_empty() else 59
	if attack_data.is_empty():
		weapon_value.text = ""
	else:
		var range_name: String = loc.text("UI_ATTACK_%s" % attack_data.range_type.to_upper())
		var time: float = player.attack_ready_in()
		weapon_value.text = loc.text("UI_WEAPON_HUD", {"attack": loc.binding("attack"), "mode": range_name})
		if time > 0.0:
			weapon_value.text += "  ·  " + loc.text("UI_INTERVAL_VALUE", {"time": "%.1f" % time})
	inventory_label.text = loc.text("UI_BAG_HUD", {"bag": loc.binding("inventory")})
	quick_label.visible = model.potion_on_quick_slot
	inventory_label.position.y = 643 if quick_label.visible else 654
	shortcuts_panel.position.y = 637 if quick_label.visible else 647
	shortcuts_panel.size.y = 59 if quick_label.visible else 49
	quick_label.text = loc.text("UI_QUICK_HUD", {"quick": loc.binding("quick_item"), "count": model.count("POTION")})
	safe_label.text = hint
	near_label.text = nearby
	safe_label.visible = not hint.is_empty()
	near_label.visible = not nearby.is_empty()
	hint_panel.visible = safe_label.visible or near_label.visible
	var two_lines := safe_label.visible and near_label.visible
	hint_panel.position.y = 595 if two_lines else 638
	hint_panel.size.y = 101 if two_lines else 58
	near_label.position.y = 601 if two_lines else 647

func show_inventory(model: RunInventory, player: Node2D, progress: RunCodex = null) -> void:
	bag.show_inventory(model, player, progress)
	_push(bag)

func show_codex(progress: RunCodex) -> void:
	bag.show_codex(progress)
	_push(bag)

func refresh_inventory() -> void:
	bag.refresh()

func show_lore(id: String) -> void:
	lore_id = id
	_refresh_lore()
	lore_body.scroll_to_line(0)
	_push(lore)

func _refresh_lore() -> void:
	if lore_id.is_empty():
		return
	lore_title.text = loc.text(lore_id + "_TITLE")
	lore_body.text = loc.text(lore_id + "_BODY")
	lore_close.text = loc.text("UI_LORE_CLOSE", {"interact": loc.binding("interact"), "close": loc.binding("close")})
	lore_done.text = loc.text("UI_CLOSE")

func show_dialogue(lines: Array[String], speakers: Array[String] = []) -> void:
	if lines.is_empty():
		return
	dialogue_keys = lines.duplicate()
	speaker_keys = speakers.duplicate()
	dialogue_line = 0
	_refresh_dialogue()
	_push(dialogue)

func _refresh_dialogue() -> void:
	if dialogue_line >= dialogue_keys.size():
		return
	var speaker := "UI_DIALOGUE_TITLE"
	if dialogue_line < speaker_keys.size():
		speaker = speaker_keys[dialogue_line]
	dialogue_speaker.text = loc.text(speaker)
	dialogue_text.text = loc.text(dialogue_keys[dialogue_line])
	dialogue_text.scroll_to_line(0)
	dialogue_button.text = loc.text("UI_DIALOGUE_CONTINUE")
	dialogue_button.tooltip_text = loc.binding("next")

func _advance_dialogue() -> void:
	if top_overlay() != dialogue:
		return
	dialogue_line += 1
	if dialogue_line < dialogue_keys.size():
		_refresh_dialogue()
		return
	pop_overlay()
	dialogue_finished.emit()

func _clear_layer(screen: Control) -> void:
	for child in screen.get_children():
		screen.remove_child(child)
		child.queue_free()

func show_result(victory: bool, floor_number: int, kills: int, elapsed: float, _items: Array[String]) -> void:
	clear_pickup_notices()
	_show_base(result)
	_clear_layer(result)
	_dimmer(result, 0.81)
	_panel(result, Rect2(340, 174, 600, 372))
	_label(result, Vector2(376, 204), Vector2(528, 50), 32, GOLD if victory else BLOOD).text = loc.text("UI_VICTORY" if victory else "UI_DEFEAT")
	_color(result, Rect2(376, 276, 528, 1), RULE)
	var stats := [["UI_RESULT_FLOOR", str(floor_number)], ["UI_RESULT_KILLS", str(kills)], ["UI_RESULT_TIME", "%02d:%02d" % [floori(elapsed / 60.0), int(elapsed) % 60]]]
	for i in range(stats.size()):
		_label(result, Vector2(376 + i * 176, 301), Vector2(168, 25), 15, MUTED).text = loc.text(stats[i][0])
		_label(result, Vector2(376 + i * 176, 333), Vector2(168, 43), 29, INK).text = stats[i][1]
	var restart := _button(result, "Restart", Rect2(649, 449, 255, 47), true)
	restart.text = loc.text("UI_RESTART")
	restart.pressed.connect(func(): start_pressed.emit())
	var back := _button(result, "Back", Rect2(376, 449, 255, 47))
	back.text = loc.text("UI_BACK_MENU")
	back.pressed.connect(func(): menu_pressed.emit())

func _refresh_text() -> void:
	for entry in _static_text:
		entry[0].text = loc.text(entry[1])
	settings.refresh()
	_refresh_pause()
	_refresh_transition()
	refresh_inventory()
	_refresh_lore()
	_refresh_dialogue()
	_refresh_status()
	_refresh_pickup_notice()

func notify(key: String, values: Dictionary = {}, seconds := 0.0) -> void:
	status_key = key
	status_values = values
	status_remaining = seconds
	_refresh_status()

func _refresh_status() -> void:
	status_panel.visible = not status_key.is_empty()
	var is_blood := status_key.begins_with("UI_PEARL_") or status_key == "UI_CORRUPTION_SUCCESS"
	status_marker.color = BLOOD if is_blood else GOLD
	status_label.text = loc.text(status_key, status_values) if status_panel.visible else ""
	_refresh_pickup_notice()

func notify_pickup(id: String, count := 1) -> void:
	if pickup_current.get("id") == id:
		pickup_current.count += count
		pickup_remaining = 2.2
		_refresh_pickup_notice()
		return
	for entry in pickup_queue:
		if entry.id == id:
			entry.count += count
			return
	pickup_queue.append({"id": id, "count": count})
	if pickup_current.is_empty():
		_next_pickup_notice()

func _next_pickup_notice() -> void:
	pickup_current = {} if pickup_queue.is_empty() else pickup_queue.pop_front()
	pickup_remaining = 2.2 if not pickup_current.is_empty() else 0.0
	_refresh_pickup_notice()

func clear_pickup_notices() -> void:
	pickup_queue.clear()
	_next_pickup_notice()

func _refresh_pickup_notice() -> void:
	pickup_panel.visible = hud.visible and top_overlay() == null and not pickup_current.is_empty()
	if not pickup_panel.visible:
		return
	var id: String = pickup_current.id
	pickup_icon.texture = EditionArt.icon(id)
	var item: String = loc.text(GameData.name_key(id))
	if pickup_current.count > 1:
		pickup_label.text = loc.text("UI_PICKED_UP_COUNT", {"item": item, "count": pickup_current.count})
	else:
		pickup_label.text = loc.text("UI_PICKED_UP", {"item": item})

func _process(delta: float) -> void:
	if pickup_panel.visible and pickup_remaining > 0.0:
		pickup_remaining -= delta
		if pickup_remaining <= 0.0:
			_next_pickup_notice()
	if status_remaining > 0.0:
		status_remaining -= delta
		if status_remaining <= 0.0:
			notify("")
