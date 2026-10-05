class_name BattleState
extends RefCounted

var grid: BattleGrid
var units: Array[MechState] = []
var turn: int = 1
var phase: String = "player"
## Which side acts first each round. The side that opened the fight.
var initiative: String = "player"
var active_unit_id: String = ""
var winner: String = ""
var battle_status: String = "active"
var positions: Dictionary = {}
var moved: Dictionary = {}
var attacked: Dictionary = {}


func unit_by_id(unit_id: String) -> MechState:
	for unit in units:
		if unit.id == unit_id:
			return unit
	return null


func position_of(unit: MechState) -> Vector2i:
	return positions.get(unit.id, Vector2i(-1, -1))


func living_units(team_name: String) -> Array[MechState]:
	var found: Array[MechState] = []
	for unit in units:
		if unit.alive and unit.team == team_name:
			found.append(unit)
	return found


func sync_occupants() -> void:
	grid.clear_occupants()
	for unit in units:
		if not unit.alive:
			continue
		var coords: Vector2i = positions[unit.id]
		var cell := grid.cell_at(coords)
		if cell != null:
			cell.occupant_id = unit.id


func move_unit(unit: MechState, coords: Vector2i) -> void:
	positions[unit.id] = coords
	moved[unit.id] = true
	sync_occupants()


func mark_attacked(unit: MechState) -> void:
	attacked[unit.id] = true
	moved[unit.id] = true


func reset_round_actions() -> void:
	moved.clear()
	attacked.clear()


func check_outcome() -> void:
	if battle_status != "active":
		return
	if living_units("enemy").is_empty():
		battle_status = "victory"
		winner = "player"
		phase = "resolved"
	elif living_units("player").is_empty():
		battle_status = "defeat"
		winner = "enemy"
		phase = "resolved"
