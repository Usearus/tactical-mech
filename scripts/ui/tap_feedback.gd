extends CanvasLayer

const PULSE := preload("res://scenes/ui/tap_pulse.tscn")
## Above menus and battle overlays. The screen fade stays at 100.
const FEEDBACK_LAYER := 95

var _pressed := false


func _ready() -> void:
	layer = FEEDBACK_LAYER
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	var pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if pressed and not _pressed:
		_spawn(get_viewport().get_mouse_position())
	_pressed = pressed


func _spawn(at: Vector2) -> void:
	if not get_viewport().get_visible_rect().has_point(at):
		return
	var pulse := PULSE.instantiate() as Control
	add_child(pulse)
	pulse.position = at - pulse.size * 0.5
