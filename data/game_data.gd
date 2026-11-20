extends RefCounted

# Values are the single source of truth for both gameplay and item descriptions.
const UPGRADES := [
	{"id": "U01", "type": "sword_damage", "value": 6},
	{"id": "U02", "type": "sword_cooldown", "value": 0.8},
	{"id": "U03", "type": "magic_damage", "value": 12},
	{"id": "U04", "type": "magic_cooldown", "value": 0.75},
	{"id": "U05", "type": "critical", "value": 0.15},
	{"id": "U06", "type": "lifesteal", "value": 5},
	{"id": "U07", "type": "health", "value": 25},
	{"id": "U08", "type": "speed", "value": 1.15},
]

# Slime keeps its contact damage; the coil/lunge cycle adds a rhythm and a recovery window.
# The slime's lunge reach is derived in the behaviour script (speed x time + contact
# range) so the trigger and the drawn warning can never drift apart.
const ENEMIES := {
	"slime": {
		"hp": 26.0, "speed": 70.0, "damage": 8.0, "cooldown": 1.2,
		"creep_speed": 38.0, "coil_time": 0.75,
		"lunge_speed": 400.0, "lunge_time": 0.2, "recover": 0.55, "lunge_cooldown": 1.6,
	},
	"goblin": {"hp": 38.0, "speed": 95.0, "damage": 12.0, "cooldown": 1.2},
	"skeleton": {"hp": 30.0, "speed": 55.0, "damage": 10.0, "cooldown": 2.6, "telegraph": 0.55, "shots": 1, "reach": 560.0},
	"archer": {
		"hp": 24.0, "speed": 62.0, "damage": 13.0, "cooldown": 2.2,
		"draw": 0.8, "shot_speed": 560.0, "band_min": 240.0, "band_max": 360.0,
		"backpedal": 1.15, "reach": 640.0,
		"melee_range": 70.0, "melee_reach": 100.0, "melee_windup": 0.45,
		"melee_damage": 9.0, "melee_cooldown": 1.3,
	},
	"elite": {
		"hp": 160.0, "speed": 55.0, "damage": 12.0, "cooldown": 2.8,
		"telegraph": 0.75, "shots": 3, "spread": 0.24, "reach": 560.0,
	},
}

static func upgrade(id: String) -> Dictionary:
	for item in UPGRADES:
		if item.id == id:
			return item
	return {}

static func effect_value(item: Dictionary) -> int:
	match item.type:
		"sword_cooldown", "magic_cooldown": return roundi((1.0 - item.value) * 100.0)
		"critical": return roundi(item.value * 100.0)
		"speed": return roundi((item.value - 1.0) * 100.0)
		_: return roundi(item.value)
