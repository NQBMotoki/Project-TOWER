extends Node2D

const EnvironmentArt = preload("res://data/edition_environment.gd")
const EditionArt = preload("res://data/edition_art.gd")
const FloorTopology = preload("res://data/floor_topology.gd")
const PALETTES := [
	Color("273547"), Color("343645"), Color("2f3952"), Color("393248"), Color("3b3032"),
	Color("323137"), Color("3a303a"), Color("302e49"), Color("37314a"), Color("392a3d"),
]
const BRAZIERS := [Vector2(279, 108), Vector2(1001, 108), Vector2(105, 360),
	Vector2(1175, 360), Vector2(279, 612), Vector2(1001, 612)]
const TILE_SIZE := Vector2(45, 38)
const CORRUPTION_MARKS := [Vector2(374, 257), Vector2(856, 274),
	Vector2(1042, 361), Vector2(514, 493), Vector2(771, 529)]

var floor_number := 1
var layout := ArenaLayout.new()
var high_quality := true
var clock := 0.0
var _tiles: Array[Dictionary] = []
var _interior := PackedVector2Array()
var _floor_uv := PackedVector2Array()
var _wall_texture: Texture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_interior = ArenaLayout.outline(3.0)
	_floor_uv = EnvironmentArt.repeating_uv(_interior, Vector2(310, 310))
	_wall_texture = EnvironmentArt.tile(EnvironmentArt.MASONRY)
	for row in range(16):
		for column in range(28):
			var point := ArenaLayout.BOUNDS.position + Vector2(column * 46 - row % 2 * 23 - 23, row * 38)
			var tile := Rect2(point, TILE_SIZE)
			var corners := PackedVector2Array([point, Vector2(tile.end.x, point.y), tile.end, Vector2(point.x, tile.end.y)])
			var clipped := Geometry2D.intersect_polygons(corners, _interior)
			if not clipped.is_empty() and clipped[0].size() >= 3:
				_tiles.append({"polygon": clipped[0], "tile": tile})

func _process(delta: float) -> void:
	if visible and high_quality:
		clock += delta
		queue_redraw()

func _draw() -> void:
	var tint: Color = PALETTES[clampi(floor_number - 1, 0, PALETTES.size() - 1)]
	draw_rect(ArenaLayout.BOUNDS.grow(1200.0), Color("0b0d14"))
	draw_colored_polygon(ArenaLayout.outline(-17.0), Color("141824"))
	draw_colored_polygon(ArenaLayout.outline(-10.0), tint.darkened(0.18))
	draw_colored_polygon(ArenaLayout.outline(-5.0), tint.lightened(0.15))
	draw_colored_polygon(ArenaLayout.outline(), tint.darkened(0.43))
	var floor_texture := EnvironmentArt.tower_floor(floor_number)
	if floor_texture != null:
		draw_polygon(_interior, PackedColorArray([Color("9a9199")]), _floor_uv, floor_texture)
		draw_colored_polygon(_interior, Color(tint.r, tint.g, tint.b, 0.60))
	else:
		_draw_stone_tiles(tint)
	_draw_foreshadowing()
	for light in BRAZIERS:
		_draw_brazier(light)
	for entry in layout.obstacles:
		_draw_obstacle(entry.rect, entry.kind == "pillar")
	_draw_scenery()

func _draw_scenery() -> void:
	if floor_number < 1 or floor_number > FloorTopology.VIGNETTES.size():
		return
	var texture := EditionArt.icon("floor_%02d" % floor_number)
	if texture == null:
		return
	var site: Vector3i = FloorTopology.VIGNETTES[floor_number - 1]
	var anchor := Vector2(site.x, site.y)
	var width := float(site.z)
	var tint := Color("c5b9ae")
	var flat := floor_number in FloorTopology.FLAT_VIGNETTES
	if flat:
		tint = Color(0.73, 0.66, 0.69, 0.60)
	else:
		for obstacle in layout.obstacles:
			var rect: Rect2 = obstacle.rect
			if rect.get_center().distance_squared_to(anchor) < 20.0 * 20.0:
				anchor = Vector2(rect.get_center().x, rect.end.y - 5.0)
				break
	var height := width * float(texture.get_height()) / float(texture.get_width())
	var baseline := height * 0.5 if flat else height
	draw_texture_rect(texture, Rect2(anchor - Vector2(width * 0.5, baseline), Vector2(width, height)), false, tint)
	_draw_scenery_details(anchor, floor_number % 2 == 0)

