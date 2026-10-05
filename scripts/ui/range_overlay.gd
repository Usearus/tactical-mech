extends Node2D
class_name RangeOverlay

var _buttons: Dictionary = {}
var _cells: Dictionary = {}
var _color := Color(0, 0, 0, 0)


func show_outline(buttons: Dictionary, cells: Dictionary, color: Color) -> void:
	_buttons = buttons
	_cells = cells
	_color = color
	queue_redraw()


func _draw() -> void:
	if _color.a <= 0.0 or _cells.is_empty():
		return
	var width := 4.0
	for raw in _cells:
		var coords: Vector2i = raw
		var button := _buttons.get(coords) as Button
		if button == null:
			continue
		var origin := button.position
		var area := button.size
		if not _cells.has(coords + Vector2i.LEFT):
			draw_rect(Rect2(origin, Vector2(width, area.y)), _color)
		if not _cells.has(coords + Vector2i.RIGHT):
			draw_rect(Rect2(origin + Vector2(area.x - width, 0.0), Vector2(width, area.y)), _color)
		if not _cells.has(coords + Vector2i.UP):
			draw_rect(Rect2(origin, Vector2(area.x, width)), _color)
		if not _cells.has(coords + Vector2i.DOWN):
			draw_rect(Rect2(origin + Vector2(0.0, area.y - width), Vector2(area.x, width)), _color)
