extends Node2D


var radius := 0.0:
	set(value):
		radius = maxf(value, 0.0)
		queue_redraw()

var fill_color := Color(0.25, 0.65, 1.0, 0.18):
	set(value):
		fill_color = value
		queue_redraw()

var outline_color := Color(0.45, 0.85, 1.0, 0.75):
	set(value):
		outline_color = value
		queue_redraw()

var outline_width := 2.0:
	set(value):
		outline_width = maxf(value, 0.0)
		queue_redraw()


func _draw() -> void:
	if radius <= 0.0:
		return

	draw_circle(Vector2.ZERO, radius, fill_color)
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 96, outline_color, outline_width, true)
