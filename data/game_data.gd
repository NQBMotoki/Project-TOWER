extends RefCounted

const EditionSettings = preload("res://data/edition_settings.gd")
const UPGRADES := EditionSettings.ITEMS
const SLOTS := ["weapon", "gloves", "accessory", "armor", "shoes"]
const STARTERS := {"sword": "START_SWORD", "magic": "START_STAFF"}
const STACKABLE := ["MUSHROOM", "WATER", "POTION"]
const BOOKS := ["LORE_KIT", "LORE_ORDER", "LORE_F1", "LORE_F2", "LORE_PRAYER",
	"LORE_F3", "LORE_F4", "LORE_RESEARCH", "LORE_F5", "LORE_CAMP",
	"LORE_ROSTER", "LORE_RETREAT", "LORE_TRIAL", "LORE_LAST_REPORT"]
const POTION_HEAL := EditionSettings.LOOT.POTION_HEAL

const ENEMIES = preload("res://data/complete_enemies.gd").ENEMIES
const DROP_CUTOFFS := EditionSettings.LOOT.DROP_CUTOFFS
const POTION_RECIPE := EditionSettings.RECIPE

static func upgrade(id: String) -> Dictionary:
	for item in UPGRADES:
		if item.id == id:
			return item
	return {}

static func slot_for(id: String) -> String:
	if id in STARTERS.values():
		return "weapon"
	return upgrade(id).get("slot", "")

static func is_book(id: String) -> bool:
	return id in BOOKS

static func is_item(id: String) -> bool:
	return id in STACKABLE or is_book(id) or not slot_for(id).is_empty()

static func name_key(id: String) -> String:
	return "%s_TITLE" % id if is_book(id) else "ITEM_%s_NAME" % id

static func description_key(id: String) -> String:
	return "%s_DESC" % id if is_book(id) else "ITEM_%s_DESC" % id

static func effect_value(item: Dictionary) -> int:
	match item.type:
		"sword_cooldown", "magic_cooldown": return roundi((1.0 - item.value) * 100.0)
		"critical": return roundi(item.value * 100.0)
		"speed": return roundi((item.value - 1.0) * 100.0)
		_: return roundi(item.value)
