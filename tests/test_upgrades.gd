@tool
extends McpTestSuite


func suite_name() -> String:
	return "upgrades"


func test_refreshes_last_the_whole_mission() -> void:
	var memory := MissionUpgrades.new()
	assert_eq(memory.refreshes_left, 2)
	assert_true(memory.spend_refresh())
	assert_eq(memory.refreshes_left, 1)
	assert_true(memory.spend_refresh())
	assert_eq(memory.refreshes_left, 0)
	assert_false(memory.spend_refresh())
	memory.clear()
	assert_eq(memory.refreshes_left, 2)


func test_clearing_memory_drops_the_bonus() -> void:
	var memory := MissionUpgrades.new()
	var offer := _damage_offer()
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", offer))
	memory.clear()
	assert_eq(memory.upgrade_count("bastion", "bastion_piledriver"), 0)
	var cards := UpgradeDeck.runtime_cards(_data("bastion"), memory)
	assert_eq(cards[0].display_name, "Piledriver")
	assert_eq(cards[0].damage, 7)


func test_family_strips_only_a_copy_suffix() -> void:
	assert_eq(UpgradeDeck.family_of("bastion_piledriver_2"), "bastion_piledriver")
	assert_eq(UpgradeDeck.family_of("bastion_piledriver"), "bastion_piledriver")
	assert_eq(UpgradeDeck.family_of("comet_slip_2"), "comet_slip")
	assert_eq(UpgradeDeck.family_of("lancer_extended_range"), "lancer_extended_range")
	assert_eq(UpgradeDeck.family_of("barrage_slide_fire"), "barrage_slide_fire")


func test_upgrade_does_not_rewrite_the_deck_file() -> void:
	var deck := load("res://data/decks/player/bastion.tres") as MechDeck
	var printed := deck.cards[0].damage
	var printed_name := deck.cards[0].display_name
	var memory := MissionUpgrades.new()
	var offer := _damage_offer()
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", offer))
	var cards := UpgradeDeck.runtime_cards(_data("bastion"), memory)
	assert_eq(cards[0].display_name, "Piledriver+")
	assert_eq(cards[0].damage, printed + 3)
	assert_true(cards[0].has_upgrade_mark("damage"))
	assert_false(cards[0].has_upgrade_mark("cost"))
	assert_eq(cards[1].id, "bastion_piledriver_2")
	assert_eq(cards[1].display_name, "Piledriver")
	assert_eq(cards[1].damage, printed)
	assert_eq(deck.cards[0].damage, printed)
	assert_eq(deck.cards[0].display_name, printed_name)
	assert_eq(deck.cards[1].damage, printed)


func test_second_upgrade_is_a_double_plus_and_a_third_is_refused() -> void:
	var memory := MissionUpgrades.new()
	var damage := _damage_offer()
	var free := UpgradeOffer.new()
	free.make_free = true
	free.blurb = "Upgraded: costs no action."
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", damage))
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", free))
	assert_false(memory.apply_modify("bastion", "bastion_piledriver", damage))
	assert_eq(memory.upgrade_count("bastion", "bastion_piledriver"), 2)
	var cards := UpgradeDeck.runtime_cards(_data("bastion"), memory)
	assert_eq(cards[0].display_name, "Piledriver++")
	assert_eq(cards[0].damage, 10)
	assert_false(cards[0].pays_action())
	assert_true(cards[0].has_upgrade_mark("damage"))
	assert_true(cards[0].has_upgrade_mark("cost"))
	assert_true(cards[0].description.contains("Upgraded: +3 damage."))
	assert_true(cards[0].description.contains("Upgraded: costs no action."))
	assert_eq(cards[1].display_name, "Piledriver")
	assert_eq(cards[1].damage, 7)
	assert_true(cards[1].pays_action())


func test_added_movement_steps_before_the_strike() -> void:
	var memory := MissionUpgrades.new()
	var offer := UpgradeOffer.new()
	offer.movement_add = 1
	offer.movement_timing = "Before"
	offer.blurb = "Upgraded: +1 movement."
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", offer))
	var cards := UpgradeDeck.runtime_cards(_data("bastion"), memory)
	assert_eq(cards[0].movement, 1)
	assert_eq(cards[0].move_timing, "Before")
	assert_true(cards[0].moves_before())
	assert_true(cards[0].has_upgrade_mark("movement"))
	assert_eq(cards[1].movement, 0)
	assert_eq(cards[1].move_timing, "None")


