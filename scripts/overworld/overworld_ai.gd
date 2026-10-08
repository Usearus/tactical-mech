class_name OverworldAi
extends RefCounted

## Overworld enemy turn. Each enemy walks orthogonally toward the nearest
## player. A grunt stops one cell short and holds, and steps in only when
## another enemy can reach that same player this round. A boss, and the last
## living enemy, step in alone. A mech cannot walk through another mech.

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
	var path: Array[Vector2i] = []
	var cursor := unit.overworld_position
	var steps_left := unit.move_range
	var steps_in := _steps_in(unit, everyone, map_size)
	while steps_left > 0:
		var target := _nearest_player_from(cursor, everyone)
		if target == null:
			break
		var next := _step_toward(cursor, target.overworld_position, everyone, map_size)
		if next == cursor:
			break
		if _unit_at(next, everyone) != null:
			break
		if not steps_in and _beside_any_player(next, everyone):
			break
		path.append(next)
		cursor = next
		steps_left -= 1
	while not path.is_empty() and _unit_at(path[path.size() - 1], everyone) != null:
		path.pop_back()
	return {"path": path}


## Bosses and a sole survivor close in. A grunt needs a partner who can stand
## beside the same player before this round ends.
static func _steps_in(
	unit: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> bool:
	if unit.id.begins_with("boss") or _living_enemies(everyone) <= 1:
		return true
	var target := _nearest_player_from(unit.overworld_position, everyone)
	if target == null:
		return false
	for other in everyone:
		if other == null or other == unit or not other.alive or other.team != "enemy":
			continue
		if _can_reach_player(other, target, everyone, map_size):
			return true
	return false


## Already beside the player, or able to get there with the move they have left.
## An enemy who has already acted can only count when they are already there.
static func _can_reach_player(
	unit: MechState,
	player: MechState,
	everyone: Array[MechState],
	map_size: Vector2i
) -> bool:
	if _beside(unit.overworld_position, player.overworld_position):
		return true
	if unit.has_moved:
		return false
	var distances := reachable(unit, everyone, map_size)
	for raw in distances:
		var cell: Vector2i = raw
		if _beside(cell, player.overworld_position):
			return true
	return false


static func _living_enemies(everyone: Array[MechState]) -> int:
	var count := 0
	for unit in everyone:
		if unit != null and unit.alive and unit.team == "enemy":
			count += 1
	return count


static func _beside_any_player(cell: Vector2i, everyone: Array[MechState]) -> bool:
	for other in everyone:
		if other == null or not other.alive or other.team != "player":
			continue
		if _beside(cell, other.overworld_position):
			return true
	return false


static func _beside(a: Vector2i, b: Vector2i) -> bool:
	return absi(a.x - b.x) + absi(a.y - b.y) == 1


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


## Cells inside `allowed` that can be reached from `origin` without crossing a mech.
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


## Movement stops at another mech. The mover's own cell does not count.
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


static func approach_origin(unit: MechState, destination: Vector2i, distances: Dictionary) -> Vector2i:
	var best := unit.overworld_position
	var best_distance := 999999
	for step in STEPS:
		var origin: Vector2i = destination - step
		if not distances.has(origin):
			continue
		var distance: int = distances[origin]
		if distance < best_distance:
			best_distance = distance
			best = origin
	return best


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


static func _blocked_by_mech(coords: Vector2i, mover: MechState, everyone: Array[MechState]) -> bool:
	var unit := _unit_at(coords, everyone)
	return unit != null and unit != mover


static func _unit_at(coords: Vector2i, everyone: Array[MechState]) -> MechState:
	for unit in everyone:
		if unit != null and unit.alive and unit.overworld_position == coords:
			return unit
	return null


static func _in_bounds(coords: Vector2i, _map_size: Vector2i) -> bool:
	return StageMap.contains(coords)
