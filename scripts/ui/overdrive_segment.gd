## One unit of the select-screen Overdrive gauge.
class_name OverdriveSegment
extends Panel

enum Kind { EMPTY, ACCOUNTED, EXTRA }

@export var empty_style: StyleBoxFlat
@export var accounted_style: StyleBoxFlat
@export var extra_style: StyleBoxFlat

const FLASH_HALF := 0.18
const FLASH_TIMES := 3

var kind := Kind.EMPTY
var _tween: Tween
var _flashing := false


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


func is_flashing() -> bool:
	return _flashing


## Three swings to white and back. done runs after the last return to rest.
func flash_white(rest: Color, done: Callable = Callable()) -> void:
	_stop()
	_flashing = true
	var style := StyleBoxFlat.new()
	style.bg_color = rest
	style.set_corner_radius_all(2)
	add_theme_stylebox_override("panel", style)
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	for _pulse in FLASH_TIMES:
		_tween.tween_property(style, "bg_color", Color.WHITE, FLASH_HALF)
		_tween.tween_property(style, "bg_color", rest, FLASH_HALF)
	_tween.finished.connect(func() -> void:
		_flashing = false
		if done.is_valid():
			done.call()
	)


## A gauge-owned style, so every filled pill can share one color and pulse together.
func apply_style(style: StyleBoxFlat) -> void:
	visible = true
	if style != null:
		add_theme_stylebox_override("panel", style)


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
	_flashing = false
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
