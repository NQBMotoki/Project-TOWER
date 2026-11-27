extends Node2D

const UpgradeArt = preload("res://data/upgrade_art.gd")
const EnvironmentArt = preload("res://data/edition_environment.gd")
const FloorTopology = preload("res://data/floor_topology.gd")
const Lighting = preload("res://scripts/tower_lighting.gd")
const PALETTES := [
	Color("273547"), Color("343645"), Color("2f3952"), Color("393248"), Color("3b3032"),
	Color("323137"), Color("3a303a"), Color("302e49"), Color("37314a"), Color("392a3d"),
]
const BRAZIERS := [Vector2(279, 108), Vector2(1001, 108), Vector2(105, 360),
	Vector2(1175, 360), Vector2(279, 612), Vector2(1001, 612)]
const TILE_SIZE := Vector2(45, 38)
const STRUCTURAL_FIXTURES := {
	1: {0: "fixture_01"}, 2: {0: "fixture_02", 1: "fixture_02"},
	3: {0: "fixture_03", 1: "fixture_03"}, 4: {2: "fixture_04", 3: "fixture_04"},
	5: {0: "fixture_05_guard", 1: "fixture_05"}, 6: {0: "fixture_06", 1: "fixture_06"},
	7: {2: "fixture_07"}, 9: {2: "fixture_09", 3: "fixture_09"},
	10: {0: "fixture_10_pillar", 1: "fixture_10_pillar"},
}
const INLAYS := {
	1: ["threshold_01", Vector2(640, 168)], 2: ["drain_02", Vector2(652, 300)],
	8: ["fixture_08", Vector2(640, 258)], 10: ["fixture_10", Vector2(640, 287)],
}
const CORRUPTION_MARKS := [Vector2(374, 257), Vector2(856, 274),
	Vector2(1042, 361), Vector2(514, 493), Vector2(771, 529)]

var floor_number := 1
var layout := ArenaLayout.new()
var high_quality := true
var _tiles: Array[Dictionary] = []
var _interior := PackedVector2Array()
var _floor_uv := PackedVector2Array()
var _upgrade_uv := PackedVector2Array()
var _wall_texture: Texture2D
var _lighting: Lighting

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	var void_backdrop := ColorRect.new()
	var backdrop_rect := ArenaLayout.BOUNDS.grow(1200.0)
	void_backdrop.position = backdrop_rect.position
	void_backdrop.size = backdrop_rect.size
	void_backdrop.color = Color("0b0d14")
	void_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	void_backdrop.show_behind_parent = true
	void_backdrop.material = Lighting.unshaded()
	add_child(void_backdrop)
	_lighting = Lighting.new()
	_lighting.name = "TowerLighting"
	add_child(_lighting)
	_lighting.set_process(false)
	_interior = ArenaLayout.outline(3.0)
	_floor_uv = EnvironmentArt.repeating_uv(_interior, Vector2(310, 310))
	_upgrade_uv = EnvironmentArt.repeating_uv(_interior, Vector2(384, 288))
	_wall_texture = UpgradeArt.prop("wall")
	if _wall_texture == null:
		_wall_texture = EnvironmentArt.tile(EnvironmentArt.MASONRY)
	for row in range(16):
		for column in range(28):
			var point := ArenaLayout.BOUNDS.position + Vector2(column * 46 - row % 2 * 23 - 23, row * 38)
			var tile := Rect2(point, TILE_SIZE)
			var corners := PackedVector2Array([point, Vector2(tile.end.x, point.y), tile.end, Vector2(point.x, tile.end.y)])
			var clipped := Geometry2D.intersect_polygons(corners, _interior)
			if not clipped.is_empty() and clipped[0].size() >= 3:
				_tiles.append({"polygon": clipped[0], "tile": tile})

func setup_lighting(floor: int, room_layout: ArenaLayout) -> void:
	_lighting.configure(floor, room_layout, fire_positions(), high_quality)

func clear_lighting() -> void:
	_lighting.clear()

func set_lighting_quality(high: bool) -> void:
	high_quality = high
	_lighting.set_quality(high)

func _draw() -> void:
	var tint: Color = PALETTES[clampi(floor_number - 1, 0, PALETTES.size() - 1)]
	draw_colored_polygon(ArenaLayout.outline(-17.0), Color("141824"))
	draw_colored_polygon(ArenaLayout.outline(-10.0), tint.darkened(0.18))
	draw_colored_polygon(ArenaLayout.outline(-5.0), tint.lightened(0.15))
	draw_colored_polygon(ArenaLayout.outline(), tint.darkened(0.43))
	var floor_texture := UpgradeArt.prop("floor_%02d" % floor_number)
	if floor_texture != null:
		draw_polygon(_interior, PackedColorArray([Color.WHITE]), _upgrade_uv, floor_texture)
		draw_colored_polygon(_interior, Color(tint.r, tint.g, tint.b, 0.16))
	else:
		floor_texture = EnvironmentArt.tower_floor(floor_number)
		if floor_texture != null:
			draw_polygon(_interior, PackedColorArray([Color("9a9199")]), _floor_uv, floor_texture)
			draw_colored_polygon(_interior, Color(tint.r, tint.g, tint.b, 0.60))
		else:
			_draw_stone_tiles(tint)
	_draw_north_wall(tint)
	_draw_inlay()
	if floor_number >= 6 and floor_number <= 9:
		_draw_corrupted_stone()
	for fire: Vector2 in fire_positions():
		_draw_brazier(fire)
	for entry in layout.obstacles:
		var rect: Rect2 = entry.rect
		var fixture := _fixture_at(rect.get_center())
		if fixture != null:
			_draw_contact_shadow(rect)
			draw_texture_rect(fixture, rect, false)
		else:
			_draw_obstacle(rect, entry.kind == "pillar")

