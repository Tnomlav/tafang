extends Node2D

const TICK_COLOR := Color(0.08, 0.08, 0.08, 0.9)
const BAR_START_X := 1.0
const BAR_WIDTH := 30.0
const TICK_TOP_Y := 0.5
const TICK_BOTTOM_Y := 5.5

var max_health := 0


func set_max_health(value: int) -> void:
	max_health = maxi(value, 0)
	queue_redraw()


func _draw() -> void:
	if max_health <= 10:
		return

	for health_value in range(10, max_health, 10):
		var x := BAR_START_X + BAR_WIDTH * float(health_value) / float(max_health)
		x = clampf(x, BAR_START_X + 0.5, BAR_START_X + BAR_WIDTH - 0.5)
		draw_line(Vector2(x, TICK_TOP_Y), Vector2(x, TICK_BOTTOM_Y), TICK_COLOR, 1.0, false)
