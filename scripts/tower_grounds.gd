extends Node2D

const EnvironmentArt = preload("res://data/edition_environment.gd")
const BOUNDS := ArenaLayout.BOUNDS
const FIRE_POSITION := Vector2(344, 393)

@export var tent_texture: Texture2D
@export var fire_pit_texture: Texture2D
@export var road_texture: Texture2D
@export var gate_texture: Texture2D

var high_quality := true
var clock := 0.0
var _ground_texture: Texture2D
var _terrain := PackedVector2Array()
var _terrain_uv := PackedVector2Array()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	_ground_texture = EnvironmentArt.tile(EnvironmentArt.GROUNDS)
	_terrain = ArenaLayout.outline()
	_terrain_uv = EnvironmentArt.repeating_uv(_terrain, Vector2(330, 330))
	if tent_texture == null:
		tent_texture = EnvironmentArt.grounds_prop(EnvironmentArt.TENT)
	if fire_pit_texture == null:
		fire_pit_texture = EnvironmentArt.grounds_prop(EnvironmentArt.FIRE_PIT)
	if road_texture == null:
		road_texture = EnvironmentArt.grounds_prop(EnvironmentArt.ROAD)
	if gate_texture == null:
		gate_texture = EnvironmentArt.grounds_prop(EnvironmentArt.TOWER_GATE)

func pickups() -> Dictionary:
	return {
		"START_SWORD": $StarterSword.position, "START_STAFF": $StarterStaff.position,
		"MUSHROOM": $Mushroom.position, "WATER": $Water.position,
		"LORE_KIT": $KitList.position, "LORE_ORDER": $GarrisonOrder.position,
	}

func _process(delta: float) -> void:
	if visible and high_quality:
		clock += delta
		queue_redraw()

func _draw() -> void:
	draw_rect(BOUNDS.grow(1200.0), Color("0a1014"))
	draw_colored_polygon(ArenaLayout.outline(-14.0), Color("1d2a29"))
	draw_colored_polygon(ArenaLayout.outline(-6.0), Color("465345"))
	draw_colored_polygon(_terrain, Color("263934"))
	if _ground_texture != null:
		draw_polygon(_terrain, PackedColorArray([Color("abae99")]), _terrain_uv, _ground_texture)
		draw_colored_polygon(_terrain, Color(0.09, 0.20, 0.14, 0.52))
	_draw_roads()
	for i in range(150):
		var p := BOUNDS.position + Vector2(12 + (i * 227) % 1130, 8 + (i * 109) % 573)
		if not ArenaLayout.contains(p, 10.0):
			continue
		draw_line(p, p + Vector2(4 + i % 7, -3), Color(0.25, 0.35, 0.30, 0.62), 1.0)
	for i in range(10):
		var p := Vector2(129 + i * 111, 570 + i % 3 * 5)
		if not ArenaLayout.contains(p, 18.0):
			continue
		draw_circle(p, 10 + i % 3, Color("25332d"))
		draw_rect(Rect2(p + Vector2(-8, -8), Vector2(13, 9)), Color("405147"))
	_draw_gate()
	_draw_camp()
	if high_quality:
		for i in range(15):
			var p := BOUNDS.position + Vector2(35 + fposmod(i * 197.0 + clock * 5.0, 1082.0),
				34 + fposmod(i * 83.0 - clock * 9.0, 524.0))
			if not ArenaLayout.contains(p, 8.0):
				continue
			draw_circle(p, 1.5, Color(0.82, 0.85, 0.55, 0.20 + 0.12 * sin(clock * 2.0 + i)))

