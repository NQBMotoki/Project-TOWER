extends Node2D

signal drop_requested(id: String, position: Vector2)
signal sound_requested(kind: String, position: Vector2)

const WorldData = preload("res://data/complete_world.gd")
const Pot = preload("res://scripts/breakable_pot.gd")
const ProjectileScene = preload("res://scenes/combat/projectile.tscn")
const UpgradeArt = preload("res://data/upgrade_art.gd")
const AltarVisual = preload("res://scripts/altar_visual.gd")
const SummitCrystal = preload("res://scripts/summit_crystal.gd")
const Lighting = preload("res://scripts/tower_lighting.gd")
const GATE_RECT := Rect2(-96, -98, 192, 128)
const EditionArt = preload("res://data/edition_art.gd")
const GROUND_POINTS := [
	Vector2(640, 500), Vector2(640, 205), Vector2(310, 383), Vector2(485, 225),
	Vector2(800, 225), Vector2(240, 446), Vector2(395, 420), Vector2(322, 445),
	Vector2(895, 350),
]

@export var pot_texture: Texture2D
@export var plate_texture: Texture2D
@export var altar_texture: Texture2D
@export var stairs_texture: Texture2D
@export var pearl_texture: Texture2D

var enabled := false:
	set(value):
		enabled = value
		process_mode = Node.PROCESS_MODE_INHERIT if enabled else Node.PROCESS_MODE_DISABLED
var floor_number := -1
var player: Node2D
var layout: ArenaLayout
var cleared := false
var pearl_available := false
var pots: Array[Dictionary] = []
var plates: Array[Dictionary] = []
var arrows: Array[Node2D] = []
var _altar: AltarVisual
var _crystal: SummitCrystal
var _warnings: Node2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if pot_texture == null:
		pot_texture = UpgradeArt.prop("pot")
	if pot_texture == null:
		pot_texture = EditionArt.icon("pot")
	if plate_texture == null:
		plate_texture = EditionArt.icon("plate")
	if altar_texture == null:
		altar_texture = UpgradeArt.prop("altar_stone")
		if altar_texture == null:
			altar_texture = EditionArt.icon("altar")
	if stairs_texture == null:
		stairs_texture = EditionArt.icon("stairs")
	if pearl_texture == null:
		pearl_texture = EditionArt.icon("pearl")

func setup(target: Node2D, arena_layout: ArenaLayout, number: int, run_seed: int) -> void:
	clear()
	player = target
	layout = arena_layout
	floor_number = number
	var generated := _generate(arena_layout, number, run_seed)
	pots.assign(generated.pots)
	plates.assign(generated.plates)
	for entry in pots:
		var pot := Pot.new()
		pot.position = entry.position
		pot.texture = pot_texture
		entry.node = pot
		pot.broken.connect(_on_pot_broken.bind(entry))
		add_child(pot)
	_warnings = Node2D.new()
	_warnings.name = "TrapWarnings"
	_warnings.material = Lighting.unshaded()
	_warnings.draw.connect(_draw_warnings)
	add_child(_warnings)
	if number == 10:
		_crystal = SummitCrystal.new()
		_crystal.name = "SummitCrystal"
		_crystal.position = ArenaLayout.EXIT_POSITION
		add_child(_crystal)
		queue_redraw()
		return
	if number > 0:
		_altar = AltarVisual.new()
		_altar.name = "BloodBeadAltar"
		_altar.position = ArenaLayout.ALTAR_POSITION
		_altar.stone_texture = altar_texture
		_altar.bead_texture = pearl_texture
		add_child(_altar)
	var foreground := UpgradeArt.prop("stairs_front")
	if number > 0 and foreground != null:
		var arch := Sprite2D.new()
		arch.name = "StairArch"
		arch.texture = foreground
		arch.centered = false
		arch.position = ArenaLayout.STAIRS_POSITION + GATE_RECT.position
		arch.scale = GATE_RECT.size / foreground.get_size()
		arch.z_index = 4
		add_child(arch)
	queue_redraw()

func clear() -> void:
	for node in get_children():
		remove_child(node)
		node.queue_free()
	pots.clear()
	plates.clear()
	arrows.clear()
	player = null
	layout = null
	floor_number = -1
	cleared = false
	pearl_available = false
	_altar = null
	_crystal = null
	_warnings = null
	enabled = false
	queue_redraw()

func set_landmark_state(floor_cleared: bool, has_pearl: bool) -> void:
	cleared = floor_cleared
	pearl_available = has_pearl
	if _altar != null:
		_altar.set_bead(pearl_available)
	queue_redraw()

func set_crystal_state(state: String) -> void:
	if _crystal != null:
		_crystal.set_state(state)

