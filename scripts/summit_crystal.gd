extends Node2D

const Art = preload("res://data/upgrade_art.gd")
const Lighting = preload("res://scripts/tower_lighting.gd")
const STATE_ENERGY := {"dormant": 0.40, "ready": 0.66, "activated": 1.02}
const STATE_OPACITY := {"dormant": 0.50, "ready": 0.77, "activated": 1.0}
const BASE_RECT := Rect2(-35, -11, 70, 33)
const CRYSTAL_RECT := Rect2(-30, -68, 61, 76)

var state := "dormant"
var _clock := 0.0
var _light: PointLight2D
var _emission: Node2D
var _base: Texture2D
var _crystal: Texture2D
var _glow: Texture2D

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_base = Art.prop("summit_crystal_base")
	_crystal = Art.prop("summit_crystal")
	_glow = Art.prop("summit_crystal_glow")
	_light = Lighting.point_light(Vector2(0, -30), Color("bd75ed"), 190.0, STATE_ENERGY[state])
	add_child(_light)
	_emission = Node2D.new()
	_emission.material = Lighting.unshaded()
	_emission.draw.connect(_draw_emission)
	add_child(_emission)

func set_state(value: String) -> void:
	if STATE_ENERGY.has(value):
		state = value

func _process(delta: float) -> void:
	_clock += delta
	var glow: float = STATE_ENERGY[state]
	_light.energy = lerpf(_light.energy, glow * (1.0 + 0.08 * sin(_clock * 2.0)), minf(delta * 5.0, 1.0))
	_emission.queue_redraw()

func _draw() -> void:
	draw_texture_rect(Lighting.radial_texture(), Rect2(-43, 11, 92, 27), false, Color(0.045, 0.035, 0.06, 0.74))
	if _base != null:
		draw_texture_rect(_base, BASE_RECT, false)
	if _crystal != null:
		draw_texture_rect(_crystal, CRYSTAL_RECT, false)
	else:
		draw_colored_polygon(PackedVector2Array([Vector2(-17, -8), Vector2(-24, -35), Vector2(3, -68),
			Vector2(24, -42), Vector2(19, -9), Vector2(0, 8)]), Color("9067b0"))

func _draw_emission() -> void:
	var opacity: float = STATE_OPACITY[state]
	if _glow != null:
		_emission.draw_texture_rect(_glow, CRYSTAL_RECT, false, Color(1, 1, 1, opacity * (0.90 + 0.10 * sin(_clock * 2.9))))
	for index in range(7):
		var rise := fposmod(_clock * 0.34 + index * 0.31, 1.0)
		var x := sin(_clock * 1.6 + index * 2.41) * (8.0 + rise * 24.0)
		var point := Vector2(roundf(x), roundf(-9.0 - rise * 68.0))
		var size := 2.0 if index % 3 == 0 else 1.0
		var alpha := sin(rise * PI) * opacity * 0.74
		_emission.draw_rect(Rect2(point, Vector2.ONE * size), Color(0.81, 0.56, 1.0, alpha))