func _draw_roads() -> void:
	if road_texture != null:
		var road_light := Color("bdaf9a")
		draw_set_transform(Vector2(466, 374), 1.37)
		draw_texture_rect(road_texture, Rect2(-53, -181, 106, 191), false, Color("a69d88"))
		draw_texture_rect(road_texture, Rect2(-53, -10, 106, 191), false, Color("a69d88"))
		draw_set_transform(Vector2.ZERO)
		draw_texture_rect(road_texture, Rect2(557, 64, 166, 306), false, road_light)
		draw_texture_rect(road_texture, Rect2(557, 350, 166, 306), false, road_light)
		return
	draw_colored_polygon(PackedVector2Array([
		Vector2(585, 64), Vector2(699, 64), Vector2(682, 305), Vector2(742, 426),
		Vector2(698, 656), Vector2(583, 656), Vector2(620, 433), Vector2(568, 312),
	]), Color("57554a"))
	draw_colored_polygon(PackedVector2Array([
		Vector2(578, 308), Vector2(634, 354), Vector2(351, 443), Vector2(235, 418), Vector2(267, 373),
	]), Color("504e40"))

func _draw_gate() -> void:
	if gate_texture != null:
		var gate: Vector2 = $Entrance.position
		draw_texture_rect(gate_texture, Rect2(gate - Vector2(105, 182), Vector2(210, 193)), false, Color("dfd3c6"))
		_draw_gate_lamps(104.0)
		return
	draw_rect(Rect2(512, 124, 256, 47), Color("383b3a"))
	for row in range(2):
		for col in range(6):
			draw_rect(Rect2(515 + col * 42, 126 + row * 21, 38, 17), Color("64645a"))
	draw_rect(Rect2(586, 124, 108, 59), Color("7e7460"))
	draw_rect(Rect2(600, 124, 80, 64), Color("171c22"))
	draw_rect(Rect2(603, 177, 74, 12), Color("48433c"))
	draw_rect(Rect2(593, 190, 94, 7), Color("635d50"))
	draw_rect(Rect2(591, 199, 98, 4), Color("77705c"))
	_draw_gate_lamps(154.0)

func _draw_gate_lamps(height: float) -> void:
	for x in [568, 712]:
		var light := Vector2(x, height)
		if high_quality:
			draw_circle(light, 31, Color(1.0, 0.72, 0.39, 0.07 + 0.02 * sin(clock * 6.0)))
			draw_circle(light, 19, Color(1.0, 0.61, 0.28, 0.09))
		draw_rect(Rect2(light - Vector2(3, 6), Vector2(6, 12)), Color("dca45e"))

func _draw_camp() -> void:
	if tent_texture != null:
		draw_texture_rect(tent_texture, Rect2($Camp.position - Vector2(116, 112), Vector2(144, 124)), false, Color("ddd0af"))
	else:
		draw_colored_polygon(PackedVector2Array([
			Vector2(214, 384), Vector2(259, 318), Vector2(313, 332), Vector2(286, 388),
		]), Color("a18e63"))
		draw_colored_polygon(PackedVector2Array([
			Vector2(259, 318), Vector2(286, 388), Vector2(313, 332),
		]), Color("72684e"))
		draw_line(Vector2(223, 392), Vector2(258, 318), Color("d2bd84"), 2.0)
	draw_rect(Rect2(353, 338, 52, 20), Color("6c5240"))
	draw_rect(Rect2(353, 337, 52, 4), Color("9a7755"))
	_draw_fire()

func _draw_fire() -> void:
	var fire := FIRE_POSITION
	if high_quality:
		draw_circle(fire, 41, Color(1.0, 0.57, 0.24, 0.11 + 0.025 * sin(clock * 8.0)))
	if fire_pit_texture != null:
		draw_texture_rect(fire_pit_texture, Rect2(fire - Vector2(28, 26), Vector2(56, 54)), false, Color("d4c5ae"))
	else:
		draw_circle(fire, 15, Color("7c7764"))
		draw_circle(fire, 10, Color("382e29"))
	var lift := roundf(sin(clock * 11.0) * 2.0 + sin(clock * 19.0)) if high_quality else 0.0
	draw_colored_polygon(PackedVector2Array([
		fire + Vector2(-8, 4), fire + Vector2(-6, -3), fire + Vector2(1, -16 + lift),
		fire + Vector2(8, -2), fire + Vector2(5, 6),
	]), Color("ef9d5f"))
	draw_colored_polygon(PackedVector2Array([
		fire + Vector2(-4, 4), fire + Vector2(1, -8 + lift), fire + Vector2(4, 1), fire + Vector2(2, 5),
	]), Color("ffd995"))
