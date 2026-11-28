extends Control

var ui: CanvasLayer
var loc: Node
var title: Label
var quality_label: Label
var quality_low: Button
var quality_high: Button
var language_label: Label
var language_zh: Button
var language_en: Button
var bindings_title: Label
var fixed_escape: Label
var capture_hint: Label
var reset: Button
var back: Button
var sound_test: Button
var action_labels: Dictionary = {}
var action_buttons: Dictionary = {}
var volume_labels: Dictionary = {}
var volume_values: Dictionary = {}
var sliders: Dictionary = {}
var capturing := ""
var hint_key := ""
var hint_values: Dictionary = {}
var volumes_dirty := false

func setup(interface: CanvasLayer, service: Node) -> void:
	ui = interface
	loc = service
	ui._dimmer(self, 0.80)
	ui._panel(self, Rect2(208, 54, 864, 612))
	title = ui._label(self, Vector2(245, 75), Vector2(790, 46), 27, ui.INK)
	ui._color(self, Rect2(245, 129, 790, 1), ui.RULE)
	ui._color(self, Rect2(604, 152, 1, 406), ui.RULE)
	ui._localize(ui._label(self, Vector2(251, 151), Vector2(306, 25), 17, ui.GOLD), "UI_SETTINGS_DISPLAY")
	quality_label = ui._label(self, Vector2(251, 181), Vector2(126, 34), 15, ui.INK)
	quality_low = ui._button(self, "QualityLow", Rect2(382, 181, 107, 34))
	quality_high = ui._button(self, "QualityHigh", Rect2(495, 181, 91, 34))
	quality_low.pressed.connect(func(): loc.set_quality(false))
	quality_high.pressed.connect(func(): loc.set_quality(true))
	_segmented(quality_low, quality_high)
	language_label = ui._label(self, Vector2(251, 220), Vector2(126, 34), 15, ui.INK)
	language_zh = ui._button(self, "Chinese", Rect2(382, 220, 107, 34))
	language_en = ui._button(self, "English", Rect2(495, 220, 91, 34))
	language_zh.pressed.connect(func(): loc.set_language("zh_CN"))
	language_en.pressed.connect(func(): loc.set_language("en_US"))
	_segmented(language_zh, language_en)
	ui._color(self, Rect2(251, 270, 335, 1), ui.RULE)
	ui._localize(ui._label(self, Vector2(251, 281), Vector2(306, 25), 17, ui.GOLD), "UI_SETTINGS_AUDIO")
	_add_volume("master", 308)
	_add_volume("effects", 364)
	_add_volume("music", 420)
	sound_test = ui._button(self, "SoundTest", Rect2(251, 487, 306, 35), false, "")
	sound_test.pressed.connect(func(): ui.sound_preview_requested.emit())

	bindings_title = ui._label(self, Vector2(655, 159), Vector2(374, 26), 17, ui.INK)
	for i in range(loc.REMAPPABLE.size()):
		var action: String = loc.REMAPPABLE[i]
		var y := 193 + i * 34
		action_labels[action] = ui._label(self, Vector2(655, y), Vector2(175, 29), 14, ui.MUTED)
		var button: Button = ui._button(self, action, Rect2(830, y, 200, 30))
		button.add_theme_font_size_override("font_size", 14)
		button.pressed.connect(func(): _start_capture(action))
		action_buttons[action] = button
	fixed_escape = ui._label(self, Vector2(655, 537), Vector2(374, 22), 13, ui.MUTED)
	capture_hint = ui._label(self, Vector2(251, 560), Vector2(778, 32), 14, ui.GOLD, HORIZONTAL_ALIGNMENT_LEFT, true)
	reset = ui._button(self, "ResetBindings", Rect2(778, 599, 252, 41))
	reset.pressed.connect(func():
		_clear_capture()
		loc.reset_bindings())
	back = ui._button(self, "Back", Rect2(251, 599, 153, 41))
	back.pressed.connect(func(): ui.close_requested.emit())
	refresh()

func _segmented(first: Button, second: Button) -> void:
	var group := ButtonGroup.new()
	for button in [first, second]:
		button.theme_type_variation = &"TabButton"
		button.toggle_mode = true
		button.button_group = group
		button.add_theme_font_size_override("font_size", 14)

