class_name BattleShot
extends Node2D

## One bullet or rocket. The node flies itself, then frees itself.
## Timers and tweens own the wait, so the caller does not have to await fly().

signal arrived


func fly(from_point: Vector2, to_point: Vector2, seconds: float, arc: float, delay: float) -> void:
	position = from_point
	visible = false
	if delay > 0.0:
		var timer := get_tree().create_timer(delay)
		timer.timeout.connect(_launch.bind(from_point, to_point, seconds, arc), CONNECT_ONE_SHOT)
		return
	_launch(from_point, to_point, seconds, arc)


func _launch(from_point: Vector2, to_point: Vector2, seconds: float, arc: float) -> void:
	if not is_inside_tree():
		queue_free()
		return
	visible = true
	var mid := (from_point + to_point) * 0.5
	var span := to_point - from_point
	if absf(arc) > 0.001 and span.length_squared() > 1.0:
		mid += Vector2(-span.y, span.x).normalized() * arc
	if span.length_squared() > 1.0:
		rotation = span.angle()
	var tween := create_tween()
	tween.tween_method(_along.bind(from_point, mid, to_point), 0.0, 1.0, maxf(seconds, 0.05))
	tween.finished.connect(_finish, CONNECT_ONE_SHOT)


func _finish() -> void:
	if not is_inside_tree():
		return
	arrived.emit()
	queue_free()


func _along(t: float, start: Vector2, mid: Vector2, finish: Vector2) -> void:
	var remain := 1.0 - t
	var next := remain * remain * start + 2.0 * remain * t * mid + t * t * finish
	var step := next - position
	position = next
	if step.length_squared() > 0.01:
		rotation = step.angle()
