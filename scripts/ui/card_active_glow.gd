class_name CardActiveGlow
extends Panel

var _pulse: Tween


func set_lit(on: bool) -> void:
	if on:
		if visible and _pulse != null and _pulse.is_valid():
			return
		visible = true
		modulate.a = 0.45
		_pulse = create_tween()
		_pulse.set_loops()
		_pulse.tween_property(self, "modulate:a", 1.0, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		_pulse.tween_property(self, "modulate:a", 0.38, 0.62).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		return
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	visible = false
	modulate.a = 0.0
