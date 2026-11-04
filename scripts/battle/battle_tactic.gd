class_name BattleTactic
extends RefCounted

## Seat is the acting mech's cell inside the rectangle, counted from the top-left.
## Columns run east. Rows run south. Both start at 0.
var id := ""
var display_name := ""
## Shown on the battle bonus panel info mark.
var note := ""
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
		_make("standard", "Defense", Vector2i(6, 3), Vector2i(2, 1), true, "Slightly increase \"Defense\" card pulls."),
		_make("offense", "Offense", Vector2i(6, 3), Vector2i(1, 1), true, "Slightly increase \"Offense\" card pulls."),
		_make("westward", "Westward", Vector2i(6, 3), Vector2i(4, 1), false, "The fight reaches four cells to the west."),
		_make("north", "Flank above", Vector2i(6, 3), Vector2i(2, 2), true, "You stand on the south edge, so the fight reaches two rows above you."),
		_make("south", "Flank below", Vector2i(6, 3), Vector2i(2, 0), true, "You stand on the north edge, so the fight reaches two rows below you."),
		_make("plaza", "Plaza", Vector2i(5, 5), Vector2i(2, 2), false, "A square field, two cells in every direction."),
		_make("broad", "Broad", Vector2i(5, 4), Vector2i(2, 1), false, "Five cells wide and four tall."),
		_make("deep", "Deep", Vector2i(4, 5), Vector2i(1, 2), false, "Four cells wide and five tall."),
	]


## The bonus panel names the two basic fields as tactics. The picker keeps the short name.
func line_name() -> String:
	if id == "standard":
		return "Defense tactics"
	if id == "offense":
		return "Offense tactics"
	return display_name


## Flank fights stay off the bonus panel. The bonuses still list.
func shows_on_panel() -> bool:
	return id != "north" and id != "south"


## Attack under Offense, Defense under Defense. Other fields do not tilt the draw.
func favored_card_type() -> String:
	if id == "offense":
		return "Attack"
	if id == "standard":
		return "Defense"
	return ""


## The commence mark and the battle panel share this. Empty when the field has no pull bonus.
func bonus_note() -> String:
	if favored_card_type() == "":
		return ""
	return note


static func _make(tactic_id: String, label: String, field_size: Vector2i, field_seat: Vector2i, on: bool, field_note := "") -> BattleTactic:
	var tactic := BattleTactic.new()
	tactic.id = tactic_id
	tactic.display_name = label
	tactic.note = field_note
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
