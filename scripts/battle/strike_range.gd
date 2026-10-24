class_name StrikeRange
extends RefCounted


## Play cells this strike can hit from origin. The attacker's own cell stays plain.
static func attack_cells(origin: Vector2i, card: CardData, bounds: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if card == null or origin.x < 0 or origin.y < 0 or origin.x >= bounds.x or origin.y >= bounds.y:
		return cells
	if card.hits_front():
		var directions: Array[int] = [1, -1]
		var rises: Array[int] = [-1, 0, 1]
		for direction in directions:
			var ahead := origin + Vector2i(direction, 0)
			for rise in rises:
				var spot := ahead + Vector2i(0, rise)
				if spot.x >= 0 and spot.y >= 0 and spot.x < bounds.x and spot.y < bounds.y:
					cells.append(spot)
		return cells
	for y in bounds.y:
		for x in bounds.x:
			var coords := Vector2i(x, y)
			var distance := absi(coords.x - origin.x) + absi(coords.y - origin.y)
			if card.reaches(distance):
				cells.append(coords)
	return cells
