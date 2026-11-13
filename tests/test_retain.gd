@tool
extends McpTestSuite


func suite_name() -> String:
	return "retain"


func test_retain_leads_the_card_copy() -> void:
	var evade := CardData.new()
	evade.retain = true
	evade.description = "Evade 1 attack entirely if in hand."
	var shown := MechCard.shown_copy(evade)
	assert_true(shown.begins_with("[gold]Retain.[/gold] "))
	assert_true(shown.ends_with("Evade 1 attack entirely if in hand."))
	var plain := CardData.new()
	plain.description = "Hit one enemy in range."
	assert_eq(MechCard.shown_copy(plain), "Hit one enemy in range.")
	var boosted := CardData.new()
	boosted.retain = true
	boosted.movement = 2
	boosted.mark_upgrade("movement")
	boosted.description = "Step up to 1 cell. Upgraded: +1 movement."
	var tinted := MechCard.shown_copy(boosted)
	assert_true(tinted.begins_with("[gold]Retain.[/gold] "))
	assert_false(tinted.contains("Upgraded:"))


func test_only_evade_retains() -> void:
	var found := false
	for mech_id in ["raven", "comet", "bulldog", "bastion", "lancer", "barrage"]:
		var deck := load("res://data/decks/player/%s.tres" % mech_id) as MechDeck
		assert_true(deck != null, mech_id)
		for card in deck.cards:
			if card == null:
				continue
			if card.id == "raven_evade":
				found = true
				assert_true(card.retain, card.id)
				assert_eq(card.description, "Evade 1 attack entirely if in hand.")
			else:
				assert_false(card.retain, card.id)
	assert_true(found, "evade is in raven's deck")


func test_the_active_card_lists_retain_under_effects() -> void:
	var evade := CardData.new()
	evade.card_type = "Defense"
	evade.defense_kind = "Dodge"
	evade.retain = true
	var box := CardEffectBox.new()
	var rows := box._effect_rows(evade, 0, 0)
	assert_eq(rows.size(), 2)
	assert_eq(str(rows[0]["text"]), "1 evade")
	assert_eq(str(rows[1]["text"]), CardEffectBox.RETAIN_EFFECT)
	var strike := CardData.new()
	strike.card_type = "Attack"
	strike.damage = 4
	strike.reach = 1
	for row in box._effect_rows(strike, 4, 0):
		assert_false(str(row["text"]).contains("Retain"))
	box.free()


func test_fight_one_holds_the_second_burst_until_round_two() -> void:
	var deck: Array[CardData] = []
	var hand: Array[CardData] = []
	for card_id in ["raven_burst_fire", "raven_burst_fire_2", "raven_snap_shot", "raven_strafe", "raven_blink"]:
		var card := CardData.new()
		card.id = card_id
		deck.append(card)
	TutorialHands.arrange(deck, hand, "b1", 3, 1)
	var opening: PackedStringArray = []
	for card in hand:
		opening.append(card.id)
	assert_true(opening.has("raven_burst_fire"))
	assert_false(opening.has("raven_burst_fire_2"))
	assert_eq(deck[deck.size() - 1].id, "raven_burst_fire_2")
	hand.clear()
	TutorialHands.arrange(deck, hand, "b1", 3, 2)
	var round_two: PackedStringArray = []
	for card in hand:
		round_two.append(card.id)
	assert_true(round_two.has("raven_burst_fire_2"))


func test_fight_two_deals_burst_fire_on_the_second_round() -> void:
	var deck: Array[CardData] = []
	var hand: Array[CardData] = []
	for card_id in ["comet_dart", "comet_dart_2", "raven_snap_shot", "raven_burst_fire", "raven_burst_fire_2", "raven_strafe"]:
		var card := CardData.new()
		card.id = card_id
		deck.append(card)
	TutorialHands.arrange(deck, hand, "b2", 4, 1)
	var opening: PackedStringArray = []
	for card in hand:
		opening.append(card.id)
	assert_true(opening.has("raven_burst_fire"))
	assert_false(opening.has("raven_burst_fire_2"))
	assert_eq(deck[deck.size() - 1].id, "raven_burst_fire_2")
	hand.clear()
	TutorialHands.arrange(deck, hand, "b2", 4, 2)
	var round_two: PackedStringArray = []
	for card in hand:
		round_two.append(card.id)
	assert_true(round_two.has("raven_burst_fire_2"))
