class_name IsoTile
extends Node2D

@onready var _fill: Polygon2D = $Fill
@onready var _edge: Line2D = $Edge


## Matches the diamond to the Ground tileset. Points stay centered on this node.
func set_span(tile_size: Vector2i) -> void:
	var half := Vector2(tile_size) * 0.5
	var points := PackedVector2Array([
		Vector2(0, -half.y),
		Vector2(half.x, 0),
		Vector2(0, half.y),
		Vector2(-half.x, 0),
	])
	_fill.polygon = points
	var closed := points.duplicate()
	closed.append(points[0])
	_edge.points = closed


## White edge only, so the painted ground stays visible underneath.
func use_as_cursor() -> void:
	_fill.color = Color(0, 0, 0, 0)
	_edge.width = 3.0


func set_hot(hot: bool) -> void:
	z_index = 1 if hot else 0
	_fill.color = Color(0.28, 0.28, 0.28, 1) if hot else Color(0, 0, 0, 1)
	_edge.width = 3.0 if hot else 2.0
