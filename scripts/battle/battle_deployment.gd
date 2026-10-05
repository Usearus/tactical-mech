class_name BattleDeployment
extends RefCounted

## Side-by-side fights use 3 rows by 6 columns.
const WIDE := Vector2i(6, 3)
## Fights stacked north to south use 3 columns by 6 rows.
const TALL := Vector2i(3, 6)
## D2 on the wide board. The mech being attacked always stands here.
const WIDE_EAST := Vector2i(3, 1)
## Tall-board cells that rotate onto D2. North when the target is above the attacker.
const TALL_NORTH := Vector2i(1, 2)
const TALL_SOUTH := Vector2i(1, 3)


## The battle board is always horizontal. A north-south fight is rotated onto it.
static func grid_size(_encounter: EncounterData) -> Vector2i:
	return WIDE


## Footprint on the overworld. North-south fights stay tall here.
static func window_size(from_pos: Vector2i, to_pos: Vector2i) -> Vector2i:
	return TALL if _vertical(from_pos, to_pos) else WIDE


## Overworld cells the battle camera zooms in from. The mech being attacked is on D2.
static func overworld_cells(from_pos: Vector2i, to_pos: Vector2i, _map_size: Vector2i) -> Array[Vector2i]:
	var size := window_size(from_pos, to_pos)
	var origin: Vector2i = _layout_from(from_pos, to_pos)["origin"]
	var cells: Array[Vector2i] = []
	for y in size.y:
		for x in size.x:
			var coords := origin + Vector2i(x, y)
			if not StageMap.contains(coords):
				continue
			cells.append(coords)
	return cells


## 1 when a north-south patch is turned clockwise onto the board, -1 when turned the other way.
static func terrain_quarter(encounter: EncounterData) -> int:
	if encounter == null or encounter.attacker == null:
		return 0
	var layout := _battle_layout(encounter)
	if not bool(layout["vertical"]):
		return 0
	return 1 if bool(layout["clockwise"]) else -1


## Overworld cell this battle cell was cut from. Off the map when the window hangs past the stage.
static func overworld_cell_for(encounter: EncounterData, battle_cell: Vector2i) -> Vector2i:
	if encounter == null or encounter.attacker == null:
		return Vector2i(-1, -1)
	return _overworld_from_layout(_battle_layout(encounter), battle_cell)


## Stage tiles with collision stay solid on the battle board.
static func stamp_solids(encounter: EncounterData, grid: BattleGrid) -> void:
	if grid == null:
		return
	for cell in grid.cells:
		var world := overworld_cell_for(encounter, cell.coords)
		if StageMap.blocked(world):
			cell.terrain_type = "solid"


static func place(encounter: EncounterData, grid: BattleGrid) -> Dictionary:
	stamp_solids(encounter, grid)
	var occupied := {}
	var placed := {}
	var attacker: MechState = encounter.attacker
	if attacker == null:
		return placed
	var defender := _defender(encounter)
	var other_pos := attacker.overworld_position + encounter.approach_step
	if defender != null:
		other_pos = defender.overworld_position
	var layout := _layout_from(attacker.overworld_position, other_pos)
	_place_from_layout(encounter, attacker, defender, layout, placed, occupied, grid)
	return placed


## Puts each fighter on the overworld cell their battle cell was cut from.
## Reads pre-battle positions, so call this before those cells are overwritten.
static func commit_to_overworld(
	encounter: EncounterData,
	battle_positions: Dictionary,
	everyone: Array[MechState],
	map_size: Vector2i
) -> void:
	if encounter == null or encounter.attacker == null or battle_positions.is_empty():
		return
	var layout := _battle_layout(encounter)
	var desired_at := {}
	for unit in encounter.participants:
		if unit == null or not battle_positions.has(unit.id):
			continue
		desired_at[unit.id] = _overworld_from_layout(layout, battle_positions[unit.id])
	if desired_at.is_empty():
		return
	var claimed := {}
	for unit in everyone:
		if unit == null or not unit.alive or desired_at.has(unit.id):
			continue
		claimed[unit.overworld_position] = true
	var parked: Array[MechState] = []
	for unit in encounter.participants:
		if unit == null or not unit.alive or not desired_at.has(unit.id):
			continue
		var desired: Vector2i = desired_at[unit.id]
		if _on_map(desired, map_size) and not claimed.has(desired) and not StageMap.blocked(desired):
			claimed[desired] = true
			unit.overworld_position = desired
		else:
			parked.append(unit)
	var from_pos: Vector2i = layout["from"]
	var to_pos: Vector2i = layout["to"]
	for unit in parked:
		var desired: Vector2i = desired_at[unit.id]
		var landing := _nearest_open(desired, map_size, claimed, from_pos, to_pos)
		if landing.x < 0:
			continue
		claimed[landing] = true
		unit.overworld_position = landing
	for unit in encounter.participants:
		if unit == null or unit.alive or not desired_at.has(unit.id):
			continue
		var fallen: Vector2i = desired_at[unit.id]
		if _on_map(fallen, map_size) and not claimed.has(fallen):
			claimed[fallen] = true
			unit.overworld_position = fallen


