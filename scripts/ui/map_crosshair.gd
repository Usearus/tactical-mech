extends Control

## Destination mark on the briefing map. The blink belongs to this control.

const DIM := 0.15
const BEAT := 0.38


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tween := create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "modulate:a", DIM, BEAT)
	tween.tween_property(self, "modulate:a", 1.0, BEAT)
