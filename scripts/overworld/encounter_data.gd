class_name EncounterData
extends RefCounted

## Living mechs standing on the overworld battle grid join the fight.
var attacker: MechState
var participants: Array[MechState] = []
var encounter_location: Vector2i = Vector2i.ZERO
var encounter_direction: String = "from_west"
var approach_step: Vector2i = Vector2i.RIGHT
## Top-left stage cell of the fight. The tactic's seat sits on the attacker.
var field_origin: Vector2i = Vector2i.ZERO
var tactic: BattleTactic
var player_positions: Dictionary = {}
var enemy_positions: Dictionary = {}


static func direction_from_step(step: Vector2i) -> String:
	if absi(step.x) >= absi(step.y):
		if step.x > 0:
			return "from_west"
		if step.x < 0:
			return "from_east"
	if step.y > 0:
		return "from_north"
	if step.y < 0:
		return "from_south"
	return "from_west"


## Enemy fights and older callers use the Standard seat.
static func create(
	moving_unit: MechState,
	step: Vector2i,
	everyone: Array[MechState]
) -> EncounterData:
	var encounter := create_from_tactic(moving_unit, BattleTactic.standard(), everyone)
	encounter.approach_step = step
	encounter.encounter_direction = direction_from_step(step)
	encounter.encounter_location = moving_unit.overworld_position + step
	return encounter


## The rectangle is the tactic's size, slid so the acting mech sits on its seat.
static func create_from_tactic(
	moving_unit: MechState,
	chosen: BattleTactic,
	everyone: Array[MechState]
) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.attacker = moving_unit
	encounter.tactic = chosen if chosen != null else BattleTactic.standard()
	encounter.field_origin = moving_unit.overworld_position - encounter.tactic.seat
	var inside := {}
	for cell in encounter.tactic.world_cells(moving_unit.overworld_position):
		inside[cell] = true
	var nearest: MechState = null
	var nearest_distance := 999999
	for unit in everyone:
		if unit == null or not unit.alive:
			continue
		if not inside.has(unit.overworld_position):
			continue
		encounter.participants.append(unit)
		if unit.team == "player":
			encounter.player_positions[unit.id] = unit.overworld_position
		else:
			encounter.enemy_positions[unit.id] = unit.overworld_position
		if unit == moving_unit or unit.team == moving_unit.team:
			continue
		var distance := absi(unit.overworld_position.x - moving_unit.overworld_position.x)
		distance += absi(unit.overworld_position.y - moving_unit.overworld_position.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = unit
	if not encounter.participants.has(moving_unit):
		encounter.participants.append(moving_unit)
		encounter.player_positions[moving_unit.id] = moving_unit.overworld_position
	if nearest != null:
		encounter.encounter_location = nearest.overworld_position
		encounter.approach_step = nearest.overworld_position - moving_unit.overworld_position
		encounter.encounter_direction = direction_from_step(encounter.approach_step)
	else:
		encounter.encounter_location = moving_unit.overworld_position
		encounter.approach_step = Vector2i.ZERO
	return encounter
