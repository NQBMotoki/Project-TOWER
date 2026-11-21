extends Node

signal language_changed
signal bindings_changed
signal preferences_changed
signal settings_write_failed
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "zh_CN"
const REMAPPABLE := [
	"move_up", "move_left", "move_down", "move_right",
	"attack", "magic", "interact", "next", "inventory", "quick_item",
]
var settings_path := SETTINGS_PATH
var locale := DEFAULT_LOCALE
var translations: Dictionary = {}
var high_quality := true
var master_volume := 1.0
var effects_volume := 1.0
var _config := ConfigFile.new()
var _defaults: Dictionary = {}

func _ready() -> void:
	for code in ["zh_CN", "en_US"]:
		var translation: Translation = load("res://localization/game.%s.translation" % code)
		if translation:
			translations[code] = translation
			TranslationServer.add_translation(translation)
	if _config.load(settings_path) == OK:
		locale = str(_config.get_value("language", "locale", DEFAULT_LOCALE))
		high_quality = _config.get_value("video", "quality", "high") != "low"
		master_volume = _read_volume("master")
		effects_volume = _read_volume("effects")
	else:
		var system := OS.get_locale().to_lower()
		locale = "en_US" if system.begins_with("en") else DEFAULT_LOCALE
	if not translations.has(locale):
		locale = DEFAULT_LOCALE
	TranslationServer.set_locale(locale)
	for action in REMAPPABLE:
		_defaults[action] = ProjectSettings.get_setting("input/" + action).events[0]
		_install_binding(action, _defaults[action])
	for action in REMAPPABLE:
		var saved: Variant = _config.get_value("controls", action, "")
		if saved is String:
			var event := _decode_binding(saved)
			if event != null:
				_install_binding(action, event)
	# A damaged or obsolete config must not leave two gameplay actions on one input.
	for action in REMAPPABLE:
		if not binding_conflict(action, InputMap.action_get_events(action)[0]).is_empty():
			_apply_defaults()
			break

func set_language(code: String) -> void:
	if not translations.has(code):
		return
	locale = code
	TranslationServer.set_locale(locale)
	_config.set_value("language", "locale", locale)
	_save_settings()
	language_changed.emit()

func _read_volume(channel: String) -> float:
	var value: Variant = _config.get_value("audio", channel, 1.0)
	if (value is float or value is int) and is_finite(float(value)):
		return clampf(float(value), 0.0, 1.0)
	return 1.0

func set_quality(high: bool) -> void:
	high_quality = high
	_config.set_value("video", "quality", "high" if high else "low")
	_save_settings()
	preferences_changed.emit()

func preview_volume(channel: String, value: float) -> void:
	if channel == "master":
		master_volume = clampf(value, 0.0, 1.0)
	else:
		effects_volume = clampf(value, 0.0, 1.0)
	preferences_changed.emit()

func save_volumes() -> void:
	_config.set_value("audio", "master", master_volume)
	_config.set_value("audio", "effects", effects_volume)
	_save_settings()

func _save_settings() -> void:
	if _config.save(settings_path) != OK:
		settings_write_failed.emit()

func binding_conflict(action: String, event: InputEvent) -> String:
	var code := binding_code(event)
	for other in REMAPPABLE:
		if other != action and binding_code(InputMap.action_get_events(other)[0]) == code:
			return other
	return ""

func change_binding(action: String, event: InputEvent) -> bool:
	var code := binding_code(event)
	if not action in REMAPPABLE or code.is_empty() or not binding_conflict(action, event).is_empty():
		return false
	_install_binding(action, _decode_binding(code))
	_config.set_value("controls", action, code)
	_save_settings()
	bindings_changed.emit()
	return true

func reset_bindings() -> void:
	_apply_defaults()
	if _config.has_section("controls"):
		_config.erase_section("controls")
	_save_settings()
	bindings_changed.emit()

func _apply_defaults() -> void:
	for action in REMAPPABLE:
		_install_binding(action, _defaults[action])

func _install_binding(action: String, event: InputEvent) -> void:
	Input.action_release(action)
	InputMap.action_erase_events(action)
	InputMap.action_add_event(action, event)

func binding_code(event: InputEvent) -> String:
	if event is InputEventKey and event.keycode != KEY_ESCAPE and event.keycode != KEY_NONE:
		var is_combination: bool = (
			(event.alt_pressed and event.keycode != KEY_ALT) or (event.ctrl_pressed and event.keycode != KEY_CTRL)
			or (event.meta_pressed and event.keycode != KEY_META) or (event.shift_pressed and event.keycode != KEY_SHIFT)
		)
		if not is_combination:
			return "key:%d" % event.keycode
	elif event is InputEventMouseButton and event.button_index in [
		MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_XBUTTON1, MOUSE_BUTTON_XBUTTON2,
	]:
		if not (event.alt_pressed or event.ctrl_pressed or event.meta_pressed or event.shift_pressed):
			return "mouse:%d" % event.button_index
	return ""

func _decode_binding(code: String) -> InputEvent:
	var parts := code.split(":")
	if parts.size() != 2 or not parts[1].is_valid_int():
		return null
	var event: InputEvent
	match parts[0]:
		"key":
			event = InputEventKey.new()
			event.keycode = int(parts[1]) as Key
			if OS.get_keycode_string(event.keycode).is_empty():
				return null
		"mouse":
			event = InputEventMouseButton.new()
			event.button_index = int(parts[1]) as MouseButton
		_:
			return null
	return event if not binding_code(event).is_empty() else null

func text(key: String, values: Dictionary = {}) -> String:
	var result := ""
	if translations.has(locale):
		result = str(translations[locale].get_message(key))
	if result.is_empty() and translations.has(DEFAULT_LOCALE):
		push_warning("Missing translation for %s in %s; using zh_CN" % [key, locale])
		result = str(translations[DEFAULT_LOCALE].get_message(key))
	if result.is_empty():
		push_error("Missing translation in all locales: %s" % key)
		result = "文本暂不可用" if locale == DEFAULT_LOCALE else "Text unavailable"
	return result.format(values)

func binding(action: String) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "?"
	var event: InputEvent = events[0]
	if event is InputEventMouseButton:
		match event.button_index:
			MOUSE_BUTTON_LEFT: return text("UI_MOUSE_LEFT")
			MOUSE_BUTTON_RIGHT: return text("UI_MOUSE_RIGHT")
			MOUSE_BUTTON_MIDDLE: return text("UI_MOUSE_MIDDLE")
			MOUSE_BUTTON_XBUTTON1: return text("UI_MOUSE_BACK")
			MOUSE_BUTTON_XBUTTON2: return text("UI_MOUSE_FORWARD")
	return event.as_text().replace(" (Physical)", "")
