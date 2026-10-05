class_name EnemyAi
extends RefCounted

## Moves toward the nearest player. Returns that player when this unit can attack,
## without resolving the hit, so the battle can play the attack animation first.
static func act(unit: MechState, state: BattleState, card: CardData) -> MechState:
	if not unit.alive or card == null:
		return null
	var target := _nearest_player(unit, state)
	if target == null:
		return null
	var my_pos := state.position_of(unit)
	var target_pos := state.position_of(target)
	if _manhattan(my_pos, target_pos) > card.reach:
		var step := _step_toward(my_pos, target_pos, state)
		if step != my_pos:
			unit.face_toward_x(my_pos.x, step.x)
			state.move_unit(unit, step)
			my_pos = step
	target_pos = state.position_of(target)
	if _manhattan(my_pos, target_pos) <= card.reach and target.alive:
		unit.face_toward_x(my_pos.x, target_pos.x)
		return target
	state.check_outcome()
	return null


static func _nearest_player(unit: MechState, state: BattleState) -> MechState:
	var nearest: MechState = null
	var nearest_distance := 999999
	var origin := state.position_of(unit)
	for player in state.living_units("player"):
		var distance := _manhattan(origin, state.position_of(player))
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = player
	return nearest


static func _step_toward(origin: Vector2i, target: Vector2i, state: BattleState) -> Vector2i:
	var options: Array[Vector2i] = []
	if target.x != origin.x:
		options.append(origin + Vector2i(signi(target.x - origin.x), 0))
	if target.y != origin.y:
		options.append(origin + Vector2i(0, signi(target.y - origin.y)))
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return _manhattan(a, target) < _manhattan(b, target)
	)
	for coords in options:
		if not state.grid.in_bounds(coords) or state.grid.impassable(coords):
			continue
		if state.grid.occupant_at(coords) != "":
			continue
		return coords
	return origin


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
