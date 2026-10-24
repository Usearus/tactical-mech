class_name MissionTally
extends RefCounted

## A kill outweighs a hit. Damage taken lowers the score.
const KILL_WEIGHT := 100


static func score(destroyed: int, dealt: int, taken: int) -> int:
	return destroyed * KILL_WEIGHT + dealt - taken


## Destroyed and damage dealt gold the highest number. Damage taken golds the lowest.
## A destroyed or dealt column of zeros stays plain. Zero damage taken is a real best.
static func column_leaders(rows: Array) -> Dictionary:
	return {
		"destroyed": _leaders(rows, "destroyed", true),
		"dealt": _leaders(rows, "dealt", true),
		"taken": _leaders(rows, "taken", false),
	}


## One mech. Ties break toward more kills, then more damage dealt, then less taken.
static func mvp_index(rows: Array) -> int:
	if rows.is_empty():
		return -1
	var best := 0
	for index in range(1, rows.size()):
		if _outranks(rows[index], rows[best]):
			best = index
	return best


static func _leaders(rows: Array, key: String, higher: bool) -> Array[int]:
	var best := 0
	var found := false
	for row in rows:
		var value := int(row.get(key, 0))
		var better := false
		if higher:
			better = value > best
		else:
			better = value < best
		if not found or better:
			best = value
			found = true
	var indexes: Array[int] = []
	if not found or (higher and best <= 0):
		return indexes
	for index in rows.size():
		if int(rows[index].get(key, 0)) == best:
			indexes.append(index)
	return indexes


static func _outranks(challenger: Dictionary, holder: Dictionary) -> bool:
	var challenge := score(int(challenger.get("destroyed", 0)), int(challenger.get("dealt", 0)), int(challenger.get("taken", 0)))
	var held := score(int(holder.get("destroyed", 0)), int(holder.get("dealt", 0)), int(holder.get("taken", 0)))
	if challenge != held:
		return challenge > held
	var kills := int(challenger.get("destroyed", 0)) - int(holder.get("destroyed", 0))
	if kills != 0:
		return kills > 0
	var dealt := int(challenger.get("dealt", 0)) - int(holder.get("dealt", 0))
	if dealt != 0:
		return dealt > 0
	return int(challenger.get("taken", 0)) < int(holder.get("taken", 0))
