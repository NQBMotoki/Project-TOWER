extends RefCounted

const OPENING_TIME := 2.1
const STAIRS_TIME := 3.5
const CUTAWAY_TIME := 4.2
const ENDING_TIME := 5.55
const KNIGHT_TIME := 5.25
const MAX_TIME := ENDING_TIME
const STAIR_CLIMB_END := 0.88
const TOUCH_TIME := 0.42
const SKY_TIME := 1.45
const CREDITS_TIME := 4.45
const LORD_DIALOGUE: Array[String] = ["DIALOGUE_F10_1", "DIALOGUE_F10_INTRO_02", "DIALOGUE_F10_3", "DIALOGUE_F10_4"]
const LORD_DEFEATED: Array[String] = ["DIALOGUE_F10_DEFEAT_01", "DIALOGUE_F10_DEFEAT_02", "DIALOGUE_F10_DEFEAT_03"]

static func choice_time(destination: int) -> float:
	return 1.50 if destination == 2 else 0.62

static func arrival_time(destination: int) -> float:
	return choice_time(destination) + 0.72

static func duration(phase: String, floor_number: int, floor_count: int) -> float:
	match phase:
		"opening":
			return OPENING_TIME
		"transition":
			return CUTAWAY_TIME if floor_number in [1, floor_count] else STAIRS_TIME
		"ending":
			return ENDING_TIME
	return 0.0
