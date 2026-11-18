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
const ENEMIES := {
	"slime": {
		"hp": 26.0, "speed": 70.0, "damage": 8.0, "cooldown": 1.2,
		"creep_speed": 38.0, "lunge_range": 150.0, "coil_time": 0.75,
		"lunge_speed": 400.0, "lunge_time": 0.2, "recover": 0.55, "lunge_cooldown": 1.6,
	},
	"goblin": {"hp": 38.0, "speed": 95.0, "damage": 12.0, "cooldown": 1.2},
	"skeleton": {"hp": 30.0, "speed": 55.0, "damage": 10.0, "cooldown": 2.6, "telegraph": 0.55, "shots": 1},
	"archer": {
		"hp": 24.0, "speed": 62.0, "damage": 13.0, "cooldown": 2.2,
		"draw": 0.8, "shot_speed": 560.0, "band_min": 240.0, "band_max": 360.0,
		"retreat": 170.0, "backpedal": 1.15,
	},
	"elite": {
		"hp": 160.0, "speed": 55.0, "damage": 12.0, "cooldown": 2.8,
		"telegraph": 0.75, "shots": 3, "spread": 0.24,
	},
}

const FLOORS := [
	[["slime", "slime"], ["slime", "goblin"]],
	[["slime", "slime", "goblin"], ["slime", "goblin", "goblin"]],
	[["goblin", "skeleton", "archer"], ["archer", "skeleton", "skeleton"]],
	[["slime", "goblin", "skeleton", "archer"], ["archer", "goblin", "goblin", "skeleton"]],
	[["elite", "slime", "goblin"]],
]

# One record per floor. Floor 5 is read after the keeper falls, before the result screen.
const LORE := {
	1: {"title": "LORE_F1_TITLE", "body": "LORE_F1_BODY", "position": Vector2(905, 400)},
	2: {"title": "LORE_F2_TITLE", "body": "LORE_F2_BODY", "position": Vector2(300, 220)},
	3: {"title": "LORE_F3_TITLE", "body": "LORE_F3_BODY", "position": Vector2(905, 400)},
	4: {"title": "LORE_F4_TITLE", "body": "LORE_F4_BODY", "position": Vector2(1000, 480)},
	5: {"title": "LORE_F5_TITLE", "body": "LORE_F5_BODY", "position": Vector2(640, 300)},
}

const FLOOR_TIPS := {1: "TIP_F1", 2: "TIP_F2", 3: "TIP_F3", 4: "TIP_F4", 5: "TIP_F5"}

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
