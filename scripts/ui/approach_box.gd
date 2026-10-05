extends Button
class_name ApproachBox

## Yellow cell a player could attack from. The fill is the look; this button only reports the click.
signal direction_chosen(cell: Vector2i)

@export var idle_style: StyleBoxFlat
@export var chosen_style: StyleBoxFlat
var approach_cell := Vector2i.ZERO

@onready var _fill: Panel = $Fill


func _ready() -> void:
	flat = true
	focus_mode = Control.FOCUS_NONE
	text = ""
	pressed.connect(_emit_choice)
	hide_direction()


func show_direction(chosen: bool) -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var style := chosen_style if chosen else idle_style
	if _fill != null and style != null:
		_fill.add_theme_stylebox_override("panel", style)


func hide_direction() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _emit_choice() -> void:
	direction_chosen.emit(approach_cell)
