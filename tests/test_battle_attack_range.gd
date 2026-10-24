@tool
extends McpTestSuite

const StrikeRangeScript := preload("res://scripts/battle/strike_range.gd")
const BOARD := Vector2i(6, 3)


func suite_name() -> String:
	return "battle_attack_range"


func test_an_adjacent_strike_marks_the_four_neighbors() -> void:
	var cells := StrikeRangeScript.attack_cells(Vector2i(2, 1), _strike(1, false), BOARD)
	assert_eq(cells.size(), 4, "four neighbors")
	assert_true(cells.has(Vector2i(1, 1)), "left")
	assert_true(cells.has(Vector2i(3, 1)), "right")
	assert_true(cells.has(Vector2i(2, 0)), "up")
	assert_true(cells.has(Vector2i(2, 2)), "down")
	assert_false(cells.has(Vector2i(2, 1)), "own cell stays plain")
	assert_false(cells.has(Vector2i(4, 1)), "stops at one")


func test_a_two_cell_strike_stops_at_two() -> void:
	var cells := StrikeRangeScript.attack_cells(Vector2i(2, 1), _strike(2, false), BOARD)
	assert_true(cells.has(Vector2i(4, 1)), "two cells to the right")
	assert_true(cells.has(Vector2i(3, 0)), "a diagonal of two")
	assert_true(cells.has(Vector2i(1, 1)), "the next cell still counts")
	assert_false(cells.has(Vector2i(5, 1)), "stops at two")
	assert_false(cells.has(Vector2i(2, 1)), "own cell stays plain")


func test_an_exact_strike_skips_the_near_cells() -> void:
	var cells := StrikeRangeScript.attack_cells(Vector2i(2, 1), _strike(2, true), BOARD)
	assert_true(cells.has(Vector2i(4, 1)), "hits at two")
	assert_false(cells.has(Vector2i(3, 1)), "skips the next cell")
	assert_false(cells.has(Vector2i(2, 1)), "own cell stays plain")


func test_a_front_strike_fans_to_either_side() -> void:
	var card := _strike(1, false)
	card.target_type = "front"
	var cells := StrikeRangeScript.attack_cells(Vector2i(0, 0), card, BOARD)
	assert_true(cells.has(Vector2i(1, 0)), "the cell ahead")
	assert_true(cells.has(Vector2i(1, 1)), "the cell beside that")
	assert_false(cells.has(Vector2i(0, 1)), "the cell straight above is not in front")
	assert_false(cells.has(Vector2i(0, 0)), "own cell stays plain")


func test_an_off_board_enemy_marks_nothing() -> void:
	var cells := StrikeRangeScript.attack_cells(Vector2i(-1, -1), _strike(2, false), BOARD)
	assert_eq(cells.size(), 0, "no cells")


func test_gunner_shot_marks_only_adjacent_cells() -> void:
	var mech := load("res://data/mechs/enemy/gunner.tres") as MechData
	var cells := StrikeRangeScript.attack_cells(Vector2i(2, 1), MechDecks.strike_card(mech), BOARD)
	assert_eq(cells.size(), 4, "shot reaches the next cell")
	assert_false(cells.has(Vector2i(4, 1)), "shot stops at one")


func test_flyer_strafe_marks_two_cells_out() -> void:
	var mech := load("res://data/mechs/enemy/red_flyer.tres") as MechData
	var cells := StrikeRangeScript.attack_cells(Vector2i(2, 1), MechDecks.strike_card(mech), BOARD)
	assert_true(cells.has(Vector2i(4, 1)), "strafe reaches two cells")
	assert_false(cells.has(Vector2i(5, 1)), "strafe stops at two")


func test_a_ward_has_no_strike_range() -> void:
	var mech := load("res://data/mechs/enemy/red_quad.tres") as MechData
	assert_true(MechDecks.strike_card(mech) == null, "quad grants barrier instead of striking")


func _strike(reach: int, exact: bool) -> CardData:
	var card := CardData.new()
	card.card_type = "Attack"
	card.reach = reach
	card.exact_range = exact
	return card
