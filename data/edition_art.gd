extends RefCounted

const ACTORS := "res://assets/edition/actors.png"
const PROPS := "res://assets/edition/props.png"
const UI_ICONS := "res://assets/edition/ui_icons.png"
const FLOOR_SCENERY := "res://assets/edition/floor_scenery.png"

const ACTOR_KEYS := [
	"slime", "goblin", "skeleton", "archer",
	"elite", "ghost", "corrupted_slime", "corrupted_goblin",
	"corrupted_skeleton", "corrupted_archer", "lord", "hero",
	"START_SWORD", "START_STAFF", "manuscript", "POTION",
]
const ACTOR_REGIONS := [
	Rect2(70, 105, 187, 153), Rect2(378, 78, 191, 187), Rect2(670, 34, 228, 239), Rect2(988, 70, 227, 195),
	Rect2(20, 338, 258, 263), Rect2(365, 357, 210, 229), Rect2(668, 379, 227, 194), Rect2(988, 381, 214, 206),
	Rect2(28, 647, 254, 269), Rect2(351, 649, 238, 257), Rect2(646, 632, 264, 284), Rect2(1002, 670, 178, 232),
	Rect2(56, 1002, 196, 206), Rect2(361, 975, 208, 242), Rect2(678, 996, 184, 215), Rect2(1036, 985, 121, 226),
]
const PROP_REGIONS := {
	"pot": Rect2(68, 82, 242, 250), "plate": Rect2(417, 103, 251, 210),
	"altar": Rect2(765, 73, 281, 264), "stairs": Rect2(1125, 73, 281, 265),
	"exit": Rect2(44, 393, 281, 281), "MUSHROOM": Rect2(426, 435, 235, 224),
	"WATER": Rect2(819, 416, 170, 257), "pearl": Rect2(1173, 459, 185, 182),
	"U02": Rect2(44, 766, 275, 262), "U04": Rect2(431, 756, 215, 265),
	"U07": Rect2(752, 750, 302, 283), "U08": Rect2(1123, 762, 274, 272),
}
const UI_REGIONS := {
	"ui_continue": Rect2(130, 132, 243, 244), "ui_new": Rect2(542, 132, 244, 244),
	"ui_settings": Rect2(966, 146, 244, 224), "ui_codex": Rect2(1369, 159, 276, 202),
	"ui_inventory": Rect2(153, 549, 236, 227), "ui_blood": Rect2(572, 549, 214, 216),
	"ui_craft": Rect2(987, 529, 212, 255), "ui_health": Rect2(1392, 552, 241, 210),
}
const FLOOR_REGIONS := {
	"floor_01": Rect2(37, 47, 311, 291), "floor_02": Rect2(386, 62, 313, 284),
	"floor_03": Rect2(754, 33, 301, 315), "floor_04": Rect2(1109, 22, 299, 326),
	"floor_05": Rect2(20, 400, 327, 303), "floor_06": Rect2(377, 381, 332, 313),
	"floor_07": Rect2(748, 414, 318, 271), "floor_08": Rect2(1096, 416, 333, 252),
	"floor_09": Rect2(26, 747, 321, 320), "floor_10": Rect2(390, 750, 306, 291),
	"floor_lamp": Rect2(784, 744, 216, 316), "floor_rubble": Rect2(1099, 784, 329, 249),
}
const ALIASES := {"U01": "START_SWORD", "U03": "START_STAFF", "U05": "U04", "U06": "START_SWORD"}

static var _textures: Dictionary = {}

static func icon(id: String) -> Texture2D:
	if id.begins_with("LORE_"):
		id = "manuscript"
	id = ALIASES.get(id, id)
	if _textures.has(id):
		return _textures[id]
	var index := ACTOR_KEYS.find(id)
	var source: Texture2D
	var rect: Rect2
	if index >= 0:
		source = load(ACTORS)
		rect = ACTOR_REGIONS[index]
	elif PROP_REGIONS.has(id):
		source = load(PROPS)
		rect = PROP_REGIONS[id]
	elif UI_REGIONS.has(id):
		source = load(UI_ICONS)
		rect = UI_REGIONS[id]
	elif FLOOR_REGIONS.has(id):
		source = load(FLOOR_SCENERY)
		rect = FLOOR_REGIONS[id]
	else:
		return null
	if source == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = source
	texture.region = rect
	texture.filter_clip = true
	_textures[id] = texture
	return texture
