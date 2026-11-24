class_name RunSave
extends RefCounted

const PATH := "user://tower_complete.save"
const MAGIC := 0x544F5752
const VERSION := 2
const MAX_BYTES := 1024 * 1024
const HEADER_BYTES := 40
const GameData = preload("res://data/game_data.gd")
const PlayerStats = preload("res://data/player_stats.gd")
const FloorFeatures = preload("res://scripts/floor_features.gd")
const PHASES := ["opening", "grounds", "transition", "dialogue", "combat", "safe", "ending"]

var path: String

func _init(save_path := PATH) -> void:
	path = save_path

func load_latest() -> Dictionary:
	return _read(path)

func load_backup() -> Dictionary:
	return _read(path + ".bak")

func _read(source: String) -> Dictionary:
	var file := FileAccess.open(source, FileAccess.READ)
	if file == null:
		return {"error": FileAccess.get_open_error()}
	var size := file.get_length()
	if size <= HEADER_BYTES or size > MAX_BYTES or file.get_32() != MAGIC or file.get_32() != VERSION:
		return {"error": ERR_FILE_CORRUPT}
	var digest := file.get_buffer(32)
	var bytes := file.get_buffer(size - HEADER_BYTES)
	if bytes.size() != size - HEADER_BYTES or digest != _digest(bytes):
		return {"error": ERR_FILE_CORRUPT}
	var data: Variant = bytes_to_var(bytes)
	if not data is Dictionary:
		return {"error": ERR_FILE_CORRUPT}
	return {"error": OK, "data": data}

func write(data: Dictionary, preserve_backup := false) -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	var bytes := var_to_bytes(data)
	file.store_32(MAGIC)
	file.store_32(VERSION)
	file.store_buffer(_digest(bytes))
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = _read(temp).error
	if error == OK and not preserve_backup:
		error = _rotate_backup(data.seed)
	if error == OK:
		error = DirAccess.rename_absolute(temp, path)
	if error != OK and FileAccess.file_exists(temp):
		DirAccess.remove_absolute(temp)
	return error

func _rotate_backup(seed: int) -> Error:
	var previous := load_latest()
	var backup := path + ".bak"
	if previous.error == OK and previous.data.get("seed") == seed:
		var staging := backup + ".tmp"
		var error := DirAccess.copy_absolute(path, staging)
		if error == OK:
			error = DirAccess.rename_absolute(staging, backup)
		if error != OK and FileAccess.file_exists(staging):
			DirAccess.remove_absolute(staging)
		return error
	# Keep a valid same-run backup when replacing a damaged main file.
	var previous_backup := load_backup()
	if previous_backup.error == OK and previous_backup.data.get("seed") == seed:
		return OK
	return DirAccess.remove_absolute(backup) if FileAccess.file_exists(backup) else OK

func invalidate() -> Error:
	var result := OK
	for suffix in [".bak", ".bak.tmp", ".tmp", ""]:
		var target: String = path + suffix
		if FileAccess.file_exists(target):
			var error := DirAccess.remove_absolute(target)
			if error != OK:
				result = error
	return result

func _digest(bytes: PackedByteArray) -> PackedByteArray:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes)
	return context.finish()

static func prepare_resume(data: Variant, floors: Array[FloorDefinition]) -> Dictionary:
	if not data is Dictionary or not data.get("seed") is int or not data.get("floor") is int:
		return {}
	var phase: Variant = data.get("phase")
	if phase not in PHASES:
		return {}
	var floor_index: int = data.floor - 1
	var on_grounds: bool = phase in ["opening", "grounds"]
	if (on_grounds and data.floor != 0) or (not on_grounds and (floor_index < 0 or floor_index >= floors.size())):
		return {}
	if not data.get("kills") is int or data.kills < 0 or not _nonnegative(data.get("elapsed")):
		return {}
	for key in ["ghost_seen", "pearl_available", "stair_notice_seen", "lord_introduced"]:
		if not data.get(key) is bool:
			return {}
	if not _nonnegative(data.get("transition")) or data.transition > 2.1:
		return {}
	if not data.get("layouts") is Array or data.layouts.size() != floors.size():
		return {}
	var layouts: Array[ArenaLayout] = []
	for i in range(floors.size()):
		var layout := ArenaLayout.new()
		if not layout.restore(data.layouts[i], floors[i]):
			return {}
		layouts.append(layout)
	var inventory := RunInventory.new()
	if not inventory.restore(data.get("inventory")):
		return {}
	if not on_grounds and not _owns_weapon(inventory.owned):
		return {}
	var layout := ArenaLayout.new() if on_grounds else layouts[floor_index]
	if not _valid_player(data.get("player"), layout, inventory) or not _valid_ground(data.get("ground"), layout, inventory.owned):
		return {}
	if not FloorFeatures.validate_snapshot(data.get("features"), layout, data.floor, data.seed):
		return {}
	var floor: FloorDefinition = null if on_grounds else floors[floor_index]
	if not _valid_phase(data, floor, data.floor == floors.size(), inventory):
		return {}
	return {"data": data, "inventory": inventory, "layouts": layouts}

