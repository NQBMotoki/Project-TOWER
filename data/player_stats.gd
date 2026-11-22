extends RefCounted

const GameData = preload("res://data/game_data.gd")

const EditionSettings = preload("res://data/edition_settings.gd")

const WEAPONS := EditionSettings.WEAPONS
const CORRUPTION := EditionSettings.CORRUPTION
const BASE := EditionSettings.PLAYER_BASE
const MAX_BEADS := EditionSettings.PLAYER_LIMITS.MAX_BEADS
const CRITICAL_MAX := EditionSettings.PLAYER_LIMITS.CRITICAL_MAX
const CRITICAL_MULTIPLIER := EditionSettings.PLAYER_LIMITS.CRITICAL_MULTIPLIER

static func calculate(equipped: Dictionary, corruption: Dictionary) -> Dictionary:
	var stats := BASE.duplicate()
	for id in equipped.values():
		var item := GameData.upgrade(id)
		if item.is_empty():
			continue
		var value: float = item.value
		match item.type:
			"sword_damage": stats.physical += value
			"magic_damage": stats.magic += value
			"sword_cooldown": stats.physical_interval_scale *= value
			"magic_cooldown": stats.magic_interval_scale *= value
			"critical": stats.critical += value
			"lifesteal": stats.lifesteal += value
			"health": stats.max_hp += value
			"speed": stats.speed *= value
	for stat in ["physical", "magic", "max_hp", "critical"]:
		stats[stat] += _corruption_gain(corruption, stat)
	stats.speed *= 1.0 + _corruption_gain(corruption, "speed")
	stats.critical = minf(CRITICAL_MAX, stats.critical)
	var interval_scale := 1.0 - _corruption_gain(corruption, "interval")
	stats.physical_interval_scale *= interval_scale
	stats.magic_interval_scale *= interval_scale
	return stats

static func attack_interval(weapon: String, stats: Dictionary) -> float:
	var data: Dictionary = WEAPONS.get(weapon, {})
	if data.is_empty():
		return 0.0
	var scale := "physical_interval_scale" if data.range_type == "melee" else "magic_interval_scale"
	return maxf(data.minimum, data.interval * stats[scale])

static func _corruption_gain(corruption: Dictionary, stat: String) -> float:
	return corruption.get(stat, 0) * CORRUPTION[stat].increase
