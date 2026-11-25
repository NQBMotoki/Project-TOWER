extends RefCounted

const GameData = preload("res://data/game_data.gd")

const LATE_RELICS := ["U10", "U12", "U16", "U17", "U20"]
const MID_RELICS := ["U13", "U14", "U18"]

static func available_equipment(excluded: Array, floor := 10) -> Array[String]:
	var available: Array[String] = []
	for item in GameData.UPGRADES:
		if excluded.has(item.id) or (floor < 5 and item.id in LATE_RELICS) or (floor < 3 and item.id in MID_RELICS):
			continue
		available.append(item.id)
	return available

static func drop_for_roll(roll: int, available: Array[String], rng: RandomNumberGenerator, style := "") -> String:
	if roll < GameData.DROP_CUTOFFS[0]:
		return ""
	if roll < GameData.DROP_CUTOFFS[1]:
		return "MUSHROOM"
	if roll < GameData.DROP_CUTOFFS[2]:
		return "WATER"
	if available.is_empty():
		return "POTION"
	# Reserve this item for the spawning enemy so kill order cannot change the loot.
	for index in range(available.size()):
		var id := available[index]
		var weapon: Dictionary = GameData.EditionSettings.WEAPONS.get(id, {})
		if not weapon.is_empty() and weapon.range_type == style and rng.randf() < 0.13:
			return available.pop_at(index)
	return available.pop_at(rng.randi_range(0, available.size() - 1))