func _draw_scenery_details(anchor: Vector2, lamp_on_right: bool) -> void:
	var direction := 1.0 if lamp_on_right else -1.0
	var lamp := _clear_decal_position(anchor + Vector2(direction * 62.0, -16.0), 16.0)
	var lamp_texture := EditionArt.icon("floor_lamp")
	if lamp_texture != null and layout.is_walkable(lamp, 13.0):
		if high_quality:
			draw_circle(lamp - Vector2(0, 12), 27.0, Color(0.82, 0.58, 0.32, 0.07))
		draw_texture_rect(lamp_texture, Rect2(lamp - Vector2(11, 26), Vector2(22, 30)), false, Color("baaa9b"))
	var rubble_texture := EditionArt.icon("floor_rubble")
	if rubble_texture == null:
		return
	for offset in [Vector2(-direction * 52.0, 23.0), Vector2(direction * 35.0, 63.0)]:
		var debris: Vector2 = anchor + offset
		if layout.is_walkable(debris, 13.0):
			draw_texture_rect(rubble_texture, Rect2(debris - Vector2(19, 13), Vector2(38, 26)), false, Color("9a939d"))

func _draw_stone_tiles(tint: Color) -> void:
	for index in _tiles.size():
		var stone := _tiles[index]
		var tile: Rect2 = stone.tile
		var shade := tint.lightened(float((index * 23 + floor_number) % 9) * 0.006)
		draw_colored_polygon(stone.polygon, shade)
		if ArenaLayout.contains(tile.position, 4.0) and ArenaLayout.contains(Vector2(tile.end.x, tile.position.y), 4.0):
			draw_rect(Rect2(tile.position, Vector2(tile.size.x, 1)), shade.lightened(0.06))
		if index % 17 == 0 and ArenaLayout.contains(tile.get_center(), 15.0):
			draw_line(tile.position + Vector2(16, 9), tile.position + Vector2(28, 11), shade.darkened(0.20))

func _draw_foreshadowing() -> void:
	match floor_number:
		5:
			_draw_elite_chamber()
		6, 7, 8, 9:
			_draw_corrupted_stone()
		10:
			_draw_royal_approach()

func _draw_elite_chamber() -> void:
	# Two abandoned guard posts bracket the approach without obstructing the arena.
	for post in [Vector2(516, 289), Vector2(764, 289)]:
		draw_rect(Rect2(post - Vector2(50, 5), Vector2(100, 11)), Color(0.42, 0.31, 0.27, 0.34))
		draw_rect(Rect2(post - Vector2(19, 12), Vector2(38, 21)), Color("4d4140"))
		var lantern: Vector2 = post - Vector2(0, 9)
		draw_circle(lantern, 32.0, Color(0.67, 0.43, 0.19, 0.14))
		draw_rect(Rect2(lantern - Vector2(3, 6), Vector2(6, 9)), Color("be9662"))
	var shield := Vector2(475, 313)
	draw_colored_polygon(PackedVector2Array([shield, shield + Vector2(34, 0), shield + Vector2(32, 16),
		shield + Vector2(19, 27), shield + Vector2(4, 18)]), Color("5b5352"))
	draw_polyline(PackedVector2Array([shield + Vector2(23, 0), shield + Vector2(17, 9),
		shield + Vector2(25, 11), shield + Vector2(14, 24)]), Color("302935"), 2.0)
	var pennant := Vector2(793, 312)
	draw_line(pennant + Vector2(-5, -1), pennant + Vector2(42, 8), Color("675745"), 3.0)
	draw_colored_polygon(PackedVector2Array([pennant, pennant + Vector2(31, 6), pennant + Vector2(22, 23),
		pennant + Vector2(13, 14), pennant + Vector2(9, 22), pennant + Vector2(-5, 14)]), Color("61464b"))

func _draw_corrupted_stone() -> void:
	var severity := floor_number - 5
	var stain := Color(0.31, 0.20, 0.29, 0.24 + severity * 0.045)
	for index in range(severity + 1):
		var mark: Vector2 = CORRUPTION_MARKS[index]
		var skew := Vector2(12 * index, -6 * index)
		draw_colored_polygon(PackedVector2Array([mark, mark + Vector2(25, -9), mark + Vector2(38, 5),
			mark + Vector2(81, 10) + skew, mark + Vector2(56, 20), mark + Vector2(12, 23)]), stain)
	if severity >= 2:
		var scratch := Vector2(382, 396)
		for index in range(3):
			var offset := Vector2(-index * 10, index * 9)
			draw_polyline(PackedVector2Array([scratch + offset, scratch + offset + Vector2(48, 12),
				scratch + offset + Vector2(68, 23)]), Color(0.61, 0.52, 0.54, 0.34), 2.0)
	if severity >= 3:
		var rune := _clear_decal_position(Vector2(746, 216), 40.0)
		var chalk := Color(0.67, 0.61, 0.65, 0.32)
		draw_arc(rune, 38.0, 0.5, 3.6, 18, chalk, 2.0)
		draw_arc(rune, 34.0, 4.4, 5.4, 10, chalk, 2.0)
		draw_polyline(PackedVector2Array([rune + Vector2(-12, 16), rune + Vector2(2, -17),
			rune + Vector2(14, 14)]), chalk, 2.0)
	if severity >= 4:
		var rest := _clear_decal_position(Vector2(982, 463), 35.0)
		for offset in [Vector2(32, 1), Vector2(23, 19), Vector2(-8, 15)]:
			var start: Vector2 = rest + offset
			var tip: Vector2 = start + Vector2(23, -7)
			draw_line(start, tip, Color("736365"), 2.0)
			draw_line(tip, tip + Vector2(-5, -4), Color("928481"), 2.0)