func _add_volume(channel: String, y: int) -> void:
	volume_labels[channel] = ui._label(self, Vector2(251, y), Vector2(242, 26), 16, ui.INK)
	volume_values[channel] = ui._label(self, Vector2(489, y), Vector2(68, 26), 14, ui.GOLD, HORIZONTAL_ALIGNMENT_RIGHT)
	var slider := HSlider.new()
	slider.name = channel.capitalize() + "Volume"
	slider.position = Vector2(251, y + 28)
	slider.size = Vector2(306, 23)
	slider.max_value = 1.0
	slider.step = 0.01
	add_child(slider)
	slider.value_changed.connect(func(value: float):
		volumes_dirty = true
		loc.preview_volume(channel, value)
		_update_volume_labels())
	slider.drag_ended.connect(func(changed: bool):
		if changed:
			commit())
	sliders[channel] = slider

func refresh() -> void:
	title.text = loc.text("UI_SETTINGS")
	quality_label.text = loc.text("UI_QUALITY")
	quality_low.text = loc.text("UI_QUALITY_LOW")
	quality_high.text = loc.text("UI_QUALITY_HIGH")
	quality_low.set_pressed_no_signal(not loc.high_quality)
	quality_high.set_pressed_no_signal(loc.high_quality)
	volume_labels.master.text = loc.text("UI_VOLUME_MASTER")
	volume_labels.effects.text = loc.text("UI_VOLUME_EFFECTS")
	volume_labels.music.text = loc.text("UI_VOLUME_MUSIC")
	sliders.master.set_value_no_signal(loc.master_volume)
	sliders.effects.set_value_no_signal(loc.effects_volume)
	sliders.music.set_value_no_signal(loc.music_volume)
	_update_volume_labels()
	sound_test.text = loc.text("UI_SOUND_TEST")
	language_label.text = loc.text("UI_MENU_LANGUAGE")
	language_zh.text = loc.text("UI_LANGUAGE_ZH_CN")
	language_en.text = loc.text("UI_LANGUAGE_EN_US")
	language_zh.set_pressed_no_signal(loc.locale == "zh_CN")
	language_en.set_pressed_no_signal(loc.locale == "en_US")
	bindings_title.text = loc.text("UI_CONTROLS")
	for action in loc.REMAPPABLE:
		action_labels[action].text = _action_name(action)
		action_buttons[action].text = "…" if action == capturing else loc.binding(action)
	fixed_escape.text = loc.text("UI_ESCAPE_FIXED", {"close": loc.binding("close")})
	capture_hint.text = loc.text(hint_key, hint_values) if not hint_key.is_empty() else ""
	reset.text = loc.text("UI_BIND_RESET")
	back.text = loc.text("UI_BACK")

func _update_volume_labels() -> void:
	volume_values.master.text = "%d%%" % roundi(loc.master_volume * 100.0)
	volume_values.effects.text = "%d%%" % roundi(loc.effects_volume * 100.0)
	volume_values.music.text = "%d%%" % roundi(loc.music_volume * 100.0)

func _action_name(action: String) -> String:
	return loc.text("UI_ACTION_%s" % action.to_upper())

func _start_capture(action: String) -> void:
	capturing = action
	hint_key = "UI_BIND_CAPTURE"
	hint_values = {"action": _action_name(action), "close": loc.binding("close")}
	refresh()

func _clear_capture() -> void:
	capturing = ""
	hint_key = ""
	hint_values.clear()

func capture(event: InputEvent) -> bool:
	if capturing.is_empty() or event.is_echo() or not event.is_pressed():
		return false
	if event.is_action_pressed("close"):
		_clear_capture()
	elif event is InputEventKey or event is InputEventMouseButton:
		if loc.binding_code(event).is_empty():
			hint_key = "UI_BIND_INVALID"
			hint_values = {}
		else:
			var conflict: String = loc.binding_conflict(capturing, event)
			if not conflict.is_empty():
				hint_key = "UI_BIND_CONFLICT"
				hint_values = {"action": _action_name(conflict)}
			elif loc.change_binding(capturing, event):
				_clear_capture()
	else:
		return false
	refresh()
	return true

func commit() -> void:
	if volumes_dirty:
		loc.save_volumes()
		volumes_dirty = false

func dismiss() -> void:
	commit()
	_clear_capture()
