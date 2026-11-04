@tool
extends McpTestSuite

const TRIALS := 800
const HAND := 3


func suite_name() -> String:
	return "tactic_draw"


func test_the_commence_row_marks_only_a_tactic_with_a_bonus() -> void:
	assert_eq(BattleTactic.by_id("offense").bonus_note(), "Slightly increase \"Offense\" card pulls.")
	assert_eq(BattleTactic.standard().bonus_note(), "Slightly increase \"Defense\" card pulls.")
	assert_eq(BattleTactic.by_id("north").bonus_note(), "")
	assert_eq(BattleTactic.by_id("south").bonus_note(), "")
	var scene := ResourceLoader.load("res://scenes/ui/tactic_choice.tscn", "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	var row := scene.instantiate()
	assert_true(row.get_node_or_null("%Button") != null, "tactic button")
	var tip := row.get_node_or_null("%Tip") as CanvasItem
	assert_true(tip != null, "tactic tip")
	assert_false(tip.visible, "the mark stays off until a bonus is set")
	row.free()


func test_offense_and_defense_name_the_favored_type() -> void:
	assert_eq(BattleTactic.by_id("offense").favored_card_type(), "Attack")
	assert_eq(BattleTactic.standard().favored_card_type(), "Defense")
	assert_eq(BattleTactic.by_id("north").favored_card_type(), "")
	assert_eq(BattleTactic.by_id("south").favored_card_type(), "")
	assert_eq(BattleTactic.by_id("westward").favored_card_type(), "")


func test_a_fair_draw_takes_the_back_of_the_pile() -> void:
	var pile := _pile(3, 3)
	var order: PackedStringArray = []
	for card in pile:
		order.append(card.id)
	for index in range(order.size() - 1, -1, -1):
		var drawn := TacticDraw.take(pile, "")
		assert_eq(drawn.id, order[index])
	assert_eq(pile.size(), 0)


func test_each_card_is_drawn_once() -> void:
	var pile := _pile(4, 4)
	var seen := {}
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	while not pile.is_empty():
		var card := TacticDraw.take(pile, "Attack", rng)
		assert_false(seen.has(card.id), card.id)
		seen[card.id] = true
	assert_eq(seen.size(), 8)


func test_offense_tilts_both_rounds_toward_attack() -> void:
	_assert_both_rounds("Attack", 21)


func test_defense_tilts_both_rounds_toward_defense() -> void:
	_assert_both_rounds("Defense", 22)


func _assert_both_rounds(favored: String, seed: int) -> void:
	var first_hits := 0
	var second_hits := 0.0
	var second_fair := 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	for _trial in TRIALS:
		var pile := _pile(6, 6)
		var first := TacticDraw.take(pile, favored, rng)
		if first.card_type == favored:
			first_hits += 1
		for _extra in HAND - 1:
			TacticDraw.take(pile, favored, rng)
		var remaining := pile.size()
		var left := 0
		for card in pile:
			if card.card_type == favored:
				left += 1
		var round_two := 0
		for _card in HAND:
			var drawn := TacticDraw.take(pile, favored, rng)
			if drawn.card_type == favored:
				round_two += 1
		second_hits += round_two
		second_fair += float(HAND) * float(left) / float(remaining)
	var first_rate := float(first_hits) / float(TRIALS)
	assert_true(first_rate > 0.52 and first_rate < 0.64, "%s first draw %s" % [favored, first_rate])
	var lift := (second_hits - second_fair) / float(TRIALS)
	assert_true(lift > 0.05, "%s round two lift %s" % [favored, lift])


func _pile(attacks: int, defenses: int) -> Array[CardData]:
	var pile: Array[CardData] = []
	for index in attacks:
		pile.append(_card("a%d" % index, "Attack"))
	for index in defenses:
		pile.append(_card("d%d" % index, "Defense"))
	return pile


func _card(card_id: String, kind: String) -> CardData:
	var card := CardData.new()
	card.id = card_id
	card.card_type = kind
	return card
