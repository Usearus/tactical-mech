## A bright fill that sweeps an overdrive bar from the left edge to the right edge.
class_name GaugeSwoosh
extends Control

signal finished

const SWEEP_TIME := 0.21

@onready var _fill: Control = $Fill
@onready var _body: ColorRect = $Fill/Body
@onready var _edge: ColorRect = $Fill/Edge

var _amount := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	resized.connect(_apply_amount)
	_set_amount(0.0)


## color is the bright fill. The leading edge stays lighter so the sweep reads as a swoosh.
func play(color: Color) -> void:
	_body.color = Color(color.r, color.g, color.b, 1.0)
	var edge := color.lightened(0.45)
	edge.a = 1.0
	_edge.color = edge
	if size.x < 1.0:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_method(_set_amount, 0.0, 1.0, SWEEP_TIME)
	tween.finished.connect(_finish)


func _set_amount(amount: float) -> void:
	_amount = clampf(amount, 0.0, 1.0)
	_apply_amount()


func _apply_amount() -> void:
	_fill.anchor_left = 0.0
	_fill.anchor_right = 0.0
	_fill.offset_left = 0.0
	_fill.offset_right = size.x * _amount


func _finish() -> void:
	finished.emit()
	queue_free()