func fire_positions() -> Array:
	return BRAZIERS.slice(0, 4) if floor_number <= 2 else BRAZIERS

func _draw_north_wall(tint: Color) -> void:
	var wall_tint := tint.lerp(Color("b49a84"), 0.50)
	var wall := Rect2(270, 37, 740, 34)
	draw_rect(wall.grow(3), tint.darkened(0.56))
	if _wall_texture != null:
		draw_texture_rect(_wall_texture, wall, true, wall_tint)
	draw_line(Vector2(268, 71), Vector2(1012, 71), Color("483f40"), 3.0)

func _fixture_at(center: Vector2) -> Texture2D:
	var fixture_map: Dictionary = STRUCTURAL_FIXTURES.get(floor_number, {})
	for index: int in fixture_map:
		var anchor: Vector4i = FloorTopology.STRUCTURE[floor_number][index]
		if center.distance_squared_to(Vector2(anchor.x, anchor.y)) < 16.0 * 16.0:
			return UpgradeArt.prop(fixture_map[index])
	return null

func _draw_inlay() -> void:
	if not INLAYS.has(floor_number):
		return
	var entry: Array = INLAYS[floor_number]
	var texture := UpgradeArt.prop(entry[0])
	if texture != null:
		var point: Vector2 = entry[1]
		draw_texture_rect(texture, Rect2(point - texture.get_size() / 2, texture.get_size()), false)

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

func _draw_brazier(point: Vector2) -> void:
	var lamp := UpgradeArt.prop("lamp")
	if lamp != null:
		draw_texture_rect(lamp, Rect2(point - Vector2(24, 35), Vector2(48, 44)), false)
		return
	draw_rect(Rect2(point - Vector2(10, 5), Vector2(20, 14)), Color("312631"))
	draw_rect(Rect2(point - Vector2(8, 6), Vector2(16, 8)), Color("806255"))
	draw_rect(Rect2(point - Vector2(5, 9), Vector2(10, 11)), Color("df954d"))
	draw_rect(Rect2(point - Vector2(2, 12), Vector2(4, 9)), Color("ffd594"))

func _draw_obstacle(rect: Rect2, pillar: bool) -> void:
	_draw_contact_shadow(rect)
	# The walk collision grows by the actor radius, so paint a little outside the
	# blocking rect: otherwise the wall stops the player before it looks solid.
	var visual := rect.grow(3.0)
	draw_rect(visual, Color("23252a"))
	draw_rect(visual.grow(-2), Color("716b72") if pillar else Color("645e6a"))
	if _wall_texture != null:
		draw_texture_rect(_wall_texture, visual.grow(-2), false, Color("c2bac5"))
	var edge_light := Color(0.78, 0.70, 0.71, 0.42) if _wall_texture != null else Color("989097")
	var edge_shadow := Color(0.11, 0.10, 0.15, 0.43) if _wall_texture != null else Color("4b4552")
	draw_rect(Rect2(visual.position + Vector2(2, 2), Vector2(visual.size.x - 4, 8)), edge_light)
	draw_rect(Rect2(visual.position + Vector2(2, visual.size.y - 8), Vector2(visual.size.x - 4, 6)), edge_shadow)
	if pillar:
		draw_rect(visual.grow(-8), Color(0.60, 0.52, 0.58, 0.27) if _wall_texture != null else Color("817583"))
		draw_rect(visual.grow(-8), edge_shadow, false, 2.0)
	else:
		for offset in [0.26, 0.61, 0.85]:
			var x: float = visual.position.x + visual.size.x * offset
			draw_line(Vector2(x + 3, visual.position.y + 5), Vector2(x - 5, visual.end.y - 6), Color("473f49"), 2.0)
	if floor_number in [6, 7, 8, 9]:
		var edge := rect.position + Vector2(3, rect.size.y * 0.38)
		var stain := Color(0.27, 0.17, 0.26, 0.53 + float(floor_number - 6) * 0.05)
		for drip in range(floor_number - 4):
			var start := edge + Vector2(drip * 5, drip % 3 * 2)
			draw_rect(Rect2(start, Vector2(5, 5 + drip % 4 * 3)), stain)

func _draw_contact_shadow(rect: Rect2) -> void:
	var area := Rect2(Vector2(rect.position.x - 6.0, rect.end.y - 5.0), Vector2(rect.size.x + 12.0, 14.0))
	draw_texture_rect(Lighting.radial_texture(), area, false, Color(0.055, 0.047, 0.071, 0.71))