func _clear_decal_position(preferred: Vector2, radius: float) -> Vector2:
	for offset in [Vector2.ZERO, Vector2(0, -59), Vector2(63, 0), Vector2(0, 59),
			Vector2(-63, 0), Vector2(-63, -59), Vector2(63, 59)]:
		var point: Vector2 = preferred + offset
		if layout.is_walkable(point, radius):
			return point
	return preferred

func _draw_royal_approach() -> void:
	var axis := ArenaLayout.EXIT_POSITION.x
	for width in [178.0, 130.0, 82.0]:
		var start := Vector2(axis, 78)
		draw_colored_polygon(PackedVector2Array([start - Vector2(width * 0.21, 0), start + Vector2(width * 0.21, 0),
			start + Vector2(width * 0.5, 430), start + Vector2(-width * 0.5, 430)]), Color(0.77, 0.68, 0.62, 0.048))
	if EditionArt.icon("floor_10") != null:
		return
	var seal := Vector2(axis, 287)
	var brass := Color(0.61, 0.51, 0.45, 0.52)
	draw_arc(seal, 53.0, 0.36, 4.1, 36, brass, 3.0)
	draw_arc(seal, 53.0, 4.4, 5.9, 14, brass, 3.0)
	draw_polyline(PackedVector2Array([seal + Vector2(-21, 8), seal + Vector2(-24, -17),
		seal + Vector2(-8, -4), seal + Vector2(1, -21), seal + Vector2(10, -11)]), brass, 3.0)
	draw_polyline(PackedVector2Array([seal + Vector2(22, 8), seal + Vector2(26, -15),
		seal + Vector2(15, -7)]), brass, 3.0)
	draw_polyline(PackedVector2Array([seal + Vector2(-50, -23), seal + Vector2(-24, -10),
		seal + Vector2(-12, 2), seal + Vector2(18, 5), seal + Vector2(52, 19)]), Color("271f30"), 3.0)

func _draw_brazier(point: Vector2) -> void:
	if high_quality:
		var glow := 0.045 + sin(clock * 5.0 + point.x) * 0.013
		for radius in [66.0, 44.0, 27.0]:
			draw_circle(point, radius, Color(0.92, 0.58, 0.32, glow))
	draw_rect(Rect2(point - Vector2(10, 5), Vector2(20, 14)), Color("312631"))
	draw_rect(Rect2(point - Vector2(8, 6), Vector2(16, 8)), Color("806255"))
	draw_rect(Rect2(point - Vector2(5, 9), Vector2(10, 11)), Color("df954d"))
	draw_rect(Rect2(point - Vector2(2, 12), Vector2(4, 9)), Color("ffd594"))

func _draw_obstacle(rect: Rect2, pillar: bool) -> void:
	draw_rect(Rect2(rect.position + Vector2(4, 6), rect.size), Color(0.08, 0.07, 0.09, 0.56))
	draw_rect(rect, Color("23252a"))
	draw_rect(rect.grow(-2), Color("716b72") if pillar else Color("645e6a"))
	if _wall_texture != null:
		draw_texture_rect(_wall_texture, rect.grow(-2), false, Color("c2bac5"))
	var edge_light := Color(0.78, 0.70, 0.71, 0.42) if _wall_texture != null else Color("989097")
	var edge_shadow := Color(0.11, 0.10, 0.15, 0.43) if _wall_texture != null else Color("4b4552")
	draw_rect(Rect2(rect.position + Vector2(2, 2), Vector2(rect.size.x - 4, 8)), edge_light)
	draw_rect(Rect2(rect.position + Vector2(2, rect.size.y - 8), Vector2(rect.size.x - 4, 6)), edge_shadow)
	if pillar:
		draw_rect(rect.grow(-8), Color(0.60, 0.52, 0.58, 0.27) if _wall_texture != null else Color("817583"))
		draw_rect(rect.grow(-8), edge_shadow, false, 2.0)
	else:
		for offset in [0.26, 0.61, 0.85]:
			var x: float = rect.position.x + rect.size.x * offset
			draw_line(Vector2(x + 3, rect.position.y + 5), Vector2(x - 5, rect.end.y - 6), Color("473f49"), 2.0)
	if floor_number in [6, 7, 8, 9]:
		var edge := rect.position + Vector2(3, rect.size.y * 0.38)
		var stain := Color(0.27, 0.17, 0.26, 0.53 + float(floor_number - 6) * 0.05)
		for drip in range(floor_number - 4):
			var start := edge + Vector2(drip * 5, drip % 3 * 2)
			draw_rect(Rect2(start, Vector2(5, 5 + drip % 4 * 3)), stain)
