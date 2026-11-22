extends RefCounted

const GameData = preload("res://data/game_data.gd")

static func available_equipment(excluded: Array) -> Array[String]:
	var available: Array[String] = []
	for item in GameData.UPGRADES:
		if not excluded.has(item.id):
			available.append(item.id)
	return available

static func drop_for_roll(roll: int, available: Array[String], rng: RandomNumberGenerator) -> String:
	if roll < GameData.DROP_CUTOFFS[0]:
		return ""
	if roll < GameData.DROP_CUTOFFS[1]:
		return "MUSHROOM"
	if roll < GameData.DROP_CUTOFFS[2]:
		return "WATER"
	if available.is_empty():
		return "POTION"
	# Reserve this item for the spawning enemy so kill order cannot change the loot.
	return available.pop_at(rng.randi_range(0, available.size() - 1))
