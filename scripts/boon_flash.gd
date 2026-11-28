extends Node2D

var destination := Vector2.ZERO
var radius := 48.0
var kind := ""
var elapsed := 0.0

func _ready() -> void:
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit
	z_index = 2

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed >= 0.26:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := elapsed / 0.26
	var ink := Color(0.80, 0.54, 0.90, (1.0 - progress) * 0.62)
	if kind == "fork":
		var mid := destination * 0.53 + destination.orthogonal().normalized() * 7.0
		var end := destination * minf(1.0, progress * 2.8 + 0.35)
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, end]), ink, 2.0, true)
	elif kind == "pulse":
		var ring := lerpf(10.0, radius, progress)
		for i in range(6):
			var angle := TAU * i / 6.0
			draw_arc(Vector2.ZERO, ring, angle, angle + 0.64, 8, ink, 1.5, true)
	else:
		draw_arc(Vector2.ZERO, 17.0 + 9.0 * progress, 3.4, 5.9, 12, ink, 2.0, true)
