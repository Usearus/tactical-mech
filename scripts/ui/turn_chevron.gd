extends Control
class_name TurnChevron

## Chevron from the theme sheet, above the mech whose turn it is. Bob moves so the map can place the root.

const BOB_FRACTION := 0.28
const HALF_BEAT := 0.45

@onready var _bob: Control = $Bob
@onready var _mark: TextureRect = $Bob/Mark

var _pulse: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_as_relative = false
	z_index = 12
	resized.connect(_fit_mark)
	_fit_mark()


func set_shown(shown: bool) -> void:
	if shown and visible and _pulse != null and _pulse.is_valid() and _pulse.is_running():
		return
	visible = shown
	if shown:
		_start_bob()
	else:
		_stop_bob()


func _fit_mark() -> void:
	if _bob == null or _mark == null or size.x < 1.0:
		return
	_bob.size = size
	_mark.position = Vector2.ZERO
	_mark.size = size


func _start_bob() -> void:
	if _bob == null or not is_inside_tree():
		return
	if _pulse != null and _pulse.is_valid() and _pulse.is_running():
		return
	_stop_bob()
	_bob.position = Vector2.ZERO
	var ink := _mark.material as ShaderMaterial
	if ink != null:
		ink.set_shader_parameter("whiten", 0.0)
	var travel := size.y * BOB_FRACTION
	_pulse = create_tween()
	_pulse.set_loops()
	_pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if ink != null:
		_pulse.tween_property(ink, "shader_parameter/whiten", 1.0, HALF_BEAT)
		_pulse.parallel().tween_property(_bob, "position:y", travel, HALF_BEAT)
		_pulse.tween_property(ink, "shader_parameter/whiten", 0.0, HALF_BEAT)
		_pulse.parallel().tween_property(_bob, "position:y", 0.0, HALF_BEAT)
	else:
		_pulse.tween_property(_bob, "position:y", travel, HALF_BEAT)
		_pulse.tween_property(_bob, "position:y", 0.0, HALF_BEAT)


func _stop_bob() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	_pulse = null
	if _bob != null:
		_bob.position = Vector2.ZERO
	if _mark != null and _mark.material is ShaderMaterial:
		(_mark.material as ShaderMaterial).set_shader_parameter("whiten", 0.0)
