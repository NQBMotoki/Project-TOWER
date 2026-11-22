class_name RunCodex
extends RefCounted

const GameData = preload("res://data/game_data.gd")
const PATH := "user://tower_codex.cfg"

var path: String
var items: Array[String] = []
var enemies: Array[String] = []
var read: Array[String] = []
var dirty := false

func _init(storage_path := PATH) -> void:
	path = storage_path

func load_progress() -> Error:
	var stored := ConfigFile.new()
	var error := stored.load(path)
	if error == ERR_FILE_NOT_FOUND:
		return OK
	if error != OK:
		return error
	items = _known_ids(stored.get_value("discoveries", "items", []), GameData.is_item)
	enemies = _known_ids(stored.get_value("discoveries", "enemies", []), func(id: String) -> bool: return id in GameData.ENEMIES)
	read = _known_ids(stored.get_value("discoveries", "read", []), _book_discovered)
	dirty = false
	return OK

func discover_item(id: String) -> Error:
	if GameData.is_item(id) and id not in items:
		items.append(id)
		dirty = true
	return save_progress()

func discover_enemy(id: String) -> Error:
	if id in GameData.ENEMIES and id not in enemies:
		enemies.append(id)
		dirty = true
	return save_progress()

func mark_read(id: String) -> Error:
	if _book_discovered(id) and id not in read:
		read.append(id)
		dirty = true
	return save_progress()

func save_progress() -> Error:
	if not dirty:
		return OK
	var stored := ConfigFile.new()
	stored.set_value("discoveries", "items", items)
	stored.set_value("discoveries", "enemies", enemies)
	stored.set_value("discoveries", "read", read)
	var staging := path + ".tmp"
	var error := stored.save(staging)
	if error == OK:
		error = DirAccess.rename_absolute(staging, path)
	if error == OK:
		dirty = false
	elif FileAccess.file_exists(staging):
		DirAccess.remove_absolute(staging)
	return error

func _book_discovered(id: String) -> bool:
	return GameData.is_book(id) and id in items

func _known_ids(value: Variant, is_known: Callable) -> Array[String]:
	var ids: Array[String] = []
	if value is Array:
		for id in value:
			if id is String and id not in ids and is_known.call(id):
				ids.append(id)
	return ids
