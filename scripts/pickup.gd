extends Node2D

const GameData = preload("res://data/game_data.gd")
const EditionArt = preload("res://data/edition_art.gd")
const Lighting = preload("res://scripts/tower_lighting.gd")
const ICON_SIZE := 26.0
const LANDING_TIME := 0.22

static var _rendered: Dictionary = {}

var item_id := ""
var guided := false:
	set(value):
		guided = value
		_refresh_marker()
var _focused := false
var _key_name := ""
var _position := Vector2.ZERO
var _outline: Sprite2D
var _marker: Node2D
var _key: Label
var _shadow_size := Vector2(23, 9)
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	if sprite.texture == null:
		sprite.texture = EditionArt.icon(item_id)
	_marker = Node2D.new()
	_marker.material = Lighting.unshaded()
	_marker.draw.connect(_draw_marker)
	add_child(_marker)
	_outline = Sprite2D.new()
	_outline.material = Lighting.unshaded()
	_outline.show_behind_parent = true
	_marker.add_child(_outline)
	_key = Label.new()
	_key.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key.material = _marker.material
	var style := LabelSettings.new()
	style.font_size = 12
	style.font_color = Color("f3dfb1")
	style.outline_size = 4
	style.outline_color = Color("26202c")
	_key.label_settings = style
	_marker.add_child(_key)
	if sprite.texture != null:
		var graphics := _pickup_graphics(sprite.texture)
		sprite.texture = graphics[0]
		_outline.texture = graphics[1]
		_position = Vector2(0, -sprite.texture.get_height() * 0.44)
	else:
		_position = Vector2(0, -7)
	if GameData.slot_for(item_id) == "weapon":
		_shadow_size = Vector2(30, 7)
	elif item_id in GameData.STACKABLE:
		_shadow_size = Vector2(17, 7)
	elif GameData.is_book(item_id):
		_shadow_size = Vector2(23, 8)
	_move_art(_position - Vector2(0, 8))
	var landing := create_tween()
	landing.tween_method(_move_art, _position - Vector2(0, 8), _position, LANDING_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_refresh_marker()

func set_focused(value: bool, key_name := "") -> void:
	if _focused == value and _key_name == key_name:
		return
	_focused = value
	_key_name = key_name
	_refresh_marker()

func _move_art(point: Vector2) -> void:
	sprite.position = point
	_marker.position = point
	queue_redraw()

func _refresh_marker() -> void:
	if _marker == null:
		return
	_marker.visible = _focused or guided
	_outline.modulate = Color("b7e4ff") if guided else Color("f3dfb1")
	_key.text = _key_name
	_key.visible = _focused and not _key_name.is_empty()
	var half_height := sprite.texture.get_height() * 0.5 if sprite.texture != null else 10.0
	var width := maxf(56.0, _key.get_minimum_size().x + 6.0)
	_key.size = Vector2(width, 18)
	_key.position = Vector2(-width / 2.0, -half_height - 20.0)
	_marker.queue_redraw()

func _draw_marker() -> void:
	var half_height := sprite.texture.get_height() * 0.5 if sprite.texture != null else 10.0
	if guided and not _key.visible:
		var lift := -half_height - 9.0
		_marker.draw_polyline(PackedVector2Array([Vector2(-5, lift - 5), Vector2(0, lift), Vector2(5, lift - 5)]),
			Color("b7e4ff"), 2.0)
	if _focused and _outline.texture == null:
		var tint := Color("f3dfb1")
		for side in [-1.0, 1.0]:
			var x: float = side * 13.0
			_marker.draw_polyline(PackedVector2Array([Vector2(x - side * 4.0, -9), Vector2(x, -9),
				Vector2(x, 9), Vector2(x - side * 4.0, 9)]), tint, 1.0)

static func _pickup_graphics(texture: Texture2D) -> Array[Texture2D]:
	if _rendered.has(texture):
		return _rendered[texture]
	var source := texture.get_image()
	var result: Array[Texture2D] = [texture, null]
	if source != null and not source.is_empty():
		var ratio := ICON_SIZE / maxf(source.get_width(), source.get_height())
		var width := maxi(1, roundi(source.get_width() * ratio))
		var height := maxi(1, roundi(source.get_height() * ratio))
		source.resize(width, height, Image.INTERPOLATE_LANCZOS)
		source.convert(Image.FORMAT_RGBA8)
		var outline := Image.create_empty(width + 2, height + 2, false, Image.FORMAT_RGBA8)
		for y in range(-1, height + 1):
			for x in range(-1, width + 1):
				if _solid_pixel(source, x, y):
					continue
				if _solid_pixel(source, x - 1, y) or _solid_pixel(source, x + 1, y) \
						or _solid_pixel(source, x, y - 1) or _solid_pixel(source, x, y + 1):
					outline.set_pixel(x + 1, y + 1, Color.WHITE)
		result = [ImageTexture.create_from_image(source), ImageTexture.create_from_image(outline)]
	_rendered[texture] = result
	return result

static func _solid_pixel(image: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < image.get_width() and y < image.get_height() and image.get_pixel(x, y).a >= 0.38

func _draw() -> void:
	var shadow := Rect2(Vector2(2, 2) - _shadow_size * 0.5, _shadow_size)
	draw_texture_rect(Lighting.radial_texture(), shadow, false, Color(0.045, 0.038, 0.06, 0.82))
	if sprite.texture != null:
		return
	draw_set_transform(sprite.position)
	match item_id:
		"START_SWORD", "U01", "U06":
			draw_line(Vector2(-7, 8), Vector2(8, -8), Color("e6e5d3"), 4.0)
			draw_line(Vector2(-9, 1), Vector2(-1, 9), Color("ae8146"), 3.0)
		"START_STAFF", "U03":
			draw_line(Vector2(-6, 9), Vector2(5, -8), Color("b39173"), 3.0)
			draw_circle(Vector2(6, -8), 4.0, Color("9ae4e2"))
		"MUSHROOM":
			draw_rect(Rect2(-2, -1, 4, 9), Color("f2d6ad"))
			draw_circle(Vector2(0, -3), 7, Color("df856a"))
			draw_circle(Vector2(2, -5), 2, Color("f3c1a2"))
		"WATER", "POTION":
			draw_rect(Rect2(-3, -9, 6, 4), Color("c59f7b"))
			draw_rect(Rect2(-6, -5, 12, 14), Color("ecc3ad"))
			draw_rect(Rect2(-5, 0, 10, 8), Color("9ad8ef") if item_id == "WATER" else Color("db737e"))
		_:
			if GameData.is_book(item_id):
				draw_rect(Rect2(-10, -7, 20, 15), Color("a4805d"))
				draw_rect(Rect2(-8, -8, 16, 12), Color("ecd7ad"))
				draw_line(Vector2(0, -8), Vector2(0, 6), Color("9b8165"), 1.0)
			else:
				draw_colored_polygon(PackedVector2Array([
					Vector2(0, -9), Vector2(8, -2), Vector2(0, 9), Vector2(-8, -2),
				]), Color("dcac78"))
