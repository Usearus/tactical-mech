@tool
extends McpTestSuite


func suite_name() -> String:
	return "overworld_ai"


func test_a_grunt_opens_from_two_cells_and_still_from_the_next_cell() -> void:
	var player := _mech("res://data/mechs/player/bastion.tres", Vector2i(4, 0))
	var grunt := _mech("res://data/mechs/enemy/red_grunt.tres", Vector2i(2, 0))
	var everyone: Array[MechState] = [player, grunt]
	assert_eq(OverworldAi.prey(grunt, everyone), player, "two cells is a shot")
	grunt.overworld_position = Vector2i(3, 0)
	assert_eq(OverworldAi.prey(grunt, everyone), player, "the next cell still starts a fight")
	grunt.overworld_position = Vector2i(1, 0)
	assert_eq(OverworldAi.prey(grunt, everyone), null, "three cells is not yet a shot")


func test_a_vertical_shot_uses_a_field_that_contains_the_target() -> void:
	var east := OverworldAi.tactic_for(Vector2i(0, 0), Vector2i(2, 0))
	assert_eq(east.id, "standard", "two cells east stays on the usual field")
	var north := OverworldAi.tactic_for(Vector2i(0, 0), Vector2i(0, -2))
	assert_eq(north.id, "north", "two cells north uses the upper field")
	var south := OverworldAi.tactic_for(Vector2i(0, 0), Vector2i(0, 2))
	assert_eq(south.id, "south", "two cells south uses the lower field")
	assert_true(north.covers(Vector2i(0, 0), Vector2i(0, -2)), "the northern target is on the field")
	assert_true(south.covers(Vector2i(0, 0), Vector2i(0, 2)), "the southern target is on the field")


func test_a_grunt_holds_outside_range_until_a_partner_will_join() -> void:
	var spot := _spot()
	assert_false(spot.is_empty(), "an open lane of five cells")
	var cells: Array[Vector2i] = spot["cells"]
	var player := _mech("res://data/mechs/player/bastion.tres", cells[4])
	var grunt := _mech("res://data/mechs/enemy/red_grunt.tres", cells[1])
	var partner := _mech("res://data/mechs/enemy/red_grunt.tres", cells[0])
	partner.has_moved = true
	var far := _mech("res://data/mechs/enemy/red_sentinel.tres", spot["far"])
	far.has_moved = true
	var held: Array[MechState] = [player, grunt, far]
	var held_path := _path(grunt, held)
	assert_eq(held_path.size(), 0, "a grunt without backup stays outside range")
	assert_eq(OverworldAi.prey(grunt, held), null, "three cells is not a shot")
	var backed: Array[MechState] = [player, grunt, partner, far]
	var backed_path := _path(grunt, backed)
	assert_eq(backed_path.size(), 1, "backup lets the grunt step in")
	assert_eq(backed_path[0], cells[2], "the step lands two cells from the player")
	assert_false(backed_path.has(cells[3]), "it does not close to the next cell")
	grunt.overworld_position = cells[2]
	assert_eq(OverworldAi.prey(grunt, backed), player, "that cell opens the fight")
	var tactic := OverworldAi.tactic_for(grunt.overworld_position, player.overworld_position)
	var encounter := EncounterData.create_from_tactic(grunt, tactic, backed)
	assert_true(encounter.participants.has(player), "the player is in the fight")
	assert_true(encounter.participants.has(partner), "the enemy behind joins")
	assert_true(encounter.participants.has(grunt), "the shooter is in the fight")


func test_a_melee_enemy_still_closes_to_the_next_cell() -> void:
	var spot := _spot()
	assert_false(spot.is_empty(), "an open lane of five cells")
	var cells: Array[Vector2i] = spot["cells"]
	var player := _mech("res://data/mechs/player/bastion.tres", cells[4])
	var sentinel := _mech("res://data/mechs/enemy/red_sentinel.tres", cells[2])
	var partner := _mech("res://data/mechs/enemy/red_sentinel.tres", spot["side"])
	var far := _mech("res://data/mechs/enemy/red_sentinel.tres", spot["far"])
	far.has_moved = true
	var alone: Array[MechState] = [player, sentinel, far]
	assert_eq(_path(sentinel, alone).size(), 0, "a melee enemy holds one cell short")
	var backed: Array[MechState] = [player, sentinel, partner, far]
	var path := _path(sentinel, backed)
	assert_eq(path.size(), 1, "backup lets it step onto the next cell")
	assert_eq(path[0], cells[3], "the step is the cell beside the player")


func test_a_boss_stops_at_its_attack_range() -> void:
	var spot := _spot()
	assert_false(spot.is_empty(), "an open lane of five cells")
	var cells: Array[Vector2i] = spot["cells"]
	var player := _mech("res://data/mechs/player/bastion.tres", cells[4])
	var boss := _mech("res://data/mechs/enemy/red_boss.tres", cells[1])
	var path := _path(boss, [player, boss])
	assert_eq(path.size(), 1, "the boss takes one step")
	assert_eq(path[0], cells[2], "the boss stops two cells out")


func _path(unit: MechState, everyone: Array[MechState]) -> Array[Vector2i]:
	var plan := OverworldAi.plan_enemy_move(unit, everyone, StageMap.bounds.size)
	var path: Array[Vector2i] = []
	path.assign(plan["path"])
	return path


func _spot() -> Dictionary:
	for scene_path in ["res://scenes/stage/stage-0-1.tscn", "res://scenes/stage/stage-0-0.tscn"]:
		StageMap.use(scene_path)
		var found := _find_lane()
		if not found.is_empty():
			return found
	return {}


func _find_lane() -> Dictionary:
	var rect := StageMap.bounds
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x - 4):
			var cells: Array[Vector2i] = []
			var open := true
			for index in 5:
				var coords := Vector2i(x + index, y)
				if StageMap.blocked(coords):
					open = false
					break
				cells.append(coords)
			if not open:
				continue
			var side := _open_side(cells[4])
			if side == Vector2i(-99999, -99999):
				continue
			var shot := cells[2]
			var player_cell := cells[4]
			var tactic := OverworldAi.tactic_for(shot, player_cell)
			var far := _far_cell(cells, side, shot, tactic)
			if far == Vector2i(-99999, -99999):
				continue
			return {"cells": cells, "side": side, "far": far}
	return {}


func _open_side(player_cell: Vector2i) -> Vector2i:
	var steps: Array[Vector2i] = [Vector2i.DOWN, Vector2i.UP]
	for step in steps:
		var coords := player_cell + step
		if not StageMap.blocked(coords):
			return coords
	return Vector2i(-99999, -99999)


func _far_cell(lane: Array[Vector2i], side: Vector2i, shot: Vector2i, tactic: BattleTactic) -> Vector2i:
	var rect := StageMap.bounds
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			var coords := Vector2i(x, y)
			if StageMap.blocked(coords) or lane.has(coords) or coords == side:
				continue
			if tactic != null and tactic.covers(shot, coords):
				continue
			if absi(coords.x - lane[4].x) + absi(coords.y - lane[4].y) <= 2:
				continue
			return coords
	return Vector2i(-99999, -99999)


func _mech(path: String, coords: Vector2i) -> MechState:
	var data := load(path) as MechData
	return MechState.from_data(data, coords)
