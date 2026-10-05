@tool
extends McpTestSuite

## Row 3 of the stage is open ground, so these paths are about formation, not rubble.
const MAP := Vector2i(21, 7)


func suite_name() -> String:
	return "overworld_ai"


func test_lone_grunt_stops_one_cell_short() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var grunt := _unit("scout", "enemy", Vector2i(6, 3), 4)
	var out_of_reach := _unit("gunner", "enemy", Vector2i(18, 3), 2)
	assert_eq(_destination(grunt, [player, grunt, out_of_reach]), Vector2i(8, 3))


func test_grunts_step_in_together_when_both_can_reach() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var left := _unit("scout", "enemy", Vector2i(6, 3), 4)
	var right := _unit("slasher", "enemy", Vector2i(14, 3), 4)
	var everyone: Array[MechState] = [player, left, right]
	assert_eq(_destination(left, everyone), Vector2i(9, 3))
	assert_eq(_destination(right, everyone), Vector2i(11, 3))


func test_grunt_holds_when_partner_cannot_arrive() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var close := _unit("scout", "enemy", Vector2i(7, 3), 3)
	var far := _unit("slasher", "enemy", Vector2i(18, 3), 2)
	assert_eq(_destination(close, [player, close, far]), Vector2i(8, 3))


func test_last_enemy_steps_in_alone() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var last := _unit("scout", "enemy", Vector2i(7, 3), 3)
	assert_eq(_destination(last, [player, last]), Vector2i(9, 3))


func test_boss_steps_in_alone() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var boss := _unit("boss_green", "enemy", Vector2i(7, 3), 3)
	var far := _unit("slasher", "enemy", Vector2i(18, 3), 2)
	assert_eq(_destination(boss, [player, boss, far]), Vector2i(9, 3))


func test_grunt_steps_in_with_a_boss_who_can_reach() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var boss := _unit("boss_green", "enemy", Vector2i(7, 3), 3)
	var grunt := _unit("raider", "enemy", Vector2i(13, 3), 3)
	var everyone: Array[MechState] = [player, boss, grunt]
	assert_eq(_destination(grunt, everyone), Vector2i(11, 3))
	assert_eq(_destination(boss, everyone), Vector2i(9, 3))


func test_enemy_who_already_acted_does_not_count_unless_beside_the_player() -> void:
	var player := _unit("pilot", "player", Vector2i(10, 3), 2)
	var held := _unit("slasher", "enemy", Vector2i(4, 3), 5)
	held.has_moved = true
	var actor := _unit("scout", "enemy", Vector2i(7, 3), 3)
	assert_eq(_destination(actor, [player, held, actor]), Vector2i(8, 3))
	held.overworld_position = Vector2i(10, 4)
	assert_eq(_destination(actor, [player, held, actor]), Vector2i(9, 3))


func test_grunts_on_different_players_do_not_unlock_each_other() -> void:
	var left_player := _unit("pilot", "player", Vector2i(4, 3), 2)
	var right_player := _unit("wing", "player", Vector2i(16, 3), 2)
	var left := _unit("scout", "enemy", Vector2i(7, 3), 3)
	var right := _unit("slasher", "enemy", Vector2i(13, 3), 3)
	var everyone: Array[MechState] = [left_player, right_player, left, right]
	assert_eq(_destination(left, everyone), Vector2i(6, 3))
	assert_eq(_destination(right, everyone), Vector2i(14, 3))


func _destination(unit: MechState, everyone: Array[MechState]) -> Vector2i:
	var plan := OverworldAi.plan_enemy_move(unit, everyone, MAP)
	var path: Array = plan["path"]
	if path.is_empty():
		return unit.overworld_position
	return path[path.size() - 1]


func _unit(id: String, team: String, at: Vector2i, move_range: int) -> MechState:
	var data := MechData.new()
	data.id = id
	data.team = team
	data.move_range = move_range
	data.display_name = id
	return MechState.from_data(data, at)
