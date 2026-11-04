@tool
class_name BonusPanelRow
extends VBoxContainer

## Name on the left. The info mark shows only when this line has a note.
@onready var _name_label: Label = %Name
@onready var _tip: TextureButton = %Tip


func show_line(title: String, tip: String = "") -> void:
	if not is_node_ready():
		show_line.call_deferred(title, tip)
		return
	_name_label.text = title
	if _tip == null:
		return
	_tip.visible = tip != ""
	_tip.set_meta("note", tip)
	if tip == "":
		return
	var note := _tip_host()
	if note == null:
		return
	note.attach(_tip, tip)


func _tip_host() -> InfoNote:
	var node: Node = self
	while node != null:
		var note := node.get_node_or_null("TipLayer/TipHost/SpecialNote") as InfoNote
		if note != null:
			return note
		note = node.get_node_or_null("SpecialNote") as InfoNote
		if note != null:
			return note
		node = node.get_parent()
	return null
