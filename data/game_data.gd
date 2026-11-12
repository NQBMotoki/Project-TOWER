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

const ENEMIES := {
	"slime": {"hp": 22.0, "speed": 70.0, "damage": 8.0, "cooldown": 1.2},
	"goblin": {"hp": 38.0, "speed": 95.0, "damage": 12.0, "cooldown": 1.2},
	"skeleton": {"hp": 30.0, "speed": 55.0, "damage": 10.0, "cooldown": 2.6},
	"elite": {"hp": 160.0, "speed": 55.0, "damage": 12.0, "cooldown": 2.8},
}

const FLOORS := [
	[["slime", "slime"], ["slime", "goblin"]],
	[["slime", "slime", "goblin"], ["slime", "goblin", "goblin"]],
	[["goblin", "goblin", "skeleton"], ["goblin", "skeleton", "skeleton"]],
	[["slime", "goblin", "skeleton", "skeleton"], ["slime", "goblin", "goblin", "skeleton"]],
	[["elite", "slime", "goblin"]],
]

const LORE := {
	1: {"title": "LORE_F1_TITLE", "body": "LORE_F1_BODY", "position": Vector2(905, 400)},
	3: {"title": "LORE_F3_TITLE", "body": "LORE_F3_BODY", "position": Vector2(905, 400)},
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
