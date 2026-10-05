extends Control
class_name CellMark

var stroke_color := Color(0, 0, 0, 0)
var stroke_left := false
var stroke_top := false
var stroke_right := false
var stroke_bottom := false
var reticule_color := Color(0, 0, 0, 0)


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = 0.0
	resized.connect(queue_redraw)


func show_stroke(color: Color, left: bool, top: bool, right: bool, bottom: bool) -> void:
	stroke_color = color
	stroke_left = left
	stroke_top = top
	stroke_right = right
	stroke_bottom = bottom
	queue_redraw()


func show_reticule(color: Color) -> void:
	reticule_color = color
	queue_redraw()


func clear_marks() -> void:
	stroke_color.a = 0.0
	reticule_color.a = 0.0
	stroke_left = false
	stroke_top = false
	stroke_right = false
	stroke_bottom = false
	queue_redraw()


func _draw() -> void:
	var bounds := size
	if bounds.x < 4.0 or bounds.y < 4.0:
		return
	var width := 4.0
	if stroke_color.a > 0.0:
		if stroke_left:
			draw_rect(Rect2(0.0, 0.0, width, bounds.y), stroke_color)
		if stroke_right:
			draw_rect(Rect2(bounds.x - width, 0.0, width, bounds.y), stroke_color)
		if stroke_top:
			draw_rect(Rect2(0.0, 0.0, bounds.x, width), stroke_color)
		if stroke_bottom:
			draw_rect(Rect2(0.0, bounds.y - width, bounds.x, width), stroke_color)
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
