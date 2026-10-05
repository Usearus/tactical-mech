class_name InfoNote
extends PanelContainer

## Longest legend line is about 730px. This text column is half of that, so those sentences wrap to two or three lines.
const MAX_TEXT_WIDTH := 320.0

var _badge: Control
var _pinned := false


func attach(badge: TextureButton, note: String) -> void:
	watch(badge, note)
	if badge.has_meta("tip_pressed"):
		return
	badge.set_meta("tip_pressed", true)
	badge.pressed.connect(_on_pressed.bind(badge))


## Tap any control to pin the same note. Labels have no pressed signal.
func tap(control: Control, note: String) -> void:
	watch(control, note)
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if control.has_meta("tip_pressed"):
		return
	control.set_meta("tip_pressed", true)
	control.gui_input.connect(_on_tap.bind(control))


## Hover text for any control. Shown above the control so a card at the bottom of the screen still reveals it.
func watch(control: Control, note: String) -> void:
	control.set_meta("note", note)
	control.set_meta("keep_mouse", true)
	control.mouse_filter = Control.MOUSE_FILTER_STOP
	if control.has_meta("tip_watched"):
		return
	control.set_meta("tip_watched", true)
	control.tree_exiting.connect(_on_badge_left.bind(control))
	control.mouse_entered.connect(_on_entered.bind(control))
	control.mouse_exited.connect(_on_exited)


func dismiss() -> void:
	_pinned = false
	_badge = null
	visible = false


func _on_badge_left(badge: Control) -> void:
	if _badge == badge:
		dismiss()


func _on_entered(badge: Control) -> void:
	_badge = badge
	badge.modulate = Color(1.15, 1.15, 1.2)
	_show(badge)


func _on_exited() -> void:
	if _badge != null and is_instance_valid(_badge):
		_badge.modulate = Color.WHITE
	if _pinned:
		return
	visible = false


func _on_tap(event: InputEvent, badge: Control) -> void:
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	badge.accept_event()
	_on_pressed(badge)


func _on_pressed(badge: Control) -> void:
	if _pinned and _badge == badge:
		dismiss()
		return
	_pinned = true
	_badge = badge
	_show(badge)


func _input(event: InputEvent) -> void:
	if not _pinned or not visible:
		return
	var click := event as InputEventMouseButton
	if click == null or not click.pressed or click.button_index != MOUSE_BUTTON_LEFT:
		return
	var at := click.global_position
	if get_global_rect().has_point(at):
		return
	if _badge != null and is_instance_valid(_badge) and _badge.get_global_rect().has_point(at):
		return
	dismiss()


func _show(badge: Control) -> void:
	if not is_instance_valid(badge):
		dismiss()
		return
	var label := get_node_or_null("Row/Note") as Label
	if label != null:
		label.text = str(badge.get_meta("note", ""))
	_apply_icon(badge)
	visible = true
	var wrap_limit := MAX_TEXT_WIDTH
	if badge.has_meta("tip_width"):
		wrap_limit = float(badge.get_meta("tip_width"))
	var note_size := _fitted_size(label, wrap_limit)
	size = note_size
	var origin := badge.get_global_rect()
	var host := get_parent() as Control
	var bounds := host.get_global_rect() if host != null else Rect2()
	var x := origin.end.x - note_size.x
	var y := origin.position.y - note_size.y - 8.0
	var min_x := bounds.position.x + 8.0
	var max_x := bounds.end.x - note_size.x - 8.0
	x = clampf(x, min_x, maxf(min_x, max_x))
	if y < bounds.position.y + 8.0:
		y = origin.end.y + 8.0
	global_position = Vector2(x, y)


func _apply_icon(badge: Control) -> void:
	var slot := get_node_or_null("Row/Icon") as TextureRect
	if slot == null:
		return
	var texture: Texture2D = null
	var tint := Color.WHITE
	if badge is TextureButton:
		texture = (badge as TextureButton).texture_normal
	else:
		var icon := badge.get_node_or_null("Icon") as TextureRect
		if icon != null and icon.visible:
			texture = icon.texture
			tint = icon.modulate
	slot.visible = texture != null
	slot.texture = texture
	slot.modulate = tint


func _fitted_size(label: Label, wrap_limit: float = MAX_TEXT_WIDTH) -> Vector2:
	var text := "" if label == null else label.text
	var wrap := wrap_limit
	var text_height := 0.0
	if label != null and not text.is_empty():
		var font := label.get_theme_font("font")
		var font_size := label.get_theme_font_size("font_size")
		var line_width := 0.0
		for line in text.split("\n"):
			line_width = maxf(line_width, font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		wrap = minf(line_width, wrap_limit)
		text_height = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, wrap, font_size).y
		label.custom_minimum_size = Vector2(wrap, text_height)
	var icon := get_node_or_null("Row/Icon") as TextureRect
	var content := Vector2(wrap, text_height)
	if icon != null and icon.visible:
		content.x += 8.0 + icon.custom_minimum_size.x
		content.y = maxf(content.y, icon.custom_minimum_size.y)
	var style := get_theme_stylebox("panel")
	return style.get_minimum_size() + content
