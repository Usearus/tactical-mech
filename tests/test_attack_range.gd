@tool
extends McpTestSuite


func suite_name() -> String:
	return "attack_range"


func test_raven_and_comet_open_fights_from_one_or_two() -> void:
	for mech_id in ["raven", "comet"]:
		var unit := _unit(mech_id)
		assert_true(unit.attacks_at(1), "%s hits the next cell" % mech_id)
		assert_true(unit.attacks_at(2), "%s hits two cells out" % mech_id)
		assert_false(unit.attacks_at(3), "%s stops at two" % mech_id)
		assert_eq(unit.attack_range_text(), "1-2", mech_id)


func test_barrage_opens_fights_from_exactly_two() -> void:
	var unit := _unit("barrage")
	assert_false(unit.attacks_at(1), "barrage skips the next cell")
	assert_true(unit.attacks_at(2), "barrage hits at two")
	assert_false(unit.attacks_at(3), "barrage stops at two")
	assert_eq(unit.attack_range_text(), "2", "exact")


func test_a_close_mech_opens_fights_from_the_next_cell() -> void:
	var unit := _unit("bastion")
	assert_true(unit.attacks_at(1), "bastion hits the next cell")
	assert_false(unit.attacks_at(2), "bastion stops at one")
	assert_eq(unit.attack_range_text(), "1", "exact")


func _unit(mech_id: String) -> MechState:
	var mech := load("res://data/mechs/player/%s.tres" % mech_id) as MechData
	return MechState.from_data(mech, Vector2i.ZERO)
