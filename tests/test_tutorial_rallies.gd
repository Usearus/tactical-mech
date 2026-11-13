@tool
extends McpTestSuite

## The tutorial stage's markers produce the three scripted fights.


func suite_name() -> String:
	return "tutorial_rallies"


func test_fight_one_is_raven_and_one_scout() -> void:
	_reload_stage()
	var units := TutorialStage.units_for(1)
	var encounter := _encounter(units)
	assert_eq(_ids(encounter), PackedStringArray(["raven", "scout"]), "Raven and one Scout")
	assert_eq(encounter.participants.size(), 2, "nobody else is standing in the rectangle")
	_assert_open(TutorialStage.cell("Player1"))
	_assert_open(TutorialStage.cell("Scout"))


func test_fight_two_is_one_step_with_comet_and_three() -> void:
	_reload_stage()
	var start := TutorialStage.raven_cell(2, false)
	var attack := TutorialStage.raven_cell(2, true)
	assert_eq(_manhattan(start, attack), 1, "fight 2 is one step")
	var units := TutorialStage.units_for(2)
	var raven := units[0]
	assert_false(_in_range(raven, start, units), "the pack is out of range before the step")
	raven.overworld_position = attack
	var encounter := _encounter(units)
	assert_eq(_ids(encounter), PackedStringArray(["comet", "raven", "tutorial_gunner", "tutorial_raider", "tutorial_scout"]), "Raven, Comet, and three contacts")
	assert_false(_has(encounter, "barrage"), "Barrage stands outside this rectangle")
	_assert_open(start)
	_assert_open(attack)
	_assert_open(TutorialStage.cell("Player2"))


func test_comet_leads_into_the_second_fight() -> void:
	_reload_stage()
	assert_eq(TutorialStage.lead_id(2), "comet", "Comet's turn after the first battle")
	var units := TutorialStage.units_for(2)
	var comet := _find(units, "comet")
	var raven := _find(units, "raven")
	comet.overworld_position = TutorialStage.lead_cell(2, true)
	raven.overworld_position = TutorialStage.cell("Player2")
	var encounter := EncounterData.create_from_tactic(comet, BattleTactic.standard(), units)
	assert_eq(_ids(encounter), PackedStringArray(["comet", "raven", "tutorial_gunner", "tutorial_raider", "tutorial_scout"]), "Comet's attack still brings Raven and the three contacts")
	assert_true(_in_range(comet, comet.overworld_position, units), "Comet can attack from there")


func test_barrage_leads_into_the_third_fight() -> void:
	_reload_stage()
	assert_eq(TutorialStage.lead_id(3), "barrage", "Barrage's turn after the second battle")
	var start := TutorialStage.lead_cell(3, false)
	var attack := TutorialStage.lead_cell(3, true)
	assert_eq(_manhattan(start, attack), 1, "Barrage steps one cell")
	_assert_open(start)
	_assert_open(attack)
	var units := TutorialStage.units_for(3)
	var barrage := _find(units, "barrage")
	barrage.overworld_position = attack
	var encounter := EncounterData.create_from_tactic(barrage, BattleTactic.standard(), units)
	assert_eq(
		_ids(encounter),
		PackedStringArray(["barrage", "comet", "raven", "tutorial_gunner", "tutorial_raider", "tutorial_scout"]),
		"Barrage's attack still brings the whole squad"
	)
	for unit in units:
		if unit.team != "enemy":
			continue
		assert_eq(_manhattan(attack, unit.overworld_position), 3, "Salvo distance")


func test_fight_three_lines_barrage_up_for_salvo() -> void:
	_reload_stage()
	var start := TutorialStage.raven_cell(3, false)
	var attack := TutorialStage.raven_cell(3, true)
	assert_eq(_manhattan(start, attack), 1, "fight 3 is one step")
	var units := TutorialStage.units_for(3)
	var raven := units[0]
	raven.overworld_position = attack
	var encounter := _encounter(units)
	assert_eq(
		_ids(encounter),
		PackedStringArray(["barrage", "comet", "raven", "tutorial_gunner", "tutorial_raider", "tutorial_scout"]),
		"all three pilots and three contacts"
	)
	var barrage := _find(units, "barrage")
	var enemies := 0
	for unit in units:
		if unit.team != "enemy":
			continue
		enemies += 1
		assert_eq(_manhattan(barrage.overworld_position, unit.overworld_position), 3, "Salvo distance")
		assert_true(raven.attacks_at(_manhattan(attack, unit.overworld_position)), "Raven can open on this contact")
		_assert_open(unit.overworld_position)
	assert_eq(enemies, 3, "three contacts")
	_assert_open(start)
	_assert_open(attack)
	_assert_open(barrage.overworld_position)


## The editor keeps the last instantiated stage. Read the scene file again.
func _reload_stage() -> void:
	if StageMap.root != null and is_instance_valid(StageMap.root):
		StageMap.root.free()
	StageMap.root = null
	StageMap.scene_path = ""
	ResourceLoader.load(TutorialStage.SCENE_PATH, "", ResourceLoader.CACHE_MODE_REPLACE)
	TutorialStage.use()


func _encounter(units: Array[MechState]) -> EncounterData:
	return EncounterData.create_from_tactic(units[0], BattleTactic.standard(), units)


func _ids(encounter: EncounterData) -> PackedStringArray:
	var names: PackedStringArray = []
	for unit in encounter.participants:
		names.append(unit.data.id)
	names.sort()
	return names


func _has(encounter: EncounterData, mech_id: String) -> bool:
	for unit in encounter.participants:
		if unit.data.id == mech_id:
			return true
	return false


func _find(units: Array[MechState], mech_id: String) -> MechState:
	for unit in units:
		if unit.data.id == mech_id:
			return unit
	return null


func _in_range(raven: MechState, origin: Vector2i, units: Array[MechState]) -> bool:
	for unit in units:
		if unit.team != "enemy":
			continue
		if raven.attacks_at(_manhattan(origin, unit.overworld_position)):
			return true
	return false


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _assert_open(coords: Vector2i) -> void:
	TutorialStage.use()
	assert_false(StageMap.blocked(coords), "open ground at %s" % coords)
