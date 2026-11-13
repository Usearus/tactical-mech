@tool
class_name TacticChoice
extends HBoxContainer

@onready var button: Button = %Button
@onready var _tip: TextureButton = %Tip
@onready var _spacer: Control = %Spacer


## The info mark shows only when this tactic has a bonus note.
## A tactic without one keeps the same gap, with empty space where the mark sits.
func show_bonus(note_host: InfoNote, text: String) -> void:
	if not is_node_ready():
		show_bonus.call_deferred(note_host, text)
		return
	if _tip == null:
		return
	var marked := text != ""
	_tip.visible = marked
	if _spacer != null:
		_spacer.visible = not marked
	_tip.set_meta("note", text)
	if text == "" or note_host == null:
		return
	_tip.set_meta("tip_width", 420.0)
	note_host.attach(_tip, text)
