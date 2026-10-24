class_name SquadPlacement
extends RefCounted

const SeatAssignScript := preload("res://scripts/overworld/seat_assign.gd")

var seats: Array[Vector2i] = []


func is_seat(coords: Vector2i) -> bool:
	return seats.has(coords)


func all_seated(units: Array[MechState]) -> bool:
	if units.is_empty():
		return false
	for unit in units:
		if unit == null or not is_seat(unit.overworld_position):
			return false
	return true


## Move onto a starting square. An occupied square swaps, and a mech that came from the tray sends the occupant back there.
func drop_on_seat(unit: MechState, coords: Vector2i, occupant: MechState) -> bool:
	if unit == null or not is_seat(coords):
		return false
	if occupant != null and occupant != unit and occupant.team != "player":
		return false
	if occupant == unit:
		return true
	var from := unit.overworld_position
	if occupant != null:
		occupant.overworld_position = from if is_seat(from) else StartingRoster.UNPLACED
	unit.overworld_position = coords
	return true


func return_to_bench(unit: MechState) -> void:
	if unit == null:
		return
	unit.overworld_position = StartingRoster.UNPLACED


## Puts every mech on a different starting square. Extra mechs stay in the window.
func auto_place(units: Array[MechState], rng: RandomNumberGenerator = null) -> void:
	SeatAssignScript.auto_place(units, seats, StartingRoster.UNPLACED, rng)
