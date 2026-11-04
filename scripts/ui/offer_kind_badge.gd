class_name OfferKindBadge
extends PanelContainer

## Muted plate for a printed card. Gold marks an overdrive card. The blue plate stays on upgrades and new cards.
@export var grey_style: StyleBox
@export var gold_style: StyleBox

var _color_style: StyleBox


func _ready() -> void:
	var current := get_theme_stylebox("panel")
	if current != null:
		_color_style = current.duplicate()


func show_caption(caption: String, tone: String = "") -> void:
	var label := get_node_or_null("Caption") as Label
	if label != null:
		label.text = caption
	var style := _color_style
	if tone == "grey" and grey_style != null:
		style = grey_style
	elif tone == "gold" and gold_style != null:
		style = gold_style
	if style != null:
		add_theme_stylebox_override("panel", style)
	reset_size()