func test_a_grant_is_added_only_to_that_mech() -> void:
	var memory := MissionUpgrades.new()
	var card := CardData.new()
	card.id = "test_grant"
	card.display_name = "Test Grant"
	card.card_type = "Attack"
	card.damage = 4
	memory.add_grant("bastion", card)
	var bastion := UpgradeDeck.runtime_cards(_data("bastion"), memory)
	var comet := UpgradeDeck.runtime_cards(_data("comet"), memory)
	assert_true(_has_id(bastion, "test_grant"))
	assert_false(_has_id(comet, "test_grant"))


func test_a_dead_mech_can_only_be_revived() -> void:
	var bastion := _mech("bastion", false)
	var comet := _mech("comet", true)
	var legal := UpgradeRoller.legal_choices([bastion, comet], MissionUpgrades.new())
	var saw_revive := false
	for choice in legal:
		if choice.bound_mech == bastion:
			assert_eq(choice.kind, "Revive")
			assert_eq(choice.preview.display_name, "Revive Bastion")
			saw_revive = true
			assert_eq(choice.rarity, 3)
		if choice.kind == "Immediate":
			assert_true(false, "a group effect needs two living mechs")
		if choice.bound_mech == bastion and (choice.kind == "Grant" or choice.kind == "Modify"):
			assert_true(false, "a destroyed mech does not take a card")
	assert_true(saw_revive)


func test_group_effects_need_two_survivors() -> void:
	var alone := UpgradeRoller.legal_choices([_mech("bastion"), _mech("comet", false)], MissionUpgrades.new())
	var together := UpgradeRoller.legal_choices([_mech("bastion"), _mech("comet")], MissionUpgrades.new())
	assert_false(_has_kind(alone, "Immediate"))
	assert_true(_has_kind(together, "Immediate"))


func test_revive_returns_half_health_and_barrier_sticks() -> void:
	var bastion := _mech("bastion", false)
	var comet := _mech("comet")
	var revive := UpgradeChoice.new()
	revive.kind = "Revive"
	revive.bound_mech = bastion
	UpgradeDeck.apply(revive, MissionUpgrades.new())
	assert_true(bastion.alive)
	assert_eq(bastion.hp, 11)
	var offer := UpgradeOffer.new()
	offer.barrier = 5
	var group := UpgradeChoice.new()
	group.kind = "Immediate"
	group.offer = offer
	var owners: Array[MechState] = []
	owners.append(bastion)
	owners.append(comet)
	group.mechs = owners
	UpgradeDeck.apply(group, MissionUpgrades.new())
	assert_eq(bastion.standing_guard, 5)
	assert_eq(comet.standing_guard, 5)


func test_a_row_can_hold_more_than_one_three_star() -> void:
	var legal: Array = []
	for index in 4:
		legal.append(_choice("Modify", 3, "mod%d" % index))
		legal.append(_choice("Grant", 3, "grant%d" % index))
	var odds := DraftOdds.new()
	odds.weight_1 = 0
	odds.weight_2 = 0
	odds.weight_3 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var row: Array = UpgradeRoller.pick(legal, odds, rng)
	var stars := 0
	var kinds := {}
	for choice in row:
		var item := choice as UpgradeChoice
		if item.rarity == 3:
			stars += 1
		kinds[item.kind] = true
	assert_eq(row.size(), 3)
	assert_true(stars >= 2)
	assert_true(kinds.size() >= 2)


func test_a_row_is_never_three_of_one_kind() -> void:
	var legal: Array = []
	for index in 6:
		legal.append(_choice("Modify", 1, "mod%d" % index))
		legal.append(_choice("Grant", 2, "grant%d" % index))
		legal.append(_choice("Immediate", 3, "imm%d" % index))
	var odds := DraftOdds.new()
	odds.weight_1 = 60
	odds.weight_2 = 30
	odds.weight_3 = 10
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for _step in 40:
		var row: Array = UpgradeRoller.pick(legal, odds, rng)
		assert_eq(row.size(), 3)
		var counts := {}
		for choice in row:
			var item := choice as UpgradeChoice
			counts[item.kind] = int(counts.get(item.kind, 0)) + 1
		assert_true(counts.size() >= 2)
		for kind in counts.keys():
			assert_true(int(counts[kind]) < 3, "three %s cards" % str(kind))


