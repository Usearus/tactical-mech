class_name BattleDeployment
extends RefCounted

## Fights without a tactic use 3 rows by 6 columns.
const WIDE := Vector2i(6, 3)
## Scenery cells drawn around the playable board. Two on every side makes a 10 by 7 view.
const VIEW_MARGIN := 2
## D2 on the wide board when the attacker stands to the west. The pair then fills C2 and D2.
const WIDE_EAST := Vector2i(3, 1)
## C2 when the attacker stands to the east, so that pair still fills C2 and D2.
const WIDE_WEST := Vector2i(2, 1)


## Two overworld tiles past every edge, including a tactic fight, so the board shows the street beyond the rectangle.
static func view_margin(_encounter: EncounterData = null) -> int:
	return VIEW_MARGIN


## Tactic fights use that tactic's size. Anything else stays 6 by 3.
static func grid_size(encounter: EncounterData = null) -> Vector2i:
	if encounter != null and encounter.tactic != null:
		return encounter.tactic.size
	return WIDE


## Playable board plus the scenery ring. The ring is not part of the fight.
static func view_size(encounter: EncounterData = null) -> Vector2i:
	var margin := view_margin(encounter)
	return grid_size(encounter) + Vector2i(margin, margin) * 2


## Battle-board cell under a view cell. Negative when the view cell is in the ring.
static func play_cell(view_cell: Vector2i, encounter: EncounterData = null) -> Vector2i:
	var margin := view_margin(encounter)
	return view_cell - Vector2i(margin, margin)


static func is_play_cell(view_cell: Vector2i, encounter: EncounterData = null) -> bool:
	var play := play_cell(view_cell, encounter)
	var size := grid_size(encounter)
	return play.x >= 0 and play.y >= 0 and play.x < size.x and play.y < size.y


## Stage cell drawn at this view cell, including the ring. Off the stage when the fight is at the edge.
static func overworld_cell_for_view(encounter: EncounterData, view_cell: Vector2i) -> Vector2i:
	return overworld_cell_for(encounter, play_cell(view_cell, encounter))


## View cell for a stage cell. Outside the 10 by 7 when that mech is beyond the ring.
static func view_cell_for_overworld(encounter: EncounterData, world: Vector2i) -> Vector2i:
	if encounter == null or encounter.attacker == null:
		return Vector2i(-1, -1)
	var layout := _battle_layout(encounter)
	var origin: Vector2i = layout["origin"]
	var margin := view_margin(encounter)
	return world - origin + Vector2i(margin, margin)


## Overworld cells the battle camera zooms in from. An east-west pair sits on C2 and D2.
static func overworld_cells(from_pos: Vector2i, to_pos: Vector2i, _map_size: Vector2i) -> Array[Vector2i]:
	var origin: Vector2i = _layout_from(from_pos, to_pos)["origin"]
	var cells: Array[Vector2i] = []
	for y in WIDE.y:
		for x in WIDE.x:
			var coords := origin + Vector2i(x, y)
			if not StageMap.contains(coords):
				continue
			cells.append(coords)
	return cells


## Stage pixel mapped onto the terrain stamp, in that node's local pixels.
static func terrain_point(encounter: EncounterData, stage_pixel: Vector2, mech_px: Vector2) -> Vector2:
	var layout := _battle_layout(encounter)
	var origin: Vector2i = layout["origin"]
	var battle := stage_pixel / mech_px - Vector2(origin)
	var margin := float(view_margin(encounter))
	return (battle + Vector2(margin, margin)) * mech_px


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
	var layout := _battle_layout(encounter)
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


## Top-left stage cell of this fight. Tactic fights store it. Older fights derive it.
static func window_origin(encounter: EncounterData) -> Vector2i:
	if encounter != null and encounter.tactic != null:
		return encounter.field_origin
	if encounter == null or encounter.attacker == null:
		return Vector2i.ZERO
	return _battle_layout(encounter)["origin"]


## Stage cells in the fight. Off-map cells are left out.
static func stage_cells(encounter: EncounterData) -> Array[Vector2i]:
	if encounter != null and encounter.tactic != null and encounter.attacker != null:
		return encounter.tactic.world_cells(encounter.attacker.overworld_position)
	if encounter == null or encounter.attacker == null:
		var none: Array[Vector2i] = []
		return none
	var other := encounter.attacker.overworld_position + encounter.approach_step
	return overworld_cells(encounter.attacker.overworld_position, other, StageMap.bounds.size)


## Inverse of place(). A tactic fight is the rectangle around the attacker's seat.
static func _battle_layout(encounter: EncounterData) -> Dictionary:
	var attacker: MechState = encounter.attacker
	if encounter.tactic != null and attacker != null:
		return {
			"origin": encounter.field_origin,
			"from": attacker.overworld_position,
			"to": attacker.overworld_position,
		}
	var defender := _defender(encounter)
	var other_pos := attacker.overworld_position + encounter.approach_step
	if defender != null:
		other_pos = defender.overworld_position
	return _layout_from(attacker.overworld_position, other_pos)


static func _overworld_from_layout(layout: Dictionary, battle_cell: Vector2i) -> Vector2i:
	var origin: Vector2i = layout["origin"]
	return origin + battle_cell


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


## Puts an east-west pair on C2 and D2. A target west of its attacker is anchored on C2.
## Everyone else keeps their offset from that mech.
static func _layout_from(from_pos: Vector2i, to_pos: Vector2i) -> Dictionary:
	var anchor := WIDE_WEST if from_pos.x > to_pos.x else WIDE_EAST
	return {
		"origin": to_pos - anchor,
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
	var order: Array[MechState] = []
	if defender != null:
		order.append(defender)
	if attacker != defender:
		order.append(attacker)
	for unit in encounter.participants:
		if unit != null and not order.has(unit):
			order.append(unit)
	for unit in order:
		var desired := unit.overworld_position - origin
		var cell := _nearest_free(desired, grid, occupied)
		_claim(unit, cell, placed, occupied, grid)
	if defender != null and defender != attacker and placed.has(attacker.id) and placed.has(defender.id):
		var attacker_at: Vector2i = placed[attacker.id]
		var defender_at: Vector2i = placed[defender.id]
		attacker.face_toward_x(float(attacker_at.x), float(defender_at.x))
		defender.face_toward_x(float(defender_at.x), float(attacker_at.x))


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
