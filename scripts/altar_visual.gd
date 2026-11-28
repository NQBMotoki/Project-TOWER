extends Node2D

const Art = preload("res://data/upgrade_art.gd")
const Lighting = preload("res://scripts/tower_lighting.gd")
const STONE_RECT := Rect2(-45, -49, 90, 85)

var stone_texture: Texture2D
var bead_texture: Texture2D
var _bead: Sprite2D
var _runes: Sprite2D
var _light: PointLight2D
var _transition: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var rune_mask := Art.prop("altar_runes")
	if rune_mask != null:
		_runes = Sprite2D.new()
		_runes.texture = rune_mask
		_runes.position = STONE_RECT.get_center()
		_runes.material = Lighting.unshaded()
		_runes.modulate.a = 0.12
		add_child(_runes)
	_bead = Sprite2D.new()
	_bead.texture = bead_texture
	_bead.position = Vector2(0, -25)
	_bead.material = Lighting.unshaded()
	if bead_texture != null:
		_bead.scale = Vector2(26, 26) / bead_texture.get_size()
	_bead.hide()
	add_child(_bead)
	_light = Lighting.point_light(Vector2(0, -22), Color("da5a75"), 138.0, 0.0)
	add_child(_light)

func set_bead(active: bool) -> void:
	if _bead.visible == active:
		return
	_bead.visible = active
	if _transition != null and _transition.is_valid():
		_transition.kill()
	_transition = create_tween().set_parallel()
	_transition.tween_property(_light, "energy", 0.58 if active else 0.0, 0.34)
	if _runes != null:
		_transition.tween_property(_runes, "modulate:a", 0.88 if active else 0.12, 0.34)
	queue_redraw()

func _draw() -> void:
	draw_texture_rect(Lighting.radial_texture(), Rect2(-52, 21, 112, 25), false, Color(0.04, 0.032, 0.05, 0.78))
	if stone_texture != null:
		draw_texture_rect(stone_texture, STONE_RECT, false)
	else:
		draw_rect(Rect2(-34, -23, 68, 49), Color("877884"))
		draw_rect(Rect2(-25, -15, 50, 25), Color("423044"))
	if _bead.visible and _bead.texture == null:
		draw_circle(_bead.position, 8.0, Color("ff9699"))