static func _generate(arena_layout: ArenaLayout, number: int, run_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([run_seed, WorldData.ID, number])
	var available: Array[Vector2] = []
	var reserved := GROUND_POINTS if number == 0 else arena_layout.reserved_points
	for row in range(5):
		for column in range(9):
			var point := Vector2(218 + column * 105, 168 + row * 98)
			if arena_layout.is_walkable(point, WorldData.PLATE_RADIUS + 6.0) and not _near_reserved(point, reserved):
				available.append(point)
	var pot_spots: Array[Dictionary] = []
	var plate_spots: Array[Dictionary] = []
	var late := number >= 5 and number <= 9
	var wanted := WorldData.LATE_PLATE_COUNT if late else WorldData.EARLY_PLATE_COUNT
	var candidates := available.duplicate()
	while not candidates.is_empty() and plate_spots.size() < wanted:
		var point: Vector2 = candidates.pop_at(rng.randi_range(0, candidates.size() - 1))
		var plate := _make_plate(point, arena_layout, reserved, rng)
		if not plate.is_empty():
			plate_spots.append(plate)
			available.erase(point)
	while not available.is_empty() and pot_spots.size() < WorldData.POT_COUNT:
		var point: Vector2 = available.pop_at(rng.randi_range(0, available.size() - 1))
		var drop_index := rng.randi_range(0, WorldData.POT_DROPS.size() - 1)
		pot_spots.append({"position": point, "drop": WorldData.POT_DROPS[drop_index]})
	return {"pots": pot_spots, "plates": plate_spots}

static func _near_reserved(point: Vector2, reserved: Array) -> bool:
	for landmark in reserved:
		if point.distance_squared_to(landmark) < 68.0 * 68.0:
			return true
	return false

static func _make_plate(point: Vector2, arena_layout: ArenaLayout, reserved: Array, rng: RandomNumberGenerator) -> Dictionary:
	var rotation := rng.randi_range(0, 7)
	for offset in range(8):
		var heading := Vector2.from_angle((rotation + offset) * TAU / 8.0)
		var origin := point - heading * WorldData.ARROW_SOURCE_DISTANCE
		var finish := origin + heading * WorldData.ARROW_RANGE
		if not arena_layout.is_walkable(origin, 16.0) or not arena_layout.has_clear_line(origin, point + heading * 45.0, ArenaLayout.PROJECTILE_RADIUS):
			continue
		var safe := true
		for landmark in reserved:
			var on_path := Geometry2D.get_closest_point_to_segment(landmark, origin, finish)
			if on_path.distance_squared_to(landmark) < 47.0 * 47.0:
				safe = false
				break
		if safe:
			return {"position": point, "direction": heading, "origin": origin,
				"windup": 0.0, "cooldown": 0.0, "held": false}
	return {}

func _on_pot_broken(entry: Dictionary) -> void:
	sound_requested.emit("pot_break", entry.position)
	var drop: String = entry.drop
	if not drop.is_empty():
		drop_requested.emit(drop, entry.position)

func _physics_process(delta: float) -> void:
	if not enabled or not is_instance_valid(player) or not player.alive or plates.is_empty():
		return
	for index in plates.size():
		_update_plate(index, delta)
	arrows = arrows.filter(func(arrow): return is_instance_valid(arrow) and not arrow.consumed)
	_warnings.queue_redraw()
	queue_redraw()

func _update_plate(index: int, delta: float) -> void:
	var plate := plates[index]
	var pressed := _occupied(plate.position)
	if plate.windup > 0.0:
		plate.windup = maxf(0.0, plate.windup - delta)
		if plate.windup == 0.0:
			_fire(index, plate.origin, WorldData.ARROW_RANGE)
			plate.cooldown = WorldData.PLATE_RESET
			sound_requested.emit("trap_arrow", plate.origin)
	elif plate.cooldown > 0.0:
		plate.cooldown = maxf(0.0, plate.cooldown - delta)
	elif pressed and not plate.held and not _arrow_in_flight(index):
		plate.windup = WorldData.PLATE_WARNING
		sound_requested.emit("trap_warn", plate.origin)
	plate.held = pressed

func _arrow_in_flight(index: int) -> bool:
	for arrow in arrows:
		if is_instance_valid(arrow) and not arrow.consumed and arrow.get_meta("plate_index") == index:
			return true
	return false

func _occupied(point: Vector2) -> bool:
	var radius := WorldData.PLATE_RADIUS
	if player.global_position.distance_squared_to(point) <= radius * radius:
		return true
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.alive and enemy.global_position.distance_squared_to(point) <= radius * radius:
			return true
	return false

func _fire(index: int, origin: Vector2, distance: float) -> void:
	var arrow := ProjectileScene.instantiate()
	arrow.set_meta("plate_index", index)
	arrow.trap_arrow = true
	arrow.impact_sound.connect(sound_requested.emit)
	arrow.z_index = 1
	add_child(arrow)
	arrow.setup(origin, plates[index].direction, WorldData.ARROW_DAMAGE, false, player, WorldData.ARROW_SPEED, distance)
	arrows.append(arrow)

func disarm_traps() -> void:
	for plate in plates:
		plate.windup = 0.0
	for arrow in arrows:
		if is_instance_valid(arrow):
			arrow.cancel()
	arrows.clear()
	_warnings.queue_redraw()
	queue_redraw()

func snapshot() -> Dictionary:
	var broken: Array[int] = []
	for index in pots.size():
		if not pots[index].node.alive:
			broken.append(index)
	var mechanisms := []
	for plate in plates:
		mechanisms.append({"windup": plate.windup, "cooldown": plate.cooldown, "held": plate.held})
	var flight := []
	for arrow in arrows:
		if is_instance_valid(arrow) and not arrow.consumed:
			flight.append({"plate": arrow.get_meta("plate_index"), "position": arrow.global_position,
				"remaining": arrow.remaining_distance})
	return {"broken": broken, "plates": mechanisms, "arrows": flight}

func restore(data: Variant) -> bool:
	if not _valid_snapshot(data, pots, plates, layout):
		return false
	for index in pots.size():
		var pot: Node2D = pots[index].node
		pot.alive = index not in data.broken
		pot.queue_redraw()
	for index in plates.size():
		var state: Dictionary = data.plates[index]
		plates[index].windup = state.windup
		plates[index].cooldown = state.cooldown
		plates[index].held = state.held
	for arrow in arrows:
		if is_instance_valid(arrow):
			remove_child(arrow)
			arrow.queue_free()
	arrows.clear()
	for entry in data.arrows:
		_fire(entry.plate, entry.position, entry.remaining)
	queue_redraw()
	return true

static func fresh_snapshot(arena_layout: ArenaLayout, number: int, run_seed: int) -> Dictionary:
	var mechanisms := []
	for plate: Dictionary in _generate(arena_layout, number, run_seed).plates:
		mechanisms.append({"windup": plate.windup, "cooldown": plate.cooldown, "held": plate.held})
	return {"broken": [], "plates": mechanisms, "arrows": []}

static func validate_snapshot(data: Variant, arena_layout: ArenaLayout, number: int, run_seed: int) -> bool:
	var generated := _generate(arena_layout, number, run_seed)
	return _valid_snapshot(data, generated.pots, generated.plates, arena_layout)

static func _valid_snapshot(data: Variant, pot_entries: Array, plate_entries: Array, arena_layout: ArenaLayout) -> bool:
	if not data is Dictionary or not data.get("broken") is Array or not data.get("plates") is Array or not data.get("arrows") is Array:
		return false
	if data.plates.size() != plate_entries.size() or data.broken.size() > pot_entries.size() or data.arrows.size() > plate_entries.size():
		return false
	var broken := {}
	for index in data.broken:
		if not index is int or index < 0 or index >= pot_entries.size() or broken.has(index):
			return false
		broken[index] = true
	for state in data.plates:
		if not state is Dictionary or not _valid_time(state.get("windup"), WorldData.PLATE_WARNING) or not _valid_time(state.get("cooldown"), WorldData.PLATE_RESET) or not state.get("held") is bool:
			return false
		if state.windup > 0.0 and state.cooldown > 0.0:
			return false
	var flying := {}
	for arrow in data.arrows:
		if not arrow is Dictionary or not arrow.get("plate") is int or not arrow.get("position") is Vector2 or not _valid_time(arrow.get("remaining"), WorldData.ARROW_RANGE):
			return false
		var index: int = arrow.plate
		if index < 0 or index >= plate_entries.size() or flying.has(index) or arrow.remaining <= 0.0:
			return false
		var plate: Dictionary = plate_entries[index]
		var expected: Vector2 = plate.origin + plate.direction * (WorldData.ARROW_RANGE - arrow.remaining)
		var position: Vector2 = arrow.position
		if not arena_layout.has_clear_line(plate.origin, position, ArenaLayout.PROJECTILE_RADIUS) or position.distance_squared_to(expected) > 0.25:
			return false
		flying[index] = true
	return true

static func _valid_time(value: Variant, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= 0.0 and value <= maximum

func _draw() -> void:
	if floor_number < 0:
		return
	if floor_number > 0 and floor_number != 10:
		_draw_stairs()
	for plate in plates:
		_draw_plate(plate)

func _draw_stairs() -> void:
	var gate := ArenaLayout.STAIRS_POSITION
	var gate_id := "stairs_open" if cleared else "stairs_closed"
	var arch_texture := UpgradeArt.prop(gate_id)
	if arch_texture != null:
		draw_texture_rect(arch_texture, Rect2(gate + GATE_RECT.position, GATE_RECT.size), false)
		return
	_draw_ring(gate, 33.0, Color("9ef0e2") if cleared else Color("7a657f"))
	if stairs_texture != null:
		draw_texture_rect(stairs_texture, Rect2(gate - Vector2(48, 54), Vector2(96, 92)), false,
			Color.WHITE if cleared else Color("766673"))
	else:
		for step in range(4):
			draw_rect(Rect2(gate - Vector2(38, 28 - step * 13), Vector2(76, 11)),
				Color("91859e") if cleared else Color("4f4758"))
	if not cleared:
		draw_rect(Rect2(gate - Vector2(8, 11), Vector2(16, 14)), Color("a57a83"), false, 2.0)
		draw_arc(gate - Vector2(0, 11), 5.0, PI, TAU, 10, Color("a57a83"), 2.0)

func _draw_ring(point: Vector2, radius: float, color: Color) -> void:
	draw_circle(point + Vector2(0, 5), radius, Color(color.r, color.g, color.b, 0.14))
	draw_arc(point + Vector2(0, 5), radius, 0.0, TAU, 40, Color(color.r, color.g, color.b, 0.73), 2.0)

func _draw_plate(plate: Dictionary) -> void:
	var point: Vector2 = plate.position
	var origin: Vector2 = plate.origin
	var heading: Vector2 = plate.direction
	var winding: bool = plate.windup > 0.0
	var accent := Color("ffd394") if winding else Color("a4836c")
	var pressure_art := UpgradeArt.prop("plate_armed" if winding else "plate")
	if pressure_art != null:
		var lift: float = 4.0 * (1.0 - plate.windup / WorldData.PLATE_WARNING) if winding else 0.0
		draw_texture_rect(pressure_art, Rect2(point - Vector2(24, 17 + lift), Vector2(48, 34)), false)
	elif plate_texture != null:
		draw_texture_rect(plate_texture, Rect2(point - Vector2(25, 20), Vector2(50, 40)), false, Color("aaa0a3"))
	else:
		draw_rect(Rect2(point - Vector2(21, 14), Vector2(42, 28)), Color("695a61"))
		draw_rect(Rect2(point - Vector2(16, 10), Vector2(32, 20)), Color("352e39"))
	var launcher := UpgradeArt.prop("launcher_armed" if winding else "launcher")
	if launcher != null:
		draw_set_transform(origin, heading.angle())
		draw_texture_rect(launcher, Rect2(-17, -13, 26, 26), false)
		draw_set_transform(Vector2.ZERO)
	else:
		draw_rect(Rect2(origin - Vector2(8, 8), Vector2(16, 16)), Color("2e2632"))
		draw_line(origin - heading * 4.0, origin + heading * 8.0, accent, 3.0)
	if not winding:
		_draw_chevron(self, point, heading, accent, 7.0)

func _draw_warnings() -> void:
	var accent := Color("ffd394")
	for plate in plates:
		if plate.windup <= 0.0:
			continue
		var origin: Vector2 = plate.origin
		var heading: Vector2 = plate.direction
		var finish := origin + heading * WorldData.ARROW_RANGE
		var block := layout.first_block(origin, finish, ArenaLayout.PROJECTILE_RADIUS)
		if block != INF:
			finish = origin.lerp(finish, block)
		_warnings.draw_arc(plate.position, WorldData.PLATE_RADIUS, 0.0, TAU, 24, Color(accent, 0.64), 1.5)
		_draw_chevron(_warnings, plate.position, heading, accent, 7.0)
		_warnings.draw_line(origin, finish, Color(0.97, 0.55, 0.30, 0.27), 12.0)
		_warnings.draw_dashed_line(origin, finish, accent, 2.0, 8.0)
		for distance in range(28, floori(origin.distance_to(finish)), 36):
			_draw_chevron(_warnings, origin + heading * float(distance), heading, accent, 8.0)

func _draw_chevron(surface: CanvasItem, point: Vector2, heading: Vector2, color: Color, size: float) -> void:
	var cross := heading.orthogonal() * size * 0.6
	var back := point - heading * size
	surface.draw_line(back + cross, point, color, 2.0)
	surface.draw_line(back - cross, point, color, 2.0)
