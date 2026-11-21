extends RefCounted

const GameData = preload("res://data/game_data.gd")

static func available_equipment(excluded: Array) -> Array[String]:
	var available: Array[String] = []
	for item in GameData.UPGRADES:
		if not excluded.has(item.id):
			available.append(item.id)
	return available

static func generate_choices(owned: Array, rng: RandomNumberGenerator) -> Array[String]:
	var available := available_equipment(owned)
	var choices: Array[String] = []
	while choices.size() < 3 and not available.is_empty():
		choices.append(available.pop_at(rng.randi_range(0, available.size() - 1)))
	for id in GameData.REWARD_FILLERS:
		if choices.size() < 3:
			choices.append(id)
	return choices

static func drop_for_roll(roll: int, available: Array[String], rng: RandomNumberGenerator) -> String:
	if roll < 55:
		return ""
	if roll < 75:
		return "MUSHROOM"
	if roll < 90:
		return "WATER"
	if available.is_empty():
		return "POTION"
	# Reserve this item for the spawning enemy so kill order cannot change the loot.
	return available.pop_at(rng.randi_range(0, available.size() - 1))
