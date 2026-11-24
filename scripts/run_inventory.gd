class_name RunInventory
extends RefCounted

const GameData = preload("res://data/game_data.gd")
const PlayerStats = preload("res://data/player_stats.gd")
const WEAPON_SLOT := "weapon"
const POTION_RECIPE := GameData.POTION_RECIPE

var stacks: Dictionary = {}
var owned: Array[String] = []
var equipped: Dictionary = {}
var read: Array[String] = []
var potion_on_quick_slot := false
var blood_beads := 0
var corruption: Dictionary = {}

func add(id: String) -> bool:
	if id in GameData.STACKABLE:
		stacks[id] = count(id) + 1
		return true
	if not GameData.is_item(id) or owned.has(id):
		return false
	owned.append(id)
	if not has_weapon() and id in PlayerStats.WEAPONS:
		equip(id)
	return true

func count(id: String) -> int:
	return stacks.get(id, 0)

func current_weapon() -> String:
	return equipped.get(WEAPON_SLOT, "")

func has_weapon() -> bool:
	return not current_weapon().is_empty()

func equip(id: String) -> bool:
	var slot := GameData.slot_for(id)
	if not owned.has(id) or slot.is_empty() or equipped.get(slot, "") == id:
		return false
	equipped[slot] = id
	return true

func unequip(id: String) -> bool:
	var slot := GameData.slot_for(id)
	if slot.is_empty() or equipped.get(slot, "") != id:
		return false
	equipped.erase(slot)
	return true

func spent_beads() -> int:
	var spent := 0
	for level in corruption.values():
		spent += level
	return spent

func absorb_blood_bead() -> bool:
	if blood_beads + spent_beads() >= PlayerStats.MAX_BEADS:
		return false
	blood_beads += 1
	return true

func can_enhance(dimension: String) -> bool:
	return blood_beads > 0 and dimension in PlayerStats.CORRUPTION and corruption.get(dimension, 0) < PlayerStats.CORRUPTION[dimension].limit

func enhance(dimension: String) -> bool:
	if not can_enhance(dimension):
		return false
	blood_beads -= 1
	corruption[dimension] = corruption.get(dimension, 0) + 1
	return true

func can_craft() -> bool:
	for id in POTION_RECIPE:
		if count(id) < POTION_RECIPE[id]:
			return false
	return true

func craft_potion() -> bool:
	if not can_craft():
		return false
	for id in POTION_RECIPE:
		_consume(id, POTION_RECIPE[id])
	add("POTION")
	return true

func drink(player: Node2D) -> bool:
	if count("POTION") == 0 or not player.alive or player.hp >= player.max_hp:
		return false
	_consume("POTION", 1)
	player.heal(GameData.POTION_HEAL)
	return true

func _consume(id: String, amount: int) -> void:
	if count(id) == amount:
		stacks.erase(id)
	else:
		stacks[id] -= amount

func mark_read(id: String) -> void:
	if owned.has(id) and GameData.is_book(id) and not read.has(id):
		read.append(id)

func snapshot() -> Dictionary:
	return {
		"stacks": stacks.duplicate(), "owned": owned.duplicate(), "equipped": equipped.duplicate(),
		"read": read.duplicate(), "quick_potion": potion_on_quick_slot,
		"blood_beads": blood_beads, "corruption": corruption.duplicate(),
	}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("owned") is Array or not data.get("read") is Array:
		return false
	if not data.get("stacks") is Dictionary or not data.get("equipped") is Dictionary or not data.get("quick_potion") is bool:
		return false
	if not data.get("blood_beads") is int or data.blood_beads < 0 or not data.get("corruption") is Dictionary:
		return false
	var used_beads: int = data.blood_beads
	for dimension in data.corruption:
		var level: Variant = data.corruption[dimension]
		if dimension not in PlayerStats.CORRUPTION or not level is int or level < 1 or level > PlayerStats.CORRUPTION[dimension].limit:
			return false
		used_beads += level
	if used_beads > PlayerStats.MAX_BEADS:
		return false
	var unique := []
	for id in data.owned:
		if not id is String or not GameData.is_item(id) or id in GameData.STACKABLE or id in unique:
			return false
		unique.append(id)
	for id in data.stacks:
		if not id in GameData.STACKABLE or not data.stacks[id] is int or data.stacks[id] <= 0:
			return false
	for slot in data.equipped:
		var id: Variant = data.equipped[slot]
		if not id is String or not id in unique or GameData.slot_for(id) != slot or slot == "":
			return false
	var books_read := []
	for id in data.read:
		if not id in unique or not GameData.is_book(id) or id in books_read:
			return false
		books_read.append(id)
	owned.assign(unique)
	read.assign(books_read)
	stacks = data.stacks.duplicate()
	equipped = data.equipped.duplicate()
	potion_on_quick_slot = data.quick_potion
	blood_beads = data.blood_beads
	corruption = data.corruption.duplicate()
	return true
