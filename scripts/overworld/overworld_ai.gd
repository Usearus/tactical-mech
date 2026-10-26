class_name OverworldAi
extends RefCounted

## Overworld enemy turn. Each enemy walks orthogonally toward the nearest
## player and stops on a cell it can attack from. A grunt holds just outside
## that reach, and steps in only when another enemy can attack that same
## player or is already standing in the fight that shot would open. A boss,
## and the last living enemy, step in alone. A player can pass through other
## players. Neither team can enter a cell held by the other.

const STEPS: Array[Vector2i] = [
	Vector2i.RIGHT,
	Vector2i.LEFT,
	Vector2i.DOWN,
	Vector2i.UP,
]


## Plans one enemy move without changing the map. The path stops at another mech.
static func plan_enemy_move(
	unit: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> Dictionary:
	var steps_in := _steps_in(unit, everyone, map_size)
	return {"path": _path(unit, everyone, map_size, steps_in)}


## The player this enemy can open on. A cell in its attack band wins.
## A player on the next cell still counts when that band starts farther out.
static func prey(unit: MechState, everyone: Array[MechState]) -> MechState:
	if unit == null:
		return null
	var closest: MechState = null
	var closest_distance := 999999
	for other in everyone:
		if other == null or not other.alive or other.team != "player":
			continue
		var distance := _manhattan(unit.overworld_position, other.overworld_position)
		if not unit.attacks_at(distance) or distance >= closest_distance:
			continue
		closest = other
		closest_distance = distance
	if closest != null:
		return closest
	return _adjacent_player(unit, everyone)


## Standard when it already covers the target. Otherwise the first enabled
## tactic that does, so a shot from two cells still brings that player in.
static func tactic_for(from_cell: Vector2i, prey_cell: Vector2i) -> BattleTactic:
	var usual := BattleTactic.standard()
	if usual != null and usual.covers(from_cell, prey_cell):
		return usual
	for tactic in BattleTactic.enabled_list():
		if tactic != null and tactic.covers(from_cell, prey_cell):
			return tactic
	return usual


static func _path(
	unit: MechState,
	everyone: Array[MechState],
	map_size: Vector2i,
	steps_in: bool
) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if unit == null:
		return path
	var cursor := unit.overworld_position
	var steps_left := unit.move_range
	while steps_left > 0:
		var target := _nearest_player_from(cursor, everyone)
		if target == null:
			break
		var next := _step_toward(cursor, target.overworld_position, everyone, map_size)
		if next == cursor:
			break
		if _unit_at(next, everyone) != null:
			break
		var distance := _manhattan(next, target.overworld_position)
		if unit.attacks_at(distance):
			if not steps_in:
				break
			path.append(next)
			break
		if distance < unit.attack_range_min:
			break
		if not steps_in and _attacks_any_player_from(unit, next, everyone):
			break
		path.append(next)
		cursor = next
		steps_left -= 1
	while not path.is_empty() and _unit_at(path[path.size() - 1], everyone) != null:
		path.pop_back()
	return path


static func _is_boss(unit: MechState) -> bool:
	return unit != null and unit.data != null and unit.data.id.contains("boss")


## Bosses and a sole survivor close to attack range. A grunt needs a partner
## who can attack that same player, or one already standing in the shot.
static func _steps_in(
	unit: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> bool:
	if _is_boss(unit) or _living_enemies(everyone) <= 1:
		return true
	var target := _nearest_player_from(unit.overworld_position, everyone)
	if target == null:
		return false
	for other in everyone:
		if other == null or other == unit or not other.alive or other.team != "enemy":
			continue
		if _can_reach_player(other, target, everyone, map_size):
			return true
	var shot := _shot_cell(unit, everyone, map_size)
	if not _attacks_player_from(unit, shot, target):
		return false
	return _enemy_in_fight(unit, shot, target.overworld_position, everyone)


## Where this mech would stand if it closed to attack range this turn.
static func _shot_cell(
	unit: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> Vector2i:
	var path := _path(unit, everyone, map_size, true)
	if path.is_empty():
		return unit.overworld_position
	return path[path.size() - 1]


## Already in its own attack range, or able to get there with the move left.
## An enemy who has already acted can only count when they are already there.
static func _can_reach_player(
	unit: MechState,
	player: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> bool:
	if _attacks_player_from(unit, unit.overworld_position, player):
		return true
	if unit.has_moved:
		return false
	var distances := reachable(unit, everyone, map_size)
	for raw in distances:
		var cell: Vector2i = raw
		if _attacks_player_from(unit, cell, player):
			return true
	return false


## True when another living enemy already stands in the fight this shot opens.
static func _enemy_in_fight(
	unit: MechState,
	firing_cell: Vector2i,
	prey_cell: Vector2i,
	everyone: Array[MechState]
) -> bool:
	var tactic := tactic_for(firing_cell, prey_cell)
	if tactic == null or not tactic.covers(firing_cell, prey_cell):
		return false
	for other in everyone:
		if other == null or other == unit or not other.alive or other.team != "enemy":
			continue
		if not StageMap.contains(other.overworld_position):
			continue
		if tactic.covers(firing_cell, other.overworld_position):
			return true
	return false


static func _living_enemies(everyone: Array[MechState]) -> int:
	var count := 0
	for unit in everyone:
		if unit != null and unit.alive and unit.team == "enemy":
			count += 1
	return count


static func _attacks_player_from(unit: MechState, cell: Vector2i, player: MechState) -> bool:
	if unit == null or player == null:
		return false
	return unit.attacks_at(_manhattan(cell, player.overworld_position))


static func _attacks_any_player_from(unit: MechState, cell: Vector2i, everyone: Array[MechState]) -> bool:
	for other in everyone:
		if other == null or not other.alive or other.team != "player":
			continue
		if _attacks_player_from(unit, cell, other):
			return true
	return false


static func _adjacent_player(unit: MechState, everyone: Array[MechState]) -> MechState:
	if unit == null:
		return null
	for step in STEPS:
		var other := _unit_at(unit.overworld_position + step, everyone)
		if other != null and other.alive and other.team == "player":
			return other
	return null


static func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


static func path_from_distances(origin: Vector2i, destination: Vector2i, distances: Dictionary) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	if origin == destination or not distances.has(destination):
		return path
	var cursor := destination
	while cursor != origin:
		path.append(cursor)
		var previous := cursor
		for step in STEPS:
			var candidate: Vector2i = cursor - step
			if distances.has(candidate) and int(distances[candidate]) == int(distances[cursor]) - 1:
				previous = candidate
				break
		if previous == cursor:
			break
		cursor = previous
	path.reverse()
	return path


## Cells inside `allowed` that can be reached from `origin`. Players may cross
## other players. An opposing mech still blocks the cell.
static func reachable_within(
	origin: Vector2i,
	allowed: Dictionary,
	everyone: Array[MechState],
	mover: MechState,
	map_size: Vector2i
) -> Dictionary:
	var distances := {origin: 0}
	if not allowed.has(origin):
		return distances
	var queue: Array[Vector2i] = [origin]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for step in STEPS:
			var next: Vector2i = current + step
			if distances.has(next) or not allowed.has(next):
				continue
			if not _in_bounds(next, map_size) or StageMap.blocked(next):
				continue
			if _blocked_by_mech(next, mover, everyone):
				continue
			distances[next] = int(distances[current]) + 1
			queue.append(next)
	return distances


## Cells within attack range of any cell in `standable`.
## `standable` includes where the unit already stands. Its own cell is left out,
## and rubble is left out, since nobody can be standing there.
static func threat_zone(standable: Dictionary, attack_range: int, home: Vector2i) -> Dictionary:
	var cells := {}
	var reach := maxi(attack_range, 1)
	for raw in standable:
		var origin: Vector2i = raw
		for y in range(-reach, reach + 1):
			var span := reach - absi(y)
			for x in range(-span, span + 1):
				if x == 0 and y == 0:
					continue
				var coords := origin + Vector2i(x, y)
				if coords == home or not StageMap.contains(coords) or StageMap.blocked(coords):
					continue
				cells[coords] = true
	return cells


## Cells the unit can enter. A player path may cross another player, and still
## cannot enter an enemy. The mover's own cell does not count.
static func reachable(unit: MechState, everyone: Array[MechState], map_size: Vector2i) -> Dictionary:
	var distances := {unit.overworld_position: 0}
	var queue: Array[Vector2i] = [unit.overworld_position]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		var distance: int = distances[current]
		if distance >= unit.move_range:
			continue
		for step in STEPS:
			var next: Vector2i = current + step
			if distances.has(next) or not _in_bounds(next, map_size):
				continue
			if StageMap.blocked(next) or _blocked_by_mech(next, unit, everyone):
				continue
			distances[next] = distance + 1
			queue.append(next)
	return distances


static func _nearest_player_from(origin: Vector2i, everyone: Array[MechState]) -> MechState:
	var nearest: MechState = null
	var nearest_distance := 999999
	for other in everyone:
		if other == null or not other.alive or other.team != "player":
			continue
		var distance := absi(other.overworld_position.x - origin.x) + absi(other.overworld_position.y - origin.y)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = other
	return nearest


static func _step_toward(
	origin: Vector2i,
	target: Vector2i,
	everyone: Array[MechState],
	map_size: Vector2i
) -> Vector2i:
	var options: Array[Vector2i] = []
	if target.x != origin.x:
		options.append(origin + Vector2i(signi(target.x - origin.x), 0))
	if target.y != origin.y:
		options.append(origin + Vector2i(0, signi(target.y - origin.y)))
	options.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da := absi(a.x - target.x) + absi(a.y - target.y)
		var db := absi(b.x - target.x) + absi(b.y - target.y)
		return da < db
	)
	for coords in options:
		if not _in_bounds(coords, map_size) or StageMap.blocked(coords):
			continue
		if _unit_at(coords, everyone) != null:
			continue
		return coords
	return origin


## An opposing mech blocks the cell. A player can pass through another player.
static func _blocked_by_mech(coords: Vector2i, mover: MechState, everyone: Array[MechState]) -> bool:
	var unit := _unit_at(coords, everyone)
	if unit == null or unit == mover:
		return false
	return mover == null or mover.team != "player" or unit.team != "player"


static func _unit_at(coords: Vector2i, everyone: Array[MechState]) -> MechState:
	for unit in everyone:
		if unit != null and unit.alive and unit.overworld_position == coords:
			return unit
	return null


static func _in_bounds(coords: Vector2i, _map_size: Vector2i) -> bool:
	return StageMap.contains(coords)
