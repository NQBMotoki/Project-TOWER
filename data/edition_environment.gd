extends RefCounted

const ATLAS_PATH := "res://assets/edition/environment.png"
const GROUNDS_ATLAS_PATH := "res://assets/edition/grounds.png"
const CELL_GRID := Vector2i(3, 2)
const GROUNDS := 0
const SLATE := 1
const AMBER := 2
const CORRUPTED := 3
const CEREMONIAL := 4
const MASONRY := 5
const TENT := 0
const FIRE_PIT := 1
const ROAD := 2
const TOWER_GATE := 3
const GROUNDS_REGIONS := [
	Rect2(22, 3, 548, 547),
	Rect2(708, 100, 462, 438),
	Rect2(165, 600, 304, 646),
	Rect2(654, 596, 608, 648),
]

static var _tiles: Array[Texture2D] = []
static var _grounds_props: Array[Texture2D] = []

static func tower_floor(number: int) -> Texture2D:
	if number <= 4:
		return tile(SLATE)
	if number <= 7:
		return tile(AMBER)
	if number <= 9:
		return tile(CORRUPTED)
	return tile(CEREMONIAL)

static func tile(index: int) -> Texture2D:
	if _tiles.is_empty():
		if not ResourceLoader.exists(ATLAS_PATH):
			return null
		var atlas: Texture2D = load(ATLAS_PATH)
		var source := atlas.get_image()
		var cell := source.get_size() / CELL_GRID
		var gutter := Vector2i(Vector2(cell) * 0.075)
		for row in CELL_GRID.y:
			for column in CELL_GRID.x:
				var region := Rect2i(Vector2i(column, row) * cell + gutter, cell - gutter * 2)
				_tiles.append(ImageTexture.create_from_image(source.get_region(region)))
	return _tiles[index]

static func grounds_prop(index: int) -> Texture2D:
	if _grounds_props.is_empty():
		if not ResourceLoader.exists(GROUNDS_ATLAS_PATH):
			return null
		var atlas: Texture2D = load(GROUNDS_ATLAS_PATH)
		for region in GROUNDS_REGIONS:
			var prop := AtlasTexture.new()
			prop.atlas = atlas
			prop.region = region
			prop.filter_clip = true
			_grounds_props.append(prop)
	return _grounds_props[index]

static func repeating_uv(polygon: PackedVector2Array, tile_size: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for vertex in polygon:
		result.append(vertex / tile_size)
	return result
