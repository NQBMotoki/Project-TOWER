extends RefCounted

## All offsets are expressed in native pixels relative to the actor's grounded foot.
const ROOT := "res://assets/upgrade/"
const GripData = preload("res://data/upgrade_grips.gd")
const CELL := 64
const FOOT := Vector2(32, 56)
const COMPASS := ["s", "se", "e", "ne", "n", "nw", "w", "sw"]
const CARDINAL := ["s", "e", "n", "w"]
const BASE := ["idle", "walk", "windup", "strike", "recovery", "hurt", "dissolve"]
const COUNTS := {"idle": 2, "walk": 6, "windup": 3, "strike": 3, "recovery": 3, "hurt": 2, "dissolve": 5, "startled": 4,
	"appear": 4, "point_sword": 4, "point_staff": 4, "fade": 4,
	"assemble": 4, "phase": 4, "stance": 2, "final": 2, "gesture": 4, "defeated": 5}
const IDS := ["hero", "hero_sword", "hero_staff", "slime", "corrupted_slime", "goblin", "corrupted_goblin",
	"skeleton", "corrupted_skeleton", "archer", "corrupted_archer", "elite", "ghost", "lord", "knight"]
const ACTS := {"archer": ["melee"], "corrupted_archer": ["melee", "volley"], "corrupted_goblin": ["rush"],
	"corrupted_skeleton": ["zone"], "elite": ["volley", "sweep", "rush"], "lord": ["volley", "zone", "melee"]}
const BOSS_POSES := {"elite": ["assemble", "phase", "stance"], "lord": ["phase", "stance", "final", "gesture", "defeated"]}
const KNIGHT := ["appear", "point_sword", "point_staff", "fade"]
static var _sheets: Dictionary = {}
static var _frames: Dictionary = {}
static var _offsets: Dictionary = {}

static func _offset_table(id: String) -> Dictionary:
	if _offsets.has(id):
		return _offsets[id]
	var states: Array = KNIGHT.duplicate() if id == "knight" else BASE.duplicate()
	if id.begins_with("hero"):
		states.append("startled")
	for suffix in ACTS.get(id, []):
		for phase in ["windup", "strike", "recovery"]:
			states.append(phase + "_" + suffix)
	var table := {}
	var offset := 0
	for state: String in states:
		var count: int = COUNTS[state.get_slice("_", 0)] if not KNIGHT.has(state) else COUNTS[state]
		table[state] = Vector2i(offset, count)
		offset += count
	_offsets[id] = table
	return table

static func _span(id: String, state: String) -> Vector2i:
	var poses: Array = BOSS_POSES.get(id, [])
	var offset := 0
	for pose: String in poses:
		if pose == state:
			return Vector2i(offset, COUNTS[pose])
		offset += int(COUNTS[pose])
	var table := _offset_table(id)
	return table.get(state, table.get(state.get_slice("_", 0), Vector2i.ZERO))

static func frame_count(id: String, _direction: String, state: String) -> int:
	return _span(id, state).y if IDS.has(id) else 0

static func _direction_row(id: String, direction: String) -> int:
	if id == "knight":
		return 0
	direction = direction.to_lower()
	if id.begins_with("hero"):
		return maxi(0, COMPASS.find(direction))
	match direction:
		"se", "ne": direction = "e"
		"sw", "nw": direction = "w"
	return maxi(0, CARDINAL.find(direction))

static func _texture(path: String) -> Texture2D:
	if not _sheets.has(path) and ResourceLoader.exists(path):
		_sheets[path] = load(path)
	return _sheets.get(path)

static func frame(id: String, direction: String, state: String, index: int) -> Texture2D:
	if not IDS.has(id):
		return null
	var span := _span(id, state)
	if span.y == 0:
		return null
	var cell := Vector2i(span.x + posmod(index, span.y), _direction_row(id, direction))
	var sheet_name := id + "_poses" if state in BOSS_POSES.get(id, []) else id
	var key := "%s/%d/%d" % [sheet_name, cell.x, cell.y]
	if _frames.has(key):
		return _frames[key]
	var sheet := _texture(ROOT + "actors/" + sheet_name + ".png")
	if sheet == null:
		return null
	var texture := AtlasTexture.new()
	texture.atlas = sheet
	texture.region = Rect2(cell * CELL, Vector2i(CELL, CELL))
	texture.filter_clip = true
	_frames[key] = texture
	return texture

static func prop(id: String) -> Texture2D:
	return _texture(ROOT + "props/" + id + ".png")

static func grip(id: String, direction: String, state: String, index: int) -> Vector2:
	if not GripData.POSITIONS.has(id):
		return Vector2.ZERO
	var span := _span(id, state)
	if span.y == 0:
		return Vector2.ZERO
	var column := span.x + posmod(index, span.y)
	var packed: int = GripData.POSITIONS[id][_direction_row(id, direction)][column]
	return Vector2(packed % CELL, packed >> 6) - FOOT

static func floor_marker(floor_number: int) -> Vector2:
	# 640 × 360 artwork. Ten equally spaced rooms share the lamp socket on the right.
	return Vector2(345, 296 - 25 * (clampi(floor_number, 1, 10) - 1)) / Vector2(640, 360)