func test_one_kind_stops_at_two_cards() -> void:
	var legal: Array = []
	for index in 5:
		legal.append(_choice("Revive", 1, "rev%d" % index))
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var row: Array = UpgradeRoller.pick(legal, odds, rng)
	assert_eq(row.size(), 2)


func test_the_same_buff_is_not_offered_twice_in_one_row() -> void:
	var legal: Array = []
	legal.append(_buff_choice("Immediate", 1, "immediate:pulse", ["buff:barrier"]))
	legal.append(_buff_choice("Immediate", 2, "immediate:wall", ["buff:barrier"]))
	legal.append(_buff_choice("Immediate", 3, "immediate:dome", ["buff:barrier"]))
	legal.append(_buff_choice("Modify", 1, "modify:rocket", ["buff:damage"]))
	legal.append(_buff_choice("Modify", 2, "modify:slide", ["buff:damage"]))
	legal.append(_buff_choice("Modify", 1, "modify:boost", ["buff:movement"]))
	legal.append(_buff_choice("Grant", 1, "grant:bombard", []))
	legal.append(_buff_choice("Grant", 2, "grant:sidestep", []))
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	odds.weight_2 = 1
	odds.weight_3 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for _step in 30:
		var row: Array = UpgradeRoller.pick(legal, odds, rng)
		var seen := {}
		for choice in row:
			var item := choice as UpgradeChoice
			for key in item.buff_keys:
				assert_false(seen.has(key), str(key))
				seen[key] = true


func test_squad_barrier_tiers_are_one_buff() -> void:
	var legal := UpgradeRoller.legal_choices([_mech("bastion"), _mech("comet")], MissionUpgrades.new())
	var barriers := 0
	for choice in legal:
		if choice.kind != "Immediate":
			continue
		barriers += 1
		assert_true(choice.buff_keys.has("buff:barrier"), choice.slot_key)
	assert_true(barriers >= 2)
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	odds.weight_2 = 1
	odds.weight_3 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for _step in 25:
		var row: Array = UpgradeRoller.pick(legal, odds, rng)
		var shown := 0
		for choice in row:
			if (choice as UpgradeChoice).kind == "Immediate":
				shown += 1
		assert_true(shown <= 1)


func test_the_same_card_is_not_offered_twice_in_one_row() -> void:
	var legal: Array = []
	legal.append(_choice("Modify", 2, "modify:bastion:bastion_piledriver"))
	legal.append(_choice("Modify", 3, "modify:bastion:bastion_piledriver"))
	legal.append(_choice("Grant", 1, "grant:bastion:ram"))
	legal.append(_choice("Grant", 1, "grant:bastion:fort"))
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	odds.weight_2 = 1
	odds.weight_3 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for _step in 20:
		var row: Array = UpgradeRoller.pick(legal, odds, rng)
		var seen := {}
		for choice in row:
			var item := choice as UpgradeChoice
			assert_false(seen.has(item.slot_key), item.slot_key)
			seen[item.slot_key] = true


func test_missing_rarity_falls_back_to_a_card_that_exists() -> void:
	var legal: Array = []
	for index in 3:
		legal.append(_choice("Modify", 1, "mod%d" % index))
		legal.append(_choice("Grant", 1, "grant%d" % index))
	var odds := DraftOdds.new()
	odds.weight_1 = 0
	odds.weight_2 = 0
	odds.weight_3 = 5
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	var row: Array = UpgradeRoller.pick(legal, odds, rng)
	assert_eq(row.size(), 3)
	for choice in row:
		assert_eq((choice as UpgradeChoice).rarity, 1)


