extends RefCounted

const GameData = preload("res://data/game_data.gd")

static func generate_choices(count: int = 3) -> Array:
	var choices := GameData.UPGRADES.duplicate()
	choices.shuffle()
	return choices.slice(0, mini(count, choices.size()))
