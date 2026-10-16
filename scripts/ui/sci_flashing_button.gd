class_name SciFlashingButton
extends Button

var _pulse: Tween
var _blend: StyleBoxCrossfade


## Loop the normal texture toward the pressed texture.
## Hover, a real press, and disabled stay the theme styles.
func start_pulse() -> void:
	if _pulse != null and _pulse.is_valid() and _pulse.is_running():
		return
	var resting := get_theme_stylebox("normal")
	var bright := get_theme_stylebox("pressed")
	if resting == null or bright == null:
		return
	_blend = StyleBoxCrossfade.new()
	_blend.set_pair(resting.duplicate(), bright)
	add_theme_stylebox_override("normal", _blend)
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_pulse.tween_property(_blend, "amount", 1.0, 0.45)
	_pulse.tween_property(_blend, "amount", 0.0, 0.45)


func stop_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	_blend = null
	remove_theme_stylebox_override("normal")