## Inverse of place(). A north-south patch was turned sideways for the battle board.
static func _battle_layout(encounter: EncounterData) -> Dictionary:
	var attacker: MechState = encounter.attacker
	var defender := _defender(encounter)
	var other_pos := attacker.overworld_position + encounter.approach_step
	if defender != null:
		other_pos = defender.overworld_position
	return _layout_from(attacker.overworld_position, other_pos)


static func _overworld_from_layout(layout: Dictionary, battle_cell: Vector2i) -> Vector2i:
	var origin: Vector2i = layout["origin"]
	if not bool(layout["vertical"]):
		return origin + battle_cell
	return origin + _unrotate_tall(battle_cell, bool(layout["clockwise"]))


static func _unrotate_tall(battle_cell: Vector2i, clockwise: bool) -> Vector2i:
	if clockwise:
		return Vector2i(battle_cell.y, (TALL.y - 1) - battle_cell.x)
	return Vector2i((TALL.x - 1) - battle_cell.y, battle_cell.x)


static func _on_map(coords: Vector2i, _map_size: Vector2i) -> bool:
	return StageMap.contains(coords)


## Off-map battle cells have no overworld tile. Land on the nearest free cell instead.
static func _nearest_open(
	desired: Vector2i,
	map_size: Vector2i,
	claimed: Dictionary,
	from_pos: Vector2i,
	to_pos: Vector2i
) -> Vector2i:
	var window := {}
	for cell in overworld_cells(from_pos, to_pos, map_size):
		window[cell] = true
	var best := Vector2i(-1, -1)
	var best_score := 999999
	var rect := StageMap.bounds
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coords := Vector2i(x, y)
			if claimed.has(coords) or StageMap.blocked(coords):
				continue
			var score := absi(coords.x - desired.x) + absi(coords.y - desired.y)
			if not window.has(coords):
				score += 40
			if score < best_score:
				best_score = score
				best = coords
	return best


## Puts the mech being attacked on D2. Everyone else keeps their offset from that mech.
static func _layout_from(from_pos: Vector2i, to_pos: Vector2i) -> Dictionary:
	var vertical := _vertical(from_pos, to_pos)
	var clockwise := vertical and to_pos.y < from_pos.y
	var anchor := WIDE_EAST
	if vertical and clockwise:
		anchor = TALL_NORTH
	elif vertical:
		anchor = TALL_SOUTH
	var origin := to_pos - anchor
	return {
		"vertical": vertical,
		"clockwise": clockwise,
		"origin": origin,
		"from": from_pos,
		"to": to_pos,
	}


static func _place_from_layout(
	encounter: EncounterData,
	attacker: MechState,
	defender: MechState,
	layout: Dictionary,
	placed: Dictionary,
	occupied: Dictionary,
	grid: BattleGrid
) -> void:
	var origin: Vector2i = layout["origin"]
	var vertical := bool(layout["vertical"])
	var clockwise := bool(layout["clockwise"])
	var order: Array[MechState] = []
	if defender != null:
		order.append(defender)
	if attacker != defender:
		order.append(attacker)
	for unit in encounter.participants:
		if unit != null and not order.has(unit):
			order.append(unit)
	for unit in order:
		var local := unit.overworld_position - origin
		var desired := local
		if vertical:
			desired = _rotate_tall(local, clockwise)
		var cell := _nearest_free(desired, grid, occupied)
		_claim(unit, cell, placed, occupied, grid)
	if defender != null and defender != attacker and placed.has(attacker.id) and placed.has(defender.id):
		var attacker_at: Vector2i = placed[attacker.id]
		var defender_at: Vector2i = placed[defender.id]
		attacker.face_toward_x(float(attacker_at.x), float(defender_at.x))
		defender.face_toward_x(float(defender_at.x), float(attacker_at.x))


static func _rotate_tall(local: Vector2i, clockwise: bool) -> Vector2i:
	if clockwise:
		return Vector2i((TALL.y - 1) - local.y, local.x)
	return Vector2i(local.y, (TALL.x - 1) - local.x)


static func _vertical(a: Vector2i, b: Vector2i) -> bool:
	return a.x == b.x and a.y != b.y


static func _defender(encounter: EncounterData) -> MechState:
	for unit in encounter.participants:
		if unit != null and unit.overworld_position == encounter.encounter_location:
			return unit
	return null


static func _claim(
	unit: MechState,
	coords: Vector2i,
	placed: Dictionary,
	occupied: Dictionary,
	grid: BattleGrid
) -> void:
	placed[unit.id] = coords
	occupied[coords] = true
	var cell := grid.cell_at(coords)
	if cell != null:
		cell.occupant_id = unit.id


static func _nearest_free(desired: Vector2i, grid: BattleGrid, occupied: Dictionary) -> Vector2i:
	if grid.in_bounds(desired) and not occupied.has(desired) and not grid.impassable(desired):
		return desired
	var best := Vector2i.ZERO
	var best_distance := 999999
	var found := false
	for y in grid.height:
		for x in grid.width:
			var coords := Vector2i(x, y)
			if occupied.has(coords) or grid.impassable(coords):
				continue
			var distance := absi(coords.x - desired.x) + absi(coords.y - desired.y)
			if distance < best_distance:
				best_distance = distance
				best = coords
				found = true
	if not found:
		return Vector2i.ZERO
	return best
