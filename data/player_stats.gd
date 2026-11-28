extends RefCounted

const GameData = preload("res://data/game_data.gd")

const EditionSettings = preload("res://data/edition_settings.gd")
const Boons = preload("res://data/run_boons.gd")

const WEAPONS := EditionSettings.WEAPONS
const CORRUPTION := EditionSettings.CORRUPTION
const BASE := EditionSettings.PLAYER_BASE
const MAX_BEADS := EditionSettings.PLAYER_LIMITS.MAX_BEADS
const CRITICAL_MAX := EditionSettings.PLAYER_LIMITS.CRITICAL_MAX
const CRITICAL_MULTIPLIER := EditionSettings.PLAYER_LIMITS.CRITICAL_MULTIPLIER

static func calculate(equipped: Dictionary, corruption: Dictionary, boon_levels := {}) -> Dictionary:
	var stats := BASE.duplicate()
	stats.potion_heal = GameData.POTION_HEAL
	stats.critical_multiplier = CRITICAL_MULTIPLIER
	stats.first_guard = 0.0
	stats.low_health_attack = 0.0
	stats.focus_bonus = 0.0
	stats.aftercast_speed = 0.0
	for id in equipped.values():
		var item := GameData.upgrade(id)
		if item.is_empty():
			continue
		var value: float = item.value
		match item.type:
			"sword_damage": stats.physical += value
			"magic_damage": stats.magic += value
			"magic_damage_scale": stats.magic *= value
			"sword_cooldown": stats.physical_interval_scale *= value
			"magic_cooldown": stats.magic_interval_scale *= value
			"critical": stats.critical += value
			"lifesteal": stats.lifesteal += value
			"health": stats.max_hp += value
			"speed": stats.speed *= value
			"first_guard":
				stats.first_guard += value
				if item.slot == "armor":
					stats.max_hp += 12.0
					stats.speed *= 0.93
			"low_health_attack": stats.low_health_attack += value
			"focus_bonus":
				stats.focus_bonus += value
				stats.max_hp += 5.0
			"aftercast_speed": stats.aftercast_speed += value
		if item.id == "U18":
			stats.max_hp -= 4.0
	for stat in ["physical", "magic", "max_hp", "critical"]:
		stats[stat] += _corruption_gain(corruption, stat)
	stats.speed *= 1.0 + _corruption_gain(corruption, "speed")
	stats.critical = minf(CRITICAL_MAX, stats.critical)
	var interval_scale := 1.0 - _corruption_gain(corruption, "interval")
	stats.physical_interval_scale *= interval_scale
	stats.magic_interval_scale *= interval_scale
	var benefits := Boons.benefits(boon_levels)
	stats.max_hp += benefits.get("max_hp", 0.0)
	stats.physical *= 1.0 + benefits.get("physical_scale", 0.0)
	stats.magic *= 1.0 + benefits.get("magic_scale", 0.0)
	stats.speed *= 1.0 + benefits.get("speed_scale", 0.0)
	stats.critical = minf(CRITICAL_MAX, stats.critical + benefits.get("critical", 0.0))
	stats.physical_interval_scale *= 1.0 + benefits.get("interval_scale", 0.0)
	stats.magic_interval_scale *= 1.0 + benefits.get("interval_scale", 0.0)
	stats.potion_heal += benefits.get("potion_heal", 0.0)
	stats.critical_multiplier += benefits.get("critical_multiplier", 0.0)
	return stats

static func attack_interval(weapon: String, stats: Dictionary) -> float:
	var data: Dictionary = WEAPONS.get(weapon, {})
	if data.is_empty():
		return 0.0
	var scale := "physical_interval_scale" if data.range_type == "melee" else "magic_interval_scale"
	return maxf(data.minimum, data.interval * stats[scale])

static func _corruption_gain(corruption: Dictionary, stat: String) -> float:
	return corruption.get(stat, 0) * CORRUPTION[stat].increase
