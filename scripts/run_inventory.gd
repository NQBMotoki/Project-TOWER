class_name RunInventory
extends RefCounted

const GameData = preload("res://data/game_data.gd")
var stacks: Dictionary = {}
var owned: Array[String] = []
var equipped: Dictionary = {}
var read: Array[String] = []
var potion_on_quick_slot := false

func add(id: String) -> bool:
	if id in GameData.STACKABLE:
		stacks[id] = count(id) + 1
		return true
	if not GameData.is_item(id) or owned.has(id):
		return false
	owned.append(id)
	if id in GameData.STARTERS.values():
		equip(id)
	return true

func count(id: String) -> int:
	return stacks.get(id, 0)

func equip(id: String) -> void:
	var slot := GameData.slot_for(id)
	if owned.has(id) and not slot.is_empty():
		equipped[slot] = id

func unequip(id: String) -> void:
	var slot := GameData.slot_for(id)
	if equipped.get(slot, "") != id or id in GameData.STARTERS.values():
		return
	equipped.erase(slot)
	var starter: String = GameData.STARTERS.get(slot, "")
	if owned.has(starter):
		equip(starter)

func can_craft() -> bool:
	return count("MUSHROOM") >= 1 and count("WATER") >= 1

func craft_potion() -> bool:
	if not can_craft():
		return false
	_consume("MUSHROOM")
	_consume("WATER")
	add("POTION")
	return true

func drink(player: Node2D) -> bool:
	if count("POTION") == 0 or not player.alive or player.hp >= player.max_hp:
		return false
	_consume("POTION")
	player.heal(GameData.POTION_HEAL)
	return true

func _consume(id: String) -> void:
	if count(id) == 1:
		stacks.erase(id)
	else:
		stacks[id] -= 1

func mark_read(id: String) -> void:
	if owned.has(id) and GameData.is_book(id) and not read.has(id):
		read.append(id)

func snapshot() -> Dictionary:
	return {
		"stacks": stacks.duplicate(), "owned": owned.duplicate(), "equipped": equipped.duplicate(),
		"read": read.duplicate(), "quick_potion": potion_on_quick_slot,
	}

func restore(data: Variant) -> bool:
	if not data is Dictionary or not data.get("owned") is Array or not data.get("read") is Array:
		return false
	if not data.get("stacks") is Dictionary or not data.get("equipped") is Dictionary or not data.get("quick_potion") is bool:
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
		if not id is String or not id in unique or GameData.slot_for(id) != slot:
			return false
	for slot in GameData.STARTERS:
		if GameData.STARTERS[slot] in unique and not data.equipped.has(slot):
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
	return true
