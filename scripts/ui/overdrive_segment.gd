## One unit of the select-screen Overdrive gauge.
class_name OverdriveSegment
extends Panel

enum Kind { EMPTY, ACCOUNTED, EXTRA }

@export var empty_style: StyleBoxFlat
@export var accounted_style: StyleBoxFlat
@export var extra_style: StyleBoxFlat

var kind := Kind.EMPTY
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Returns true when this rectangle was hidden or showed a different kind.
func set_kind(next: Kind) -> bool:
	var changed := not visible or kind != next
	kind = next
	visible = true
	_apply(next)
	if not changed:
		return false
	_stop()
	modulate = Color.WHITE
	scale = Vector2.ONE
	return true


## Pop in. delay staggers a group of rectangles from the same mech.
func arrive(delay: float = 0.0) -> void:
	_stop()
	pivot_offset = custom_minimum_size * 0.5
	modulate.a = 0.0
	scale = Vector2(0.72, 0.86)
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.set_parallel(true)
	_tween.tween_property(self, "modulate:a", 1.0, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func dismiss() -> void:
	_stop()
	visible = false
	modulate = Color.WHITE
	scale = Vector2.ONE


func _apply(next: Kind) -> void:
	var style := empty_style
	match next:
		Kind.ACCOUNTED:
			style = accounted_style
		Kind.EXTRA:
			style = extra_style
	if style != null:
		add_theme_stylebox_override("panel", style)


func _stop() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
