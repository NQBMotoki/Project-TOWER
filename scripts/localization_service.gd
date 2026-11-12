extends Node

signal language_changed
const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_LOCALE := "zh_CN"
var settings_path := SETTINGS_PATH
var locale := DEFAULT_LOCALE
var translations: Dictionary = {}

func _ready() -> void:
	for code in ["zh_CN", "en_US"]:
		var translation: Translation = load("res://localization/game.%s.translation" % code)
		if translation:
			translations[code] = translation
			TranslationServer.add_translation(translation)
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		locale = str(config.get_value("language", "locale", DEFAULT_LOCALE))
	else:
		var system := OS.get_locale().to_lower()
		locale = "en_US" if system.begins_with("en") else DEFAULT_LOCALE
	if not translations.has(locale):
		locale = DEFAULT_LOCALE
	TranslationServer.set_locale(locale)

func set_language(code: String) -> void:
	if not translations.has(code):
		return
	locale = code
	TranslationServer.set_locale(locale)
	var config := ConfigFile.new()
	config.load(settings_path)
	config.set_value("language", "locale", locale)
	var error := config.save(settings_path)
	if error != OK:
		push_warning("Could not save language setting: %s" % error)
	language_changed.emit()

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
	return event.as_text().replace(" (Physical)", "")
