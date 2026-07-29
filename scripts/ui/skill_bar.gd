extends Node2D

const HEALTH_BAR_BACKGROUND := preload("res://assets/textures/ui/unit_health_bar_back.png")

@export var max_value := 100.0
@export var value := 0.0:
	set(next_value):
		value = clampf(next_value, 0.0, max_value)
		queue_redraw()

@export var bar_size := Vector2(32.0, 3.0):
	set(next_size):
		bar_size = next_size
		queue_redraw()


func _ready() -> void:
	z_index = 4
	visible = true
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(HEALTH_BAR_BACKGROUND, Rect2(Vector2.ZERO, bar_size), false)
	var ratio := value / max_value if max_value > 0.0 else 0.0
	if ratio > 0.0:
		var fill_height := maxf(bar_size.y - 1.0, 0.5)
		draw_rect(Rect2(Vector2(1.0, 0.5), Vector2(maxf(bar_size.x - 2.0, 0.0) * ratio, fill_height)), Color(0.18, 0.88, 1.0, 1.0), true)