static func _owns_weapon(owned: Array[String]) -> bool:
	for id in owned:
		if GameData.slot_for(id) == "weapon":
			return true
	return false

static func _nonnegative(value: Variant) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0.0

static func _valid_player(hero: Variant, layout: ArenaLayout, inventory: RunInventory) -> bool:
	if not hero is Dictionary or not hero.get("position") is Vector2 or not hero.get("aim") is Vector2 or not hero.get("swing_direction") is Vector2:
		return false
	if not layout.is_walkable(hero.position, ArenaLayout.PLAYER_RADIUS) or not hero.aim.is_finite() or not hero.swing_direction.is_finite():
		return false
	var hp_limit: float = PlayerStats.calculate(inventory.equipped, inventory.corruption).max_hp
	if not _nonnegative(hero.get("hp")) or hero.hp <= 0.0 or hero.hp > hp_limit:
		return false
	for key in ["invulnerability", "sword_flash"]:
		if not _nonnegative(hero.get(key)):
			return false
	if not hero.get("weapon_timers") is Dictionary:
		return false
	for id in hero.weapon_timers:
		var timer: Variant = hero.weapon_timers[id]
		if not id in PlayerStats.WEAPONS or id not in inventory.owned or not _nonnegative(timer):
			return false
		if timer > PlayerStats.attack_interval(id, PlayerStats.BASE):
			return false
	return true

static func _valid_ground(ground: Variant, layout: ArenaLayout, owned: Array[String]) -> bool:
	if not ground is Array:
		return false
	var unique := owned.duplicate()
	for entry in ground:
		if not entry is Dictionary or not entry.get("id") is String or not entry.get("position") is Vector2:
			return false
		if not GameData.is_item(entry.id) or not layout.is_walkable(entry.position, 0.0):
			return false
		if not entry.id in GameData.STACKABLE:
			if unique.has(entry.id):
				return false
			unique.append(entry.id)
	return true

static func _valid_phase(data: Dictionary, floor: FloorDefinition, top_floor: bool, inventory: RunInventory) -> bool:
	if data.phase in ["opening", "transition", "ending"] and data.transition <= 0.0:
		return false
	if data.phase in ["dialogue", "ending"] and not top_floor:
		return false
	if data.lord_introduced != (top_floor and data.phase in ["combat", "safe", "ending"]):
		return false
	if (data.pearl_available or data.stair_notice_seen) and (top_floor or data.phase != "safe"):
		return false
	var beads_earned := inventory.blood_beads
	for level in inventory.corruption.values():
		beads_earned += level
	var altar_count: int = maxi(0, data.floor - 1)
	if data.phase == "safe" and not data.pearl_available and not top_floor:
		altar_count += 1
	if beads_earned > altar_count:
		return false
	if not data.get("next_wave") is int or not data.get("wave_drops") is Array:
		return false
	var next_wave: int = data.next_wave
	var drops: Array = data.wave_drops
	if data.phase != "combat":
		return next_wave == 0 and drops.is_empty()
	if next_wave < 0 or next_wave >= floor.waves.size():
		return false
	if not drops.is_empty() and drops.size() != floor.waves[next_wave].size():
		return false
	var reserved: Array = inventory.owned.duplicate()
	for entry in data.ground:
		reserved.append(entry.id)
	for id in drops:
		if not id is String:
			return false
		if id.is_empty() or id in GameData.STACKABLE:
			continue
		if GameData.upgrade(id).is_empty() or id in reserved:
			return false
		reserved.append(id)
	return true
