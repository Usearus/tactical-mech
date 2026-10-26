class_name GaugePitch
extends Control

## The +1 lightning that leaves a discarded card and arcs into the Overdrive gauge.
## The node flies itself, then frees itself.

signal arrived

const FLIGHT := 0.58

var _from := Vector2.ZERO
var _mid := Vector2.ZERO
var _to := Vector2.ZERO
var _start_scale := 1.0
var _measured := false
var _finished := false


func fly(from_point: Vector2, to_point: Vector2, delay: float = 0.0, start_scale: float = 1.0) -> void:
	top_level = true
	z_as_relative = false
	z_index = 140
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_start_scale = clampf(start_scale, 0.4, 1.4)
	scale = Vector2(_start_scale, _start_scale)
	_from = from_point
	_to = to_point
	_mid = _bend(from_point, to_point)
	_measure()
	_put(from_point)
	modulate.a = 1.0
	visible = delay <= 0.0
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	if delay > 0.0:
		tween.tween_interval(delay)
		tween.tween_callback(func() -> void:
			visible = true
		)
	tween.tween_method(_along, 0.0, 1.0, FLIGHT)
	tween.finished.connect(_finish, CONNECT_ONE_SHOT)


func _bend(from_point: Vector2, to_point: Vector2) -> Vector2:
	var span := to_point - from_point
	var mid := from_point.lerp(to_point, randf_range(0.3, 0.7))
	if span.length_squared() <= 1.0:
		return mid
	var reach := clampf(span.length() * randf_range(0.18, 0.42), 90.0, 280.0)
	var side := -1.0 if randf() < 0.5 else 1.0
	return mid + Vector2(-span.y, span.x).normalized() * side * reach


func _along(t: float) -> void:
	var remain := 1.0 - t
	var center := remain * remain * _from + 2.0 * remain * t * _mid + t * t * _to
	var shrink := lerpf(_start_scale, _start_scale * 0.32, smoothstep(0.58, 1.0, t))
	scale = Vector2(shrink, shrink)
	modulate.a = 1.0 - smoothstep(0.84, 1.0, t)
	_put(center)


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if is_inside_tree():
		arrived.emit()
	queue_free()


func _measure() -> void:
	if _measured:
		return
	var row := get_node_or_null("Row") as Control
	var box := row.get_combined_minimum_size() if row != null else get_combined_minimum_size()
	if box.x < 1.0 or box.y < 1.0:
		box = Vector2(180, 80)
	size = box
	pivot_offset = box * 0.5
	_measured = true


func _put(center: Vector2) -> void:
	var current: Vector2 = get_global_transform() * (size * 0.5)
	global_position += center - current
