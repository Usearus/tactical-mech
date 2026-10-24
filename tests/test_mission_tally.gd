@tool
extends McpTestSuite


func suite_name() -> String:
	return "mission_tally"


func test_mvp_prefers_kills_over_raw_damage() -> void:
	var rows: Array[Dictionary] = [
		{"destroyed": 1, "dealt": 4, "taken": 9},
		{"destroyed": 2, "dealt": 3, "taken": 1},
		{"destroyed": 0, "dealt": 40, "taken": 0},
	]
	assert_eq(MissionTally.mvp_index(rows), 1, "two kills outrank a bigger damage total")


func test_tied_score_breaks_toward_more_kills() -> void:
	var rows: Array[Dictionary] = [
		{"destroyed": 0, "dealt": 100, "taken": 0},
		{"destroyed": 1, "dealt": 0, "taken": 0},
	]
	assert_eq(MissionTally.score(0, 100, 0), MissionTally.score(1, 0, 0), "the weights tie")
	assert_eq(MissionTally.mvp_index(rows), 1, "the kill wins the tie")


func test_column_gold_marks_the_high_number() -> void:
	var rows: Array[Dictionary] = [
		{"destroyed": 1, "dealt": 4, "taken": 9},
		{"destroyed": 1, "dealt": 12, "taken": 2},
	]
	var leaders := MissionTally.column_leaders(rows)
	assert_eq(leaders["destroyed"], [0, 1], "tied kills are both gold")
	assert_eq(leaders["dealt"], [1], "the bigger hit total is gold")
	assert_eq(leaders["taken"], [1], "the smaller damage taken is gold")


func test_a_column_of_zeros_stays_plain() -> void:
	var rows: Array[Dictionary] = [
		{"destroyed": 0, "dealt": 0, "taken": 0},
		{"destroyed": 0, "dealt": 0, "taken": 0},
	]
	var leaders := MissionTally.column_leaders(rows)
	assert_eq(leaders["destroyed"].size(), 0)
	assert_eq(leaders["dealt"].size(), 0)
	assert_eq(leaders["taken"], [0, 1], "taking nothing is the best damage taken")
	assert_eq(MissionTally.mvp_index(rows), 0, "the first mech keeps a tied empty record")
