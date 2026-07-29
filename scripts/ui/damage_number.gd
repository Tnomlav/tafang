extends Label

const DISPLAY_TIME := 0.5


func show_damage(amount: float) -> void:
	text = str(int(roundf(amount)))
	modulate = Color(1.0, 0.12, 0.08, 1.0)
	z_index = 40
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 6.0, DISPLAY_TIME)
	tween.tween_property(self, "modulate:a", 0.0, DISPLAY_TIME)
	tween.chain().tween_callback(queue_free)
