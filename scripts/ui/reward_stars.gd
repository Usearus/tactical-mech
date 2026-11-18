extends HBoxContainer

@onready var _stars: Array[CanvasItem] = [%Star1, %Star2, %Star3]


func show_count(count: int) -> void:
	var shown := clampi(count, 1, 3)
	for index in _stars.size():
		_stars[index].visible = index < shown
