class_name SeatAssign
extends RefCounted


## Puts every mech on a different starting square. Extra mechs stay off the map.
static func auto_place(units: Array[MechState], seats: Array[Vector2i], unplaced: Vector2i, rng: RandomNumberGenerator = null) -> void:
	var roll := rng
	if roll == null:
		roll = RandomNumberGenerator.new()
		roll.randomize()
	var order: Array[Vector2i] = []
	for seat in seats:
		order.append(seat)
	for index in range(order.size() - 1, 0, -1):
		var swap := roll.randi_range(0, index)
		var held := order[index]
		order[index] = order[swap]
		order[swap] = held
	var next := 0
	for unit in units:
		if unit == null:
			continue
		if next >= order.size():
			unit.overworld_position = unplaced
			continue
		unit.overworld_position = order[next]
		next += 1
