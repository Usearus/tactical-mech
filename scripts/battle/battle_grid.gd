class_name BattleGrid
extends RefCounted

var width: int = 6
var height: int = 3
var cells: Array[BattleCell] = []


static func create(grid_width: int = 6, grid_height: int = 3) -> BattleGrid:
	var grid := BattleGrid.new()
	grid.width = grid_width
	grid.height = grid_height
	grid.cells.clear()
	for y in grid_height:
		for x in grid_width:
			var cell := BattleCell.new()
			cell.coords = Vector2i(x, y)
			grid.cells.append(cell)
	return grid


func in_bounds(coords: Vector2i) -> bool:
	return coords.x >= 0 and coords.y >= 0 and coords.x < width and coords.y < height


func cell_at(coords: Vector2i) -> BattleCell:
	if not in_bounds(coords):
		return null
	return cells[coords.y * width + coords.x]


func clear_occupants() -> void:
	for cell in cells:
		cell.occupant_id = ""


func impassable(coords: Vector2i) -> bool:
	var cell := cell_at(coords)
	return cell == null or cell.is_solid()


func occupant_at(coords: Vector2i) -> String:
	var cell := cell_at(coords)
	if cell == null:
		return ""
	return cell.occupant_id


static func coord_name(coords: Vector2i) -> String:
	if coords.y < 0 or coords.y > 25:
		return str(coords)
	var row := char(65 + coords.y)
	return "%s%d" % [row, coords.x + 1]
