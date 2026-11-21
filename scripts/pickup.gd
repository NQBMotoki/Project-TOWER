extends Node2D

const GameData = preload("res://data/game_data.gd")
var item_id := ""
var guided := false
var clock := 0.0
var bob := Vector2.ZERO
@onready var sprite: Sprite2D = $Sprite2D

func _process(delta: float) -> void:
	clock += delta
	bob.y = sin(clock * 3.0) * 2.0
	sprite.position = bob
	queue_redraw()

func _draw() -> void:
	var tint := Color("d8ba79")
	if guided:
		tint = Color("94dcff")
		draw_arc(Vector2.ZERO, 21.0 + 2.0 * sin(clock * 5.0), 0.0, TAU, 24, tint, 1.4, true)
		var point := Vector2(0, -37) + bob
		draw_colored_polygon(PackedVector2Array([point, point + Vector2(-6, -7), point + Vector2(6, -7)]), tint)
	draw_circle(Vector2.ZERO, 16, Color(tint, 0.15))
	draw_arc(Vector2.ZERO, 15.0, 0.0, TAU, 20, Color(tint, 0.43), 1.0, true)
	if sprite.texture != null:
		return
	draw_set_transform(bob)
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
