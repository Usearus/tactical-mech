class_name EnemyAi
extends RefCounted

## The cell this unit would step to, and the player they could strike from there.
## The battle pans to the unit, then plays the step. This does not move them.
static func act(unit: MechState, state: BattleState, card: CardData) -> Dictionary:
	var here := Vector2i(-1, -1)
	if unit != null and state != null:
		here = state.position_of(unit)
	var plan := {"step": here, "target": null}
	if unit == null or state == null or not unit.alive or card == null:
		return plan
	var target := _nearest_player(unit, state)
	if target == null:
		return plan
	var my_pos := state.position_of(unit)
	var target_pos := state.position_of(target)
	var step := my_pos
	if _manhattan(my_pos, target_pos) > card.reach:
		var next := _step_toward(my_pos, target_pos, state)
		if next != my_pos:
			step = next
	plan["step"] = step
	if _manhattan(step, target_pos) <= card.reach and target.alive:
		plan["target"] = target
	return plan


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
