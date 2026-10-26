class_name HandPrompt
extends Control

signal new_hand_chosen
signal end_turn_chosen
signal dismissed

@onready var _new_hand_button: Button = %NewHandButton
@onready var _end_turn_button: Button = %EndTurnButton
@onready var _close_button: Button = %Close


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	_new_hand_button.pressed.connect(_on_new_hand)
	_end_turn_button.pressed.connect(_on_end_turn)
	_close_button.pressed.connect(_on_close)


func open() -> void:
	var layer := get_parent()
	if layer is CanvasLayer:
		layer.visible = true
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var view_size := get_viewport_rect().size
	position = Vector2.ZERO
	size = view_size
	visible = true
	move_to_front()


func close() -> void:
	visible = false


func _on_new_hand() -> void:
	if not visible:
		return
	close()
	new_hand_chosen.emit()


func _on_end_turn() -> void:
	if not visible:
		return
	close()
	end_turn_chosen.emit()


func _on_close() -> void:
	if not visible:
		return
	close()
	dismissed.emit()
