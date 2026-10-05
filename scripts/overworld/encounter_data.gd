class_name EncounterData
extends RefCounted

## Living mechs standing on the overworld battle grid join the fight.
var attacker: MechState
var participants: Array[MechState] = []
var encounter_location: Vector2i = Vector2i.ZERO
var encounter_direction: String = "from_west"
var approach_step: Vector2i = Vector2i.RIGHT
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


static func create(
	moving_unit: MechState,
	step: Vector2i,
	everyone: Array[MechState]
) -> EncounterData:
	var encounter := EncounterData.new()
	encounter.attacker = moving_unit
	encounter.approach_step = step
	encounter.encounter_direction = direction_from_step(step)
	encounter.encounter_location = moving_unit.overworld_position + step
	var window := BattleDeployment.overworld_cells(
		moving_unit.overworld_position,
		encounter.encounter_location,
		StageMap.bounds.size
	)
	var inside := {}
	for cell in window:
		inside[cell] = true
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
	if not encounter.participants.has(moving_unit):
		encounter.participants.append(moving_unit)
		encounter.player_positions[moving_unit.id] = moving_unit.overworld_position
	return encounter
