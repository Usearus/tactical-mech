class_name AccentPulse
extends RefCounted

const FILL := Color(0.25, 0.72, 0.95)
const FLASH := Color(0.72, 0.94, 1.0)
const VARIATION := &"AccentButton"


## Resting Accent from the project theme. Clears a pulse override.
static func clear(button: Button) -> void:
	if button == null:
		return
	button.theme_type_variation = VARIATION
	for slot in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		button.remove_theme_stylebox_override(slot)


## Loops a copy of the Accent normal style toward the Accent hover color. Pressed stays the theme style.
static func start(host: Node, button: Button) -> Tween:
	clear(button)
	var flash := _style_color(button, "hover", FLASH)
	var resting := _duplicate_style(button, "normal")
	var rest := resting.bg_color
	for slot in ["normal", "hover", "focus"]:
		button.add_theme_stylebox_override(slot, resting)
	var tween := host.create_tween()
	tween.set_loops()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(resting, "bg_color", flash, 0.45)
	tween.tween_property(resting, "bg_color", rest, 0.45)
	return tween


static func _duplicate_style(button: Button, slot: String) -> StyleBoxFlat:
	var source := button.get_theme_stylebox(slot)
	if source is StyleBoxFlat:
		return (source as StyleBoxFlat).duplicate()
	var style := StyleBoxFlat.new()
	style.bg_color = FILL
	return style


static func _style_color(button: Button, slot: String, fallback: Color) -> Color:
	var source := button.get_theme_stylebox(slot)
	if source is StyleBoxFlat:
		return (source as StyleBoxFlat).bg_color
	return fallback