func test_rarity_weights_can_roll_each_star() -> void:
	var odds := load("res://data/upgrades/draft_odds.tres") as DraftOdds
	assert_eq(odds.weight_1, 60)
	assert_eq(odds.weight_2, 30)
	assert_eq(odds.weight_3, 10)
	assert_eq(odds.refreshes_per_mission, 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var counts := {1: 0, 2: 0, 3: 0}
	for _step in 500:
		var band := odds.roll_rarity(rng)
		counts[band] = int(counts[band]) + 1
	assert_true(int(counts[1]) > 0)
	assert_true(int(counts[2]) > 0)
	assert_true(int(counts[3]) > 0)
	assert_true(int(counts[1]) > int(counts[3]))


func test_rarity_follows_the_fight() -> void:
	var odds := DraftOdds.new()
	odds.weight_1 = 60
	odds.weight_2 = 30
	odds.weight_3 = 10
	var even := odds.for_fight(2, 2)
	assert_eq(even.weight_1, 60)
	assert_eq(even.weight_2, 30)
	assert_eq(even.weight_3, 10)
	assert_eq(odds.for_fight(3, 3).weight_3, 10)
	assert_eq(odds.weight_1, 60)
	var small := odds.for_fight(1, 1)
	assert_true(small.weight_2 < odds.weight_2)
	assert_true(small.weight_3 < odds.weight_3)
	assert_true(small.weight_1 > odds.weight_1)
	var favored := odds.for_fight(3, 1)
	assert_true(favored.weight_3 < odds.weight_3)
	var behind := odds.for_fight(2, 3)
	assert_true(behind.weight_2 > odds.weight_2)
	assert_true(behind.weight_3 > odds.weight_3)
	assert_true(behind.weight_1 < odds.weight_1)


func test_a_common_roll_is_not_promoted_to_a_rarer_kind() -> void:
	var legal: Array = []
	legal.append(_choice("Modify", 1, "mod-a"))
	legal.append(_choice("Modify", 1, "mod-b"))
	legal.append(_choice("Grant", 1, "grant-a"))
	legal.append(_choice("Grant", 2, "grant-b"))
	legal.append(_choice("Immediate", 2, "wall"))
	legal.append(_choice("Immediate", 3, "dome"))
	legal.append(_choice("Revive", 3, "revive"))
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	odds.weight_2 = 0
	odds.weight_3 = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for _step in 40:
		var row: Array = UpgradeRoller.pick(legal, odds, rng)
		assert_eq(row.size(), 3)
		for choice in row:
			assert_eq((choice as UpgradeChoice).rarity, 1)


func test_group_cards_show_up_less_than_upgrades() -> void:
	var legal: Array = []
	for index in 8:
		legal.append(_choice("Modify", 1, "mod%d" % index))
		legal.append(_choice("Immediate", 1, "imm%d" % index))
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var group := 0
	var modify := 0
	for _step in 80:
		for choice in UpgradeRoller.pick(legal, odds, rng):
			var item := choice as UpgradeChoice
			if item.kind == "Immediate":
				group += 1
			elif item.kind == "Modify":
				modify += 1
	assert_true(modify > group)


func test_upgrade_lines_use_the_boost_blue() -> void:
	var copy := "A heavy spike driven in up close. Upgraded: +3 damage. Upgraded: costs no action."
	var shown := MechCard.tint_upgrade_copy(copy)
	var hex := MechCard.ENHANCED_COLOR.to_html(false)
	assert_true(shown.begins_with("A heavy spike driven in up close. "))
	assert_false(shown.contains("Upgraded:"))
	assert_true(shown.contains("[color=#%s](+3 damage)[/color]" % hex))
	assert_true(shown.contains("[color=#%s](costs no action)[/color]" % hex))
	assert_eq(MechCard.tint_upgrade_copy("Step 2, then a heavy strike."), "Step 2, then a heavy strike.")
	var anchor := CardData.new()
	anchor.movement = 3
	anchor.mark_upgrade("movement")
	var anchor_copy := "Add barrier, step 2 cells, and catch next hit on an ally. Upgraded: +1 movement."
	var tinted := MechCard.tint_upgrade_copy(anchor_copy, anchor)
	assert_true(tinted.contains("[color=#%s]step 3 cells[/color]" % hex))
	assert_true(tinted.ends_with("[color=#%s](+1 movement)[/color]" % hex))
	assert_true(tinted.begins_with("Add barrier, "))
	var slip := CardData.new()
	slip.movement = 2
	slip.mark_upgrade("movement")
	var slip_copy := "Add guard to self, step 1 cell, and catch next hit on an ally. Upgraded: +1 movement."
	var slip_shown := MechCard.tint_upgrade_copy(slip_copy, slip)
	assert_eq(
		slip_shown,
		"Add guard to self, [color=#%s]step 2 cells[/color], and catch next hit on an ally. [color=#%s](+1 movement)[/color]" % [hex, hex]
	)
	var group := MechCard.instant_use_copy("Each mech that fought gains 3 barrier.")
	assert_eq(group, "[color=#%s]Instant use:[/color] Each mech that fought gains 3 barrier." % hex)


func test_a_cleared_roster_is_the_end_of_the_mission() -> void:
	var living := _mech("bastion")
	var dead := _mech("comet", false)
	assert_true(UpgradeRoller.any_alive([living, dead]))
	assert_false(UpgradeRoller.any_alive([dead]))
	assert_false(UpgradeRoller.any_alive([]))


func test_catalog_offers_match_real_cards() -> void:
	for mech_id in ["bastion", "bulldog", "comet", "lancer", "barrage", "raven"]:
		var catalog := load("res://data/upgrades/player/%s.tres" % mech_id) as UpgradeCatalog
		assert_true(catalog != null, mech_id)
		var families := UpgradeDeck.families_in(_data(mech_id))
		var grants := 0
		var modifies := 0
		for offer in catalog.offers:
			if offer.kind == "Modify":
				modifies += 1
				assert_true(families.has(offer.card_family), offer.card_family)
			elif offer.kind == "Grant":
				grants += 1
				assert_true(offer.card != null, offer.id)
				assert_true(offer.card.id != "", offer.id)
		assert_true(modifies > 0, mech_id)
		assert_true(grants > 0, mech_id)
		for offer in catalog.offers:
			if offer.kind != "Grant" or offer.card == null:
				continue
			assert_true(offer.card.movement > 0, offer.card.display_name)
			assert_true(offer.card.damage > 0 or offer.card.block > 0, offer.card.display_name)
	var team := load("res://data/upgrades/team.tres") as UpgradeCatalog
	assert_true(team.offers.size() >= 2)
	var revive := load("res://data/upgrades/revive.tres") as UpgradeOffer
	assert_eq(revive.kind, "Revive")
	assert_eq(revive.rarity, 3)


func test_a_capped_card_drops_out_of_the_draft() -> void:
	var memory := MissionUpgrades.new()
	var offer := _damage_offer()
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", offer))
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", offer))
	var legal := UpgradeRoller.legal_choices([_mech("bastion"), _mech("comet")], memory)
	for choice in legal:
		assert_false(choice.family == "bastion_piledriver")


func _damage_offer() -> UpgradeOffer:
	var offer := UpgradeOffer.new()
	offer.damage_add = 3
	offer.blurb = "Upgraded: +3 damage."
	return offer


func _choice(kind: String, rarity: int, key: String) -> UpgradeChoice:
	return _buff_choice(kind, rarity, key, [])


func _buff_choice(kind: String, rarity: int, key: String, buffs: Array) -> UpgradeChoice:
	var choice := UpgradeChoice.new()
	choice.kind = kind
	choice.rarity = rarity
	choice.slot_key = key
	var keys: PackedStringArray = []
	for buff in buffs:
		keys.append(str(buff))
	choice.buff_keys = keys
	return choice


func _data(mech_id: String) -> MechData:
	return load("res://data/mechs/player/%s.tres" % mech_id) as MechData


func _mech(mech_id: String, alive := true) -> MechState:
	var unit := MechState.from_data(_data(mech_id), Vector2i.ZERO)
	unit.alive = alive
	if not alive:
		unit.hp = 0
	return unit


func _has_id(cards: Array[CardData], card_id: String) -> bool:
	for card in cards:
		if card != null and card.id == card_id:
			return true
	return false


func _has_kind(choices: Array[UpgradeChoice], kind: String) -> bool:
	for choice in choices:
		if choice.kind == kind:
			return true
	return false
