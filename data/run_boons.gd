extends RefCounted

const CARDS := {
	"EDGE": {"icon": "blade", "limit": 1, "weapon": "melee"},
	"FRACTURE": {"icon": "bolt", "limit": 1, "weapon": "ranged"},
	"REPRISAL": {"icon": "clock", "limit": 1, "floor": 4},
	"AFTERBREATH": {"icon": "step", "limit": 1},
	"WARD": {"icon": "shield", "limit": 2},
	"ECHO": {"icon": "chain", "limit": 1, "floor": 4},
	"SHARDS": {"icon": "blade", "limit": 1},
	"RECOVERY": {"icon": "blood", "limit": 1},
	"AFTERSTEP": {"icon": "step", "limit": 2},
	"HIDE": {"icon": "shield", "limit": 2, "stats": {"max_hp": 8.0}},
	"KEEN": {"icon": "blade", "limit": 2, "stats": {"physical_scale": 0.07}},
	"RUNE": {"icon": "bolt", "limit": 2, "stats": {"magic_scale": 0.07}},
	"LIGHTFOOT": {"icon": "step", "limit": 2, "stats": {"speed_scale": 0.05}},
	"SIGHT": {"icon": "chain", "limit": 2, "stats": {"critical": 0.03}},
	"TEMPO": {"icon": "clock", "limit": 2, "stats": {"interval_scale": -0.04}},
	"SURVIVOR": {"icon": "blood", "limit": 2, "stats": {"potion_heal": 4.0}},
	"NIGHTWATCH": {"icon": "shield", "limit": 2, "stats": {"max_hp": 5.0, "speed_scale": 0.02}},
	"VULNERABILITY": {"icon": "chain", "limit": 2, "stats": {"critical_multiplier": 0.08}},
}

static func levels(history: Dictionary) -> Dictionary:
	var result := {}
	for id in history.values():
		result[id] = result.get(id, 0) + 1
	return result

static func valid_history(history: Variant) -> bool:
	if not history is Dictionary:
		return false
	for floor in history:
		if not floor is int or floor < 2 or history[floor] not in CARDS:
			return false
		if floor < CARDS[history[floor]].get("floor", 2):
			return false
	var bought := levels(history)
	for id in bought:
		if bought[id] > CARDS[id].limit:
			return false
	return true

static func offer(seed: int, floor: int, owned: Array[String], history: Dictionary,
		weapons: Dictionary) -> Array[String]:
	var owned_modes := {}
	for item in owned:
		if weapons.has(item):
			owned_modes[weapons[item].range_type] = true
	var bought := levels(history)
	var mechanical: Array[String] = []
	var numerical: Array[String] = []
	for id in CARDS:
		var card: Dictionary = CARDS[id]
		if bought.get(id, 0) >= card.limit or floor < card.get("floor", 2):
			continue
		if card.has("weapon") and not owned_modes.has(card.weapon):
			continue
		var pool := numerical if card.has("stats") else mechanical
		pool.append(id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([seed, "floor_boons", floor])
	var result: Array[String] = []
	if not mechanical.is_empty():
		result.append(mechanical.pop_at(rng.randi_range(0, mechanical.size() - 1)))
	if not numerical.is_empty():
		result.append(numerical.pop_at(rng.randi_range(0, numerical.size() - 1)))
	var rest := mechanical + numerical
	while result.size() < 3 and not rest.is_empty():
		result.append(rest.pop_at(rng.randi_range(0, rest.size() - 1)))
	for index in range(result.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var card := result[index]
		result[index] = result[other]
		result[other] = card
	return result

static func benefits(bought: Dictionary) -> Dictionary:
	var result := {}
	for id in bought:
		var stats: Dictionary = CARDS[id].get("stats", {})
		for stat in stats:
			result[stat] = result.get(stat, 0.0) + stats[stat] * bought[id]
	return result
