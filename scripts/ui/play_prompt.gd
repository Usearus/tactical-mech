class_name PlayPrompt
extends CenterContainer

@onready var _line: Label = %Line


func show_line(text: String) -> void:
	if _line != null:
		_line.text = text
	visible = text != ""


func clear() -> void:
	visible = false
	if _line != null:
		_line.text = ""
