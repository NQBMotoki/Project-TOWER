extends Node2D

signal broken

const WorldData = preload("res://data/complete_world.gd")
var hit_radius := WorldData.POT_RADIUS
var alive := true
var texture: Texture2D

func _ready() -> void:
	add_to_group("breakables")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

func take_damage(amount: float, _impulse := Vector2.ZERO) -> bool:
	if not alive or amount <= 0.0:
		return false
	alive = false
	broken.emit()
	queue_redraw()
	return true

func _draw() -> void:
	if not alive:
		draw_rect(Rect2(-11, 3, 23, 5), Color("29212a"))
		draw_rect(Rect2(-11, 2, 7, 3), Color("85513d"))
		draw_rect(Rect2(-1, 6, 6, 3), Color("ad6b4b"))
		draw_rect(Rect2(8, -1, 5, 4), Color("59382f"))
		return
	draw_rect(Rect2(-13, 4, 26, 6), Color("17151b"))
	if texture != null:
		draw_texture_rect(texture, Rect2(-16, -23, 32, 32), false)
	else:
		draw_rect(Rect2(-10, -15, 20, 23), Color("7c4934"))
		draw_rect(Rect2(-13, -11, 26, 13), Color("89543d"))
		draw_rect(Rect2(-8, -20, 16, 6), Color("a46746"))
		draw_rect(Rect2(-6, -19, 12, 3), Color("251b25"))
		draw_rect(Rect2(-10, -10, 5, 12), Color("bc7950"))
