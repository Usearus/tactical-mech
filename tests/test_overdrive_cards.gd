@tool
extends McpTestSuite


func suite_name() -> String:
	return "overdrive_cards"


func test_last_card_is_held_for_overdrive() -> void:
	var expected := {
		"raven": "raven_screen",
		"comet": "comet_spark",
		"bulldog": "bulldog_anchor",
		"lancer": "lancer_charge",
		"barrage": "barrage_salvo",
	}
	for mech_id in expected:
		var deck := load("res://data/decks/player/%s.tres" % mech_id) as MechDeck
		var specials := deck.special_cards()
		assert_eq(specials.size(), 1, "%s has one overdrive card" % mech_id)
		assert_eq(specials[0].id, expected[mech_id], mech_id)
		var drawable := 0
		for card in deck.cards:
			if card == null or card.is_special:
				continue
			drawable += 1
		assert_eq(drawable, deck.cards.size() - 1, "%s keeps the other cards drawable" % mech_id)


func test_bulldog_stands_in_front() -> void:
	var deck := load("res://data/decks/player/bulldog.tres") as MechDeck
	var brace: CardData = null
	for card in deck.cards:
		if card != null and card.id == "bulldog_brace":
			brace = card
	assert_true(brace != null, "brace is in the deck")
	if brace == null:
		return
	assert_eq(brace.block, 5, "brace adds 5 guard")
	assert_eq(brace.movement, 2, "brace steps 2")
	assert_true(brace.intercept, "brace catches the next hit")
	assert_false(brace.is_special, "brace is a normal card")
	var anchor := deck.special_cards()[0]
	assert_eq(anchor.barrier, 6, "anchor adds 6 barrier")
	assert_eq(anchor.movement, 1, "anchor steps 1")
	assert_true(anchor.intercept, "anchor catches the next hit")
	assert_eq(anchor.target_type, "self", "anchor shields bulldog")


func test_overdrive_boosts_guard_like_attack() -> void:
	var saved_offense := GameManager.battle_offense
	var guard := CardData.new()
	guard.card_type = "Defense"
	guard.defense_kind = "Guard"
	var attack := CardData.new()
	attack.card_type = "Attack"
	GameManager.battle_offense = false
	guard.block = 5
	assert_eq(GameManager.card_block(guard), 5, "guard stays printed outside overdrive")
	GameManager.battle_offense = true
	for printed in [3, 4, 5, 11, 16]:
		guard.block = printed
		attack.damage = printed
		assert_eq(
			GameManager.card_block(guard),
			GameManager.card_damage(attack),
			"a %d guard gains the same bonus as a %d attack" % [printed, printed]
		)
	var dodge := CardData.new()
	dodge.card_type = "Defense"
	dodge.defense_kind = "Dodge"
	dodge.block = 5
	assert_eq(GameManager.card_block(dodge), 5, "a dodge keeps its printed block")
	GameManager.battle_offense = saved_offense


func test_barrage_salvo_hits_every_enemy_at_exact_range() -> void:
	var deck := load("res://data/decks/player/barrage.tres") as MechDeck
	var salvo := deck.special_cards()[0]
	assert_eq(salvo.damage, 6, "salvo hits for 6")
	assert_eq(salvo.reach, 3, "salvo reaches 3")
	assert_true(salvo.exact_range, "salvo only hits at that distance")
	assert_eq(salvo.movement, 1, "salvo steps 1")
	assert_eq(salvo.move_timing, "Before", "salvo steps before it fires")
	assert_eq(salvo.target_type, "enemies", "salvo hits every enemy in range")
	assert_eq(salvo.description, "Move 1 cell, hit every enemy exactly 3 cells away.")


func test_spark_banks_two_for_the_next_gauge() -> void:
	var saved_offense := GameManager.battle_offense
	var saved_gauge := GameManager.player_attack_gauge
	var saved_max := GameManager.player_attack_max
	var saved_bank := GameManager.player_banked_gauge
	GameManager.battle_offense = false
	GameManager.player_attack_gauge = 3
	GameManager.player_attack_max = 5
	GameManager.player_banked_gauge = 0
	var blocked := GameManager.charge_from_spark()
	assert_eq(int(blocked["banked"]), 0, "spark does nothing outside overdrive")
	assert_eq(GameManager.player_attack_gauge, 3, "the current gauge stays put")
	assert_eq(GameManager.player_banked_gauge, 0, "nothing is banked")
	GameManager.battle_offense = true
	GameManager.player_attack_gauge = 1
	var sparked := GameManager.charge_from_spark()
	assert_eq(int(sparked["banked"]), GameManager.SPARK_CHARGE, "spark banks its full grant")
	assert_eq(GameManager.player_attack_gauge, 1, "spark does not fill the current gauge")
	assert_eq(GameManager.player_banked_gauge, GameManager.SPARK_CHARGE, "the next gauge holds the charge")
	var card := load("res://data/decks/player/comet.tres").special_cards()[0] as CardData
	assert_eq(card.description, "Add 2 charge to your next overdrive gauge.")
	GameManager.battle_offense = saved_offense
	GameManager.player_attack_gauge = saved_gauge
	GameManager.player_attack_max = saved_max
	GameManager.player_banked_gauge = saved_bank
