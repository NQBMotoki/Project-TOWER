extends Node2D

const AMBIENT := [Color("b8bfd0"), Color("c2b7b8"), Color("aab5c8"), Color("a8acc7")]
const FLAME_COLORS := [Color("efc294"), Color("f1b17c"), Color("c6a4d5"), Color("b0a9db")]
const FLAME_OFFSET := Vector2(0, -27)
const SHADOW_LIGHT_LIMIT := 2
const NEARBY_UPDATE := 0.32

static var _radial: GradientTexture2D
static var _signal_material: CanvasItemMaterial
var _torch_lights: Array[PointLight2D] = []
var _clock := 0.0
var _shadow_timer := 0.0
var _high_quality := false
var _torch_energy := 0.0

static func radial_texture() -> GradientTexture2D:
	if _radial == null:
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0.0, 0.23, 0.58, 1.0])
		ramp.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0.80),
			Color(1, 1, 1, 0.27), Color(1, 1, 1, 0.0)])
		_radial = GradientTexture2D.new()
		_radial.gradient = ramp
		_radial.fill = GradientTexture2D.FILL_RADIAL
		_radial.fill_from = Vector2(0.5, 0.5)
		_radial.fill_to = Vector2(1.0, 0.5)
		_radial.width = 128
		_radial.height = 128
	return _radial

static func point_light(point: Vector2, tint: Color, diameter: float, energy: float) -> PointLight2D:
	var light := PointLight2D.new()
	light.texture = radial_texture()
	light.texture_scale = diameter / float(light.texture.get_width())
	light.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	light.color = tint
	light.energy = energy
	light.position = point
	return light

static func unshaded() -> CanvasItemMaterial:
	if _signal_material == null:
		_signal_material = CanvasItemMaterial.new()
		_signal_material.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	return _signal_material

func configure(floor: int, layout: ArenaLayout, fires: Array, high_quality: bool) -> void:
	clear()
	if floor < 1:
		return
	var region := 0
	if floor >= 10:
		region = 3
	elif floor >= 6:
		region = 2
	elif floor == 5:
		region = 1
	var ambient := CanvasModulate.new()
	ambient.name = "TowerAmbient"
	ambient.color = AMBIENT[region]
	add_child(ambient)
	_torch_energy = 0.62 if region == 1 else 0.53
	for point: Vector2 in fires:
		var light := point_light(point + FLAME_OFFSET, FLAME_COLORS[region], 315.0, _torch_energy)
		light.shadow_color = Color(0.13, 0.10, 0.16, 0.25)
		light.shadow_filter = Light2D.SHADOW_FILTER_PCF5
		light.shadow_filter_smooth = 0.55
		add_child(light)
		_torch_lights.append(light)
	for entry: Dictionary in layout.obstacles:
		_add_occluder(entry.rect)
	# Leave the opening itself unobstructed on the shared north approach.
	_add_occluder(Rect2(270, 37, 274, 34))
	_add_occluder(Rect2(736, 37, 274, 34))
	set_quality(high_quality)

func clear() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_torch_lights.clear()
	set_process(false)

func set_quality(high: bool) -> void:
	_high_quality = high
	set_process(high and not _torch_lights.is_empty())
	_shadow_timer = NEARBY_UPDATE
	_update_shadow_lights()
	if not high:
		for light in _torch_lights:
			light.energy = _torch_energy

func _process(delta: float) -> void:
	_clock += delta
	for light in _torch_lights:
		var phase := _clock * 6.4 + light.position.x * 0.037
		light.energy = _torch_energy * (1.0 + 0.06 * sin(phase) + 0.024 * sin(phase * 2.29))
	_shadow_timer -= delta
	if _shadow_timer <= 0.0:
		_shadow_timer = NEARBY_UPDATE
		_update_shadow_lights()

func _update_shadow_lights() -> void:
	if _torch_lights.is_empty():
		return
	var selected: Array[PointLight2D] = []
	if _high_quality:
		var camera := get_viewport().get_camera_2d()
		var point := camera.get_screen_center_position() if camera != null else ArenaLayout.PLAYER_START
		var ordered := _torch_lights.duplicate()
		ordered.sort_custom(func(a: PointLight2D, b: PointLight2D) -> bool:
			return a.global_position.distance_squared_to(point) < b.global_position.distance_squared_to(point))
		selected.assign(ordered.slice(0, SHADOW_LIGHT_LIMIT))
	for light in _torch_lights:
		light.shadow_enabled = light in selected

func _add_occluder(footprint: Rect2) -> void:
	var shape := OccluderPolygon2D.new()
	shape.polygon = PackedVector2Array([footprint.position, Vector2(footprint.end.x, footprint.position.y),
		footprint.end, Vector2(footprint.position.x, footprint.end.y)])
	var occluder := LightOccluder2D.new()
	occluder.occluder = shape
	occluder.sdf_collision = false
	add_child(occluder)
