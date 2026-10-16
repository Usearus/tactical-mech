extends Control
class_name CellMark

var reticule_color := Color(0, 0, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	resized.connect(queue_redraw)


func show_reticule(color: Color) -> void:
	reticule_color = color
	queue_redraw()


func _draw() -> void:
	var bounds := size
	if bounds.x < 4.0 or bounds.y < 4.0:
		return
	if reticule_color.a <= 0.0:
		return
	var inset := 4.0
	var arm := minf(bounds.x, bounds.y) * 0.28
	var thick := 4.0
	var left := inset
	var top := inset
	var right := bounds.x - inset
	var bottom := bounds.y - inset
	draw_rect(Rect2(left, top, arm, thick), reticule_color)
	draw_rect(Rect2(left, top, thick, arm), reticule_color)
	draw_rect(Rect2(right - arm, top, arm, thick), reticule_color)
	draw_rect(Rect2(right - thick, top, thick, arm), reticule_color)
	draw_rect(Rect2(left, bottom - thick, arm, thick), reticule_color)
	draw_rect(Rect2(left, bottom - arm, thick, arm), reticule_color)
	draw_rect(Rect2(right - arm, bottom - thick, arm, thick), reticule_color)
	draw_rect(Rect2(right - thick, bottom - arm, thick, arm), reticule_color)
