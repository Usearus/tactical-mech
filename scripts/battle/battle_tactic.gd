class_name BattleTactic
extends RefCounted

## Seat is the acting mech's cell inside the rectangle, counted from the top-left.
## Columns run east. Rows run south. Both start at 0.
var id := ""
var display_name := ""
var size := Vector2i(6, 3)
var seat := Vector2i(2, 1)
var enabled := true


static func standard() -> BattleTactic:
	return by_id("standard")


static func by_id(tactic_id: String) -> BattleTactic:
	for tactic in catalog():
		if tactic.id == tactic_id:
			return tactic
	return null


static func enabled_list() -> Array[BattleTactic]:
	var shown: Array[BattleTactic] = []
	for tactic in catalog():
		if tactic.enabled:
			shown.append(tactic)
	return shown


## Turn a tactic off here after trying it. The picker skips disabled ones.
static func catalog() -> Array[BattleTactic]:
	return [
		_make("standard", "Defense", Vector2i(6, 3), Vector2i(2, 1), true),
		_make("offense", "Offense", Vector2i(6, 3), Vector2i(1, 1), true),
		_make("westward", "Westward", Vector2i(6, 3), Vector2i(4, 1), false),
		_make("north", "Flank above", Vector2i(6, 3), Vector2i(2, 2), true),
		_make("south", "Flank below", Vector2i(6, 3), Vector2i(2, 0), true),
		_make("plaza", "Plaza", Vector2i(5, 5), Vector2i(2, 2), false),
		_make("broad", "Broad", Vector2i(5, 4), Vector2i(2, 1), false),
		_make("deep", "Deep", Vector2i(4, 5), Vector2i(1, 2), false),
	]


static func _make(tactic_id: String, label: String, field_size: Vector2i, field_seat: Vector2i, on: bool) -> BattleTactic:
	var tactic := BattleTactic.new()
	tactic.id = tactic_id
	tactic.display_name = label
	tactic.size = field_size
	tactic.seat = field_seat
	tactic.enabled = on
	return tactic


func origin_for(mech: Vector2i) -> Vector2i:
	return mech - seat


func covers(mech: Vector2i, cell: Vector2i) -> bool:
	var local := cell - origin_for(mech)
	return local.x >= 0 and local.y >= 0 and local.x < size.x and local.y < size.y


## Stage cells inside the rectangle. Cells past the map edge are left out.
func world_cells(mech: Vector2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var origin := origin_for(mech)
	for y in size.y:
		for x in size.x:
			var coords := origin + Vector2i(x, y)
			if StageMap.contains(coords):
				cells.append(coords)
	return cells
