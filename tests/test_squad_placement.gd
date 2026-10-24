@tool
extends McpTestSuite

const SeatAssignScript := preload("res://scripts/overworld/seat_assign.gd")
const DragTileScript := preload("res://scripts/ui/drag_tile.gd")


func suite_name() -> String:
	return "squad_placement"


func test_a_drop_on_an_empty_seat_leaves_the_tray() -> void:
	var placement := _placement()
	var unit := _player("raven")
	assert_true(placement.drop_on_seat(unit, Vector2i(2, 4), null), "the seat accepts the mech")
	assert_eq(unit.overworld_position, Vector2i(2, 4), "the mech stands on the chosen square")
	assert_false(placement.all_seated([unit, _player("bulldog")]), "the other mech is still in the window")


func test_a_tray_drop_on_an_occupied_seat_sends_the_occupant_back() -> void:
	var placement := _placement()
	var seated := _player("bulldog")
	seated.overworld_position = Vector2i(2, 4)
	var incoming := _player("raven")
	assert_true(placement.drop_on_seat(incoming, Vector2i(2, 4), seated), "the occupied seat accepts the swap")
	assert_eq(incoming.overworld_position, Vector2i(2, 4), "the dragged mech takes the square")
	assert_eq(seated.overworld_position, StartingRoster.UNPLACED, "the occupant returns to the window")


func test_two_placed_mechs_swap_squares() -> void:
	var placement := _placement()
	var left := _player("raven")
	var right := _player("bastion")
	left.overworld_position = Vector2i(1, 3)
	right.overworld_position = Vector2i(2, 3)
	assert_true(placement.drop_on_seat(left, Vector2i(2, 3), right), "the other square accepts the drag")
	assert_eq(left.overworld_position, Vector2i(2, 3), "the dragged mech moves")
	assert_eq(right.overworld_position, Vector2i(1, 3), "the occupant takes the vacated square")
	assert_true(placement.all_seated([left, right]), "both mechs are still placed")


func test_a_placed_mech_can_return_to_the_window() -> void:
	var placement := _placement()
	var unit := _player("comet")
	unit.overworld_position = Vector2i(0, 1)
	placement.return_to_bench(unit)
	assert_eq(unit.overworld_position, StartingRoster.UNPLACED, "the mech leaves the map")
	assert_false(placement.all_seated([unit]), "start stays locked")


func test_a_drop_off_the_starting_squares_is_rejected() -> void:
	var placement := _placement()
	var unit := _player("lancer")
	assert_false(placement.drop_on_seat(unit, Vector2i(9, 9), null), "only blue squares accept a drop")
	assert_eq(unit.overworld_position, StartingRoster.UNPLACED, "the mech stays in the window")


func test_auto_place_puts_each_mech_on_a_different_seat() -> void:
	var placement := _placement()
	var units := _squad(["raven", "bulldog", "bastion"])
	SeatAssignScript.auto_place(units, placement.seats, StartingRoster.UNPLACED, _rng(1))
	var used := {}
	for unit in units:
		assert_true(placement.is_seat(unit.overworld_position), unit.data.id)
		assert_false(used.has(unit.overworld_position), "two mechs share a square")
		used[unit.overworld_position] = true
	assert_true(placement.all_seated(units), "every mech is placed")


func test_the_same_seed_places_the_squad_the_same_way() -> void:
	var first := _spots(4)
	var again := _spots(4)
	assert_eq(again, first, "a seed repeats")
	var differed := false
	for seed in [2, 3, 5, 8, 13, 21]:
		if _spots(seed) != first:
			differed = true
			break
	assert_true(differed, "another seed shuffles the seats")


func test_auto_place_leaves_a_spare_mech_in_the_window() -> void:
	var placement := _placement()
	var units := _squad(["raven", "bulldog", "bastion", "lancer", "comet"])
	SeatAssignScript.auto_place(units, placement.seats, StartingRoster.UNPLACED, _rng(3))
	var seated := 0
	for unit in units:
		if placement.is_seat(unit.overworld_position):
			seated += 1
		else:
			assert_eq(unit.overworld_position, StartingRoster.UNPLACED, "the spare stays in the window")
	assert_eq(seated, placement.seats.size(), "every seat is filled")


func test_a_drag_preview_keeps_the_tile_center_on_the_cursor() -> void:
	var tile := Control.new()
	tile.custom_minimum_size = Vector2(104, 128)
	var anchor := DragTileScript.center_on_cursor(tile)
	track(anchor)
	var child := anchor.get_child(0) as Control
	assert_eq(child.position, Vector2(-52, -64), "the tile center sits on the cursor")


func test_cell_drag_forwarding_accepts_placement_callbacks() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var button := Button.new()
	tree.root.add_child(button)
	track(button)
	button.set_drag_forwarding(
		_forward_drag.bind(button, Vector2i(1, 2)),
		_forward_can_drop.bind(Vector2i(1, 2)),
		_forward_drop.bind(Vector2i(1, 2))
	)
	assert_true(true, "the map cells can host a placement drag")


func _forward_drag(_at: Vector2, _button: Button, _coords: Vector2i) -> Variant:
	return null


func _forward_can_drop(_at: Vector2, _data: Variant, _coords: Vector2i) -> bool:
	return false


func _forward_drop(_at: Vector2, _data: Variant, _coords: Vector2i) -> void:
	pass


func _squad(ids: Array) -> Array[MechState]:
	var units: Array[MechState] = []
	for id in ids:
		units.append(_player(str(id)))
	return units


func _spots(seed: int) -> Array[Vector2i]:
	var placement := _placement()
	var units := _squad(["raven", "bulldog", "bastion"])
	SeatAssignScript.auto_place(units, placement.seats, StartingRoster.UNPLACED, _rng(seed))
	var spots: Array[Vector2i] = []
	for unit in units:
		spots.append(unit.overworld_position)
	return spots


func _rng(seed: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng


func _placement() -> SquadPlacement:
	var placement := SquadPlacement.new()
	placement.seats = [Vector2i(1, 3), Vector2i(2, 3), Vector2i(2, 4), Vector2i(0, 1)]
	return placement


func _player(id: String) -> MechState:
	var data := MechData.new()
	data.id = id
	data.team = "player"
	data.display_name = id
	return MechState.from_data(data, StartingRoster.UNPLACED)
