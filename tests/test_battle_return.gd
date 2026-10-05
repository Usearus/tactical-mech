@tool
extends McpTestSuite


func suite_name() -> String:
	return "battle_return"


func test_horizontal_return_matches_battle_cells() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 3))
	var ally := _mech("bulldog", "player", Vector2i(7, 3))
	var enemy := _mech("scout", "enemy", Vector2i(9, 3))
	var bystander := _mech("raider", "enemy", Vector2i(16, 3))
	var everyone: Array[MechState] = [player, ally, enemy, bystander]
	var encounter := EncounterData.create(player, Vector2i.RIGHT, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	BattleDeployment.commit_to_overworld(encounter, placed, everyone, _map())
	assert_eq(player.overworld_position, Vector2i(8, 3), "unchanged battle cells stay put")
	assert_eq(ally.overworld_position, Vector2i(7, 3), "ally stays")
	assert_eq(enemy.overworld_position, Vector2i(9, 3), "enemy stays")
	assert_eq(bystander.overworld_position, Vector2i(16, 3), "units outside the fight stay")
	var moved := placed.duplicate()
	moved[player.id] = Vector2i(4, 0)
	moved[enemy.id] = placed[player.id]
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_eq(player.overworld_position, Vector2i(10, 2), "east-west step lands on that overworld cell")
	assert_eq(enemy.overworld_position, Vector2i(8, 3), "enemy takes the cell the player left")
	assert_eq(ally.overworld_position, Vector2i(7, 3), "ally who held still stays")
	assert_eq(bystander.overworld_position, Vector2i(16, 3), "bystander stays")


func test_vertical_return_unrotates() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 4))
	var enemy := _mech("scout", "enemy", Vector2i(8, 3))
	var everyone: Array[MechState] = [player, enemy]
	var encounter := EncounterData.create(player, Vector2i.UP, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	var moved := placed.duplicate()
	moved[player.id] = placed[enemy.id]
	moved[enemy.id] = placed[player.id]
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_eq(player.overworld_position, Vector2i(8, 3), "stepping toward the north enemy lands north")
	assert_eq(enemy.overworld_position, Vector2i(8, 4), "enemy steps south onto the player's old cell")


func test_enemy_attacker_uses_the_same_patch() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 4))
	var enemy := _mech("scout", "enemy", Vector2i(8, 3))
	var everyone: Array[MechState] = [player, enemy]
	var encounter := EncounterData.create(enemy, Vector2i.DOWN, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	var moved := placed.duplicate()
	moved[enemy.id] = placed[player.id]
	moved[player.id] = placed[enemy.id]
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_eq(enemy.overworld_position, Vector2i(8, 4), "enemy who closed south stands on the player's cell")
	assert_eq(player.overworld_position, Vector2i(8, 3), "player is pushed onto the enemy's old cell")


func test_off_map_cell_snaps_onto_open_ground() -> void:
	var player := _mech("lancer", "player", Vector2i(0, 3))
	var enemy := _mech("scout", "enemy", Vector2i(1, 3))
	var everyone: Array[MechState] = [player, enemy]
	var encounter := EncounterData.create(player, Vector2i.RIGHT, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	var moved := placed.duplicate()
	moved[player.id] = Vector2i(0, 0)
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_eq(player.overworld_position.x >= 0, true, "a cell past the map edge snaps onto the stage")
	assert_false(StageMap.blocked(player.overworld_position), "the landing cell is open ground")
	assert_eq(enemy.overworld_position, Vector2i(1, 3), "enemy holds")
	assert_ne(player.overworld_position, enemy.overworld_position)


func test_collision_cell_snaps_to_open_ground() -> void:
	var player := _mech("lancer", "player", Vector2i(4, 1))
	var enemy := _mech("scout", "enemy", Vector2i(5, 1))
	var everyone: Array[MechState] = [player, enemy]
	var encounter := EncounterData.create(player, Vector2i.RIGHT, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	var moved := placed.duplicate()
	moved[player.id] = Vector2i(0, 0)
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_false(StageMap.blocked(player.overworld_position), "a collision tile is not a place to stand")
	assert_true(StageMap.contains(player.overworld_position), "the landing stays on the stage")


func test_ranged_attack_keeps_the_target_on_d2() -> void:
	var player := _mech("lancer", "player", Vector2i(7, 3))
	var enemy := _mech("scout", "enemy", Vector2i(9, 3))
	var encounter := EncounterData.create(player, Vector2i(2, 0), [player, enemy])
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	assert_eq(placed[enemy.id], Vector2i(3, 1), "the mech being attacked stands on D2")
	assert_eq(placed[player.id], Vector2i(1, 1), "a range-2 attacker keeps the gap")


func test_attack_from_the_east_keeps_the_target_on_d2() -> void:
	var player := _mech("lancer", "player", Vector2i(10, 3))
	var enemy := _mech("scout", "enemy", Vector2i(9, 3))
	var encounter := EncounterData.create(player, Vector2i(-1, 0), [player, enemy])
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	assert_eq(placed[enemy.id], Vector2i(3, 1), "attacking from the east still puts the target on D2")
	assert_eq(placed[player.id], Vector2i(4, 1), "the attacker stands one cell east of D2")


func test_attack_from_the_north_keeps_the_target_on_d2() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 1))
	var enemy := _mech("scout", "enemy", Vector2i(8, 3))
	var encounter := EncounterData.create(player, Vector2i(0, 2), [player, enemy])
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	assert_eq(placed[enemy.id], Vector2i(3, 1), "a north-south target still lands on D2")
	assert_eq(placed[player.id], Vector2i(1, 1), "range 2 from the north stays two cells left of D2")


func test_player_being_attacked_stands_on_d2() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 4))
	var enemy := _mech("scout", "enemy", Vector2i(8, 2))
	var encounter := EncounterData.create(enemy, Vector2i(0, 2), [player, enemy])
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	assert_eq(placed[player.id], Vector2i(3, 1), "the player being attacked stands on D2")
	assert_eq(placed[enemy.id], Vector2i(1, 1), "the attacker keeps the two-cell gap")


func test_destroyed_mech_yields_its_cell() -> void:
	var player := _mech("lancer", "player", Vector2i(8, 3))
	var enemy := _mech("scout", "enemy", Vector2i(9, 3))
	var everyone: Array[MechState] = [player, enemy]
	var encounter := EncounterData.create(player, Vector2i.RIGHT, everyone)
	var placed := BattleDeployment.place(encounter, BattleGrid.create())
	enemy.alive = false
	var moved := placed.duplicate()
	moved[player.id] = placed[enemy.id]
	BattleDeployment.commit_to_overworld(encounter, moved, everyone, _map())
	assert_eq(player.overworld_position, Vector2i(9, 3), "the survivor takes the cell where the enemy fell")


func _map() -> Vector2i:
	StageMap.ensure()
	return StageMap.bounds.size


func _mech(id: String, team: String, pos: Vector2i) -> MechState:
	var data := MechData.new()
	data.id = id
	data.display_name = id
	data.short_name = id
	data.team = team
	return MechState.from_data(data, pos)
