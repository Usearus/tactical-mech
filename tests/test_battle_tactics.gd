@tool
extends McpTestSuite


func suite_name() -> String:
	return "battle_tactics"


func test_standard_seat_covers_two_west_and_three_east() -> void:
	var tactic := BattleTactic.standard()
	var mech := Vector2i(10, 10)
	assert_eq(tactic.origin_for(mech), Vector2i(8, 9), "origin sits two west and one north")
	assert_true(tactic.covers(mech, Vector2i(8, 10)), "two cells west")
	assert_true(tactic.covers(mech, Vector2i(13, 10)), "three cells east")
	assert_true(tactic.covers(mech, Vector2i(10, 9)), "one cell north")
	assert_true(tactic.covers(mech, Vector2i(10, 11)), "one cell south")
	assert_false(tactic.covers(mech, Vector2i(7, 10)), "stops west of the rectangle")
	assert_false(tactic.covers(mech, Vector2i(14, 10)), "stops east of the rectangle")


func test_offense_reaches_one_cell_farther_east() -> void:
	var tactic := BattleTactic.by_id("offense")
	var mech := Vector2i(10, 10)
	assert_eq(tactic.origin_for(mech), Vector2i(9, 9), "origin")
	assert_true(tactic.covers(mech, Vector2i(14, 10)), "four cells east")
	assert_false(tactic.covers(mech, Vector2i(8, 10)), "only one cell west")


func test_plaza_is_two_cells_in_every_direction() -> void:
	var tactic := BattleTactic.by_id("plaza")
	var mech := Vector2i(10, 10)
	assert_eq(tactic.size, Vector2i(5, 5), "five by five")
	assert_true(tactic.covers(mech, Vector2i(8, 8)), "north-west corner")
	assert_true(tactic.covers(mech, Vector2i(12, 12)), "south-east corner")
	assert_false(tactic.covers(mech, Vector2i(7, 10)), "outside the west edge")


func test_deep_grows_north_and_south() -> void:
	var tactic := BattleTactic.by_id("deep")
	var mech := Vector2i(10, 10)
	assert_eq(tactic.size, Vector2i(4, 5), "four wide by five tall")
	assert_true(tactic.covers(mech, Vector2i(10, 8)), "two cells north")
	assert_true(tactic.covers(mech, Vector2i(10, 12)), "two cells south")
	assert_true(tactic.covers(mech, Vector2i(12, 10)), "two cells east")
	assert_false(tactic.covers(mech, Vector2i(8, 10)), "only one cell west")


func test_the_board_shows_two_tiles_past_the_fight() -> void:
	var encounter := EncounterData.new()
	encounter.tactic = BattleTactic.standard()
	assert_eq(BattleDeployment.view_margin(encounter), 2)
	assert_eq(BattleDeployment.view_size(encounter), Vector2i(10, 7))
	assert_false(BattleDeployment.is_play_cell(Vector2i(1, 1), encounter))
	assert_true(BattleDeployment.is_play_cell(Vector2i(2, 2), encounter))
	assert_false(BattleDeployment.is_play_cell(Vector2i(8, 2), encounter))


func test_the_picker_lists_the_enabled_tactics() -> void:
	var names: PackedStringArray = []
	for tactic in BattleTactic.enabled_list():
		names.append(tactic.id)
		assert_true(tactic.enabled, tactic.id)
	assert_eq(names.size(), 4, "four tactics stay in the picker")
	assert_true(names.has("standard"), "standard")
	assert_true(names.has("offense"), "offense")
	assert_true(names.has("north"), "north")
	assert_true(names.has("south"), "south")
	var hidden_ids: PackedStringArray = ["westward", "plaza", "broad", "deep"]
	for hidden in hidden_ids:
		var tucked := BattleTactic.by_id(hidden)
		assert_false(tucked.enabled, hidden)
