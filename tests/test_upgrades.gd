@tool
extends McpTestSuite

const EDICT_BONUS := preload("res://scripts/game/edict_amounts.gd")


func suite_name() -> String:
	return "upgrades"


func test_a_refresh_does_not_repeat_a_shown_pull() -> void:
	var units: Array = [_mech("bastion"), _mech("comet")]
	var memory := MissionUpgrades.new()
	var odds := DraftOdds.new()
	odds.weight_1 = 1
	odds.weight_2 = 1
	odds.weight_3 = 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 15
	var seen := {}
	for _step in 3:
		var row: Array = UpgradeRoller.roll(units, memory, odds, rng, seen)
		assert_true(row.size() >= 2)
		for choice in row:
			var pull := UpgradeRoller.pull_id(choice)
			assert_false(seen.has(pull), pull)
			seen[pull] = true


func test_the_other_boost_on_a_shown_card_can_still_appear() -> void:
	var damage := _choice("Modify", 2, "modify:bastion:bastion_piledriver")
	damage.offer = UpgradeOffer.new()
	damage.offer.id = "bastion_piledriver_damage"
	var free := _choice("Modify", 3, "modify:bastion:bastion_piledriver")
	free.offer = UpgradeOffer.new()
	free.offer.id = "bastion_piledriver_free"
	var seen := {UpgradeRoller.pull_id(damage): true}
	var pool := UpgradeRoller.fresh_pool([damage, free], seen)
	assert_eq(pool.size(), 1)
	assert_eq(UpgradeRoller.pull_id(pool[0]), UpgradeRoller.pull_id(free))
	assert_false(UpgradeRoller.has_unseen([damage], seen))
	assert_true(UpgradeRoller.has_unseen([damage, free], seen))


func test_a_spent_pool_still_deals_when_nothing_new_is_left() -> void:
	var first := _choice("Grant", 1, "grant:ram")
	var second := _choice("Modify", 1, "modify:spike")
	var seen := {
		UpgradeRoller.pull_id(first): true,
		UpgradeRoller.pull_id(second): true,
	}
	var pool := UpgradeRoller.fresh_pool([first, second], seen)
	assert_eq(pool.size(), 2)
	assert_false(UpgradeRoller.has_unseen([first, second], seen))


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


func test_a_wiped_fight_offers_no_reward() -> void:
	var solo := UpgradeRoller.legal_choices([_mech("bastion", false)], MissionUpgrades.new())
	var pair := UpgradeRoller.legal_choices(
		[_mech("bastion", false), _mech("comet", false)],
		MissionUpgrades.new()
	)
	assert_eq(solo.size(), 0)
	assert_eq(pair.size(), 0)
	var survivor := UpgradeRoller.legal_choices(
		[_mech("bastion", false), _mech("comet", true)],
		MissionUpgrades.new()
	)
	assert_true(_has_kind(survivor, "Revive"))


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
	var duel := odds.for_fight(1, 1)
	assert_eq(duel.weight_1, 60)
	assert_eq(duel.weight_2, 30)
	assert_eq(duel.weight_3, 10)
	var favored := odds.for_fight(3, 1)
	assert_true(favored.weight_3 < odds.weight_3)
	var behind := odds.for_fight(2, 3)
	assert_eq(behind.weight_1, 20)
	assert_eq(behind.weight_2, 60)
	assert_eq(behind.weight_3, 20)
	assert_eq(DraftOdds.fight_band(2, 2), "even")
	assert_eq(DraftOdds.fight_band(3, 3), "even")
	assert_eq(DraftOdds.fight_band(1, 1), "even")
	assert_eq(DraftOdds.fight_band(3, 1), "advantaged")
	assert_eq(DraftOdds.fight_band(2, 3), "disadvantaged")


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
	var anchor_copy := "Step up to 2 cells, apply barrier to self, and apply 1 intercept. Upgraded: +1 movement."
	var tinted := MechCard.tint_upgrade_copy(anchor_copy, anchor)
	assert_true(tinted.contains("[color=#%s]Step up to 3 cells[/color]" % hex))
	assert_true(tinted.ends_with("[color=#%s](+1 movement)[/color]" % hex))
	assert_true(tinted.begins_with("[color=#%s]Step up to 3 cells[/color]" % hex))
	var slip := CardData.new()
	slip.movement = 2
	slip.mark_upgrade("movement")
	var slip_copy := "Step up to 1 cell, apply guard to self, and apply 1 intercept. Upgraded: +1 movement."
	var slip_shown := MechCard.tint_upgrade_copy(slip_copy, slip)
	assert_eq(
		slip_shown,
		"[color=#%s]Step up to 2 cells[/color], apply guard to self, and apply 1 intercept. [color=#%s](+1 movement)[/color]" % [hex, hex]
	)
	var group := MechCard.instant_use_copy("Each mech that fought gains 3 barrier.")
	assert_eq(group, "[color=#%s]Instant use:[/color] Each mech that fought gains 3 barrier." % hex)


func test_a_cleared_roster_is_the_end_of_the_mission() -> void:
	var living := _mech("bastion")
	var dead := _mech("comet", false)
	assert_true(UpgradeRoller.any_alive([living, dead]))
	assert_false(UpgradeRoller.any_alive([dead]))
	assert_false(UpgradeRoller.any_alive([]))


func test_an_edict_lists_every_living_mech() -> void:
	var bastion := _mech("bastion")
	var comet := _mech("comet")
	var fallen := _mech("lancer", false)
	var memory := MissionUpgrades.new()
	var legal := UpgradeRoller.legal_choices([bastion, comet, fallen], memory)
	var edicts := 0
	var picked: UpgradeChoice
	for choice in legal:
		if choice.kind != "Edict":
			continue
		edicts += 1
		assert_eq(choice.mechs.size(), 2, choice.slot_key)
		assert_true(choice.mechs.has(bastion), choice.slot_key)
		assert_true(choice.mechs.has(comet), choice.slot_key)
		assert_false(choice.mechs.has(fallen), choice.slot_key)
		picked = choice
	assert_eq(edicts, 6)
	UpgradeDeck.apply(picked, memory)
	assert_true(memory.has_edict(picked.offer.id))
	var again := UpgradeRoller.legal_choices([bastion, comet], memory)
	for choice in again:
		if choice.kind != "Edict":
			continue
		assert_true(choice.offer.id != picked.offer.id)
		assert_eq(choice.mechs.size(), 2)
	memory.clear()
	assert_false(memory.has_edict(picked.offer.id))


func test_the_battle_bonus_panel_lists_the_tactic_then_the_edicts() -> void:
	var row_scene := _reload_scene("res://scenes/ui/bonus_panel_row.tscn")
	var row := row_scene.instantiate()
	assert_true(row.get_node_or_null("%Name") != null, "bonus panel name")
	assert_true(row.get_node_or_null("%Tip") != null, "bonus panel tip")
	assert_true(row.get_node_or_null("Rule") != null, "bonus panel rule")
	assert_true(row.find_child("Star1", true, false) == null, "no rarity stars")
	row.free()
	var scene := _reload_scene("res://scenes/ui/bonus_panel.tscn")
	assert_true(scene != null, "bonus panel scene")
	var tree := Engine.get_main_loop() as SceneTree
	var panel := scene.instantiate()
	panel.visible = false
	tree.root.add_child(panel)
	track(panel)
	var flank := BattleTactic.by_id("north")
	var below := BattleTactic.by_id("south")
	assert_false(flank.shows_on_panel(), "flank above stays off the panel")
	assert_false(below.shows_on_panel(), "flank below stays off the panel")
	var bonuses: Array[Dictionary] = [
		{"name": "Primed", "tip": "Each battle adds 3 charge."},
		{"name": "Opening Strike", "tip": "The first attack card each battle deals 3 extra damage."},
	]
	panel.show_entries("", flank.note, bonuses)
	var rows := panel.get_node("%Rows").get_children()
	var names: PackedStringArray = []
	for child in rows:
		var label := child.get_node("%Name") as Label
		names.append("" if label == null else label.text)
		assert_true(child.get_node_or_null("%Tip") != null, "each row keeps a tip")
	assert_eq(names, PackedStringArray(["Primed", "Opening Strike"]))
	assert_eq(str(rows[0].get_node("%Tip").get_meta("note")), "Each battle adds 3 charge.")
	var offense := BattleTactic.by_id("offense")
	var defense := BattleTactic.standard()
	assert_eq(offense.line_name(), "Offense tactics")
	assert_eq(defense.line_name(), "Defense tactics")
	assert_eq(offense.note, "Slightly increase \"Offense\" card pulls.")
	assert_eq(defense.note, "Slightly increase \"Defense\" card pulls.")
	panel.show_entries(offense.line_name(), offense.note, bonuses)
	var offense_tip := panel.get_node("%Rows").get_children()[0].get_node("%Tip") as CanvasItem
	assert_true(offense_tip.visible, "offense keeps a tip")
	assert_eq(str(offense_tip.get_meta("note")), offense.note)


func test_the_bonus_scenes_load() -> void:
	var row_scene := _reload_scene("res://scenes/ui/bonus_row.tscn")
	assert_true(row_scene != null, "bonus row scene")
	var row := row_scene.instantiate() as BonusRow
	assert_true(row != null, "bonus row instance")
	assert_true(row.get_node_or_null("%Name") != null, "bonus name")
	assert_true(row.get_node_or_null("%Blurb") != null, "bonus blurb")
	row.free()
	var corner_scene := _reload_scene("res://scenes/ui/menu_corner.tscn")
	assert_true(corner_scene != null, "menu corner scene")
	var corner := corner_scene.instantiate()
	var star := corner.get_node_or_null("StarButton") as BaseButton
	assert_true(star != null, "star button")
	corner.free()
	var menu := _reload_scene("res://scenes/ui/game_menu.tscn")
	assert_true(menu != null, "game menu scene")
	var page := menu.instantiate()
	assert_true(page.get_node_or_null("%Bonuses") != null, "bonuses page")
	assert_true(page.get_node_or_null("%BonusList") != null, "bonus list")
	page.free()


func test_active_edicts_follow_pick_order() -> void:
	var memory := MissionUpgrades.new()
	memory.add_edict("edict_primed")
	memory.add_edict("edict_opening_strike")
	var rows := memory.active_edicts()
	assert_eq(rows.size(), 2)
	assert_eq(rows[0].display_name, "Primed")
	assert_eq(rows[0].rarity, 3)
	assert_true(rows[0].blurb != "")
	assert_eq(rows[1].display_name, "Opening Strike")
	assert_eq(rows[1].rarity, 2)
	memory.clear()
	assert_eq(memory.active_edicts().size(), 0)


func test_opening_strike_and_plus_two_change_the_hit() -> void:
	var attack := _attack_card(4)
	var guard := _guard_card(3)
	var dodge := CardData.new()
	dodge.card_type = "Defense"
	dodge.defense_kind = "Dodge"
	dodge.block = 3
	assert_eq(EDICT_BONUS.attack_amount(attack, false, true, true), 9, "opening strike plus two")
	assert_eq(EDICT_BONUS.guard_amount(guard, false, false, true), 5, "plus two on guard")
	assert_eq(EDICT_BONUS.guard_amount(dodge, false, true, true), 3, "a dodge stays printed")
	assert_eq(EDICT_BONUS.attack_amount(attack, false, false, true), 6, "plus two remains after the first attack")
	assert_eq(EDICT_BONUS.attack_amount(attack, true, false, true), 7, "overdrive stacks on plus two")
	assert_eq(EDICT_BONUS.attack_amount(attack, false, false, false), 4, "a plain attack stays printed")


func test_opening_guard_leaves_after_the_first_guard() -> void:
	var guard := _guard_card(3)
	assert_eq(EDICT_BONUS.guard_amount(guard, false, true, true), 8, "opening guard plus two")
	assert_eq(EDICT_BONUS.guard_amount(guard, false, false, true), 5, "plus two remains after the first guard")
	assert_eq(EDICT_BONUS.guard_amount(guard, false, true, false), 6, "the next battle offers opening guard again")


func test_a_hand_card_shows_opening_strike_in_blue() -> void:
	var attack := _attack_card(4)
	var boosted := EDICT_BONUS.attack_amount(attack, false, true, false)
	assert_eq(boosted, 7)
	assert_true(boosted > attack.damage, "opening strike paints the attack blue")
	var spent := EDICT_BONUS.attack_amount(attack, false, false, false)
	assert_eq(spent, 4)
	assert_false(spent > attack.damage, "the blue leaves after the first attack")


func test_plus_two_keeps_the_attack_blue_after_opening_strike() -> void:
	var attack := _attack_card(4)
	var boosted := EDICT_BONUS.attack_amount(attack, false, true, true)
	assert_eq(boosted, 9)
	assert_true(boosted > attack.damage)
	var kept := EDICT_BONUS.attack_amount(attack, false, false, true)
	assert_eq(kept, 6)
	assert_true(kept > attack.damage, "plus two keeps the attack blue")
	var guard := _guard_card(3)
	var guarded := EDICT_BONUS.guard_amount(guard, false, false, true)
	assert_eq(guarded, 5)
	assert_true(guarded > guard.block, "plus two paints guard blue")


func test_field_repair_heals_living_fighters() -> void:
	var wounded := _mech("bastion")
	wounded.hp = 6
	assert_true(EDICT_BONUS.repairs(wounded))
	assert_eq(EDICT_BONUS.healed_hp(wounded.hp, wounded.data.max_hp), 8)
	assert_eq(EDICT_BONUS.healed_hp(wounded.data.max_hp - 1, wounded.data.max_hp), wounded.data.max_hp)
	var dead := _mech("comet", false)
	assert_false(EDICT_BONUS.repairs(dead))
	var enemy := MechState.from_data(load("res://data/mechs/enemy/scout.tres") as MechData, Vector2i.ZERO)
	assert_false(EDICT_BONUS.repairs(enemy))


func test_primed_adds_three_charge_that_fits() -> void:
	assert_eq(EDICT_BONUS.primed_gain(9, 12), 3)
	assert_eq(EDICT_BONUS.primed_gain(11, 12), 1)
	assert_eq(EDICT_BONUS.primed_gain(12, 12), 0)


func test_free_opener_waives_the_first_card() -> void:
	var action := CardData.new()
	action.cost_kind = "Action"
	assert_false(EDICT_BONUS.pays_action(action, true))
	assert_true(EDICT_BONUS.pays_action(action, false))
	var charge := CardData.new()
	charge.cost_kind = "Charge"
	charge.charge_cost = 2
	assert_eq(EDICT_BONUS.charge_due(charge, false, true), 0)
	assert_eq(EDICT_BONUS.charge_due(charge, false, false), 2)


func test_the_edict_catalog_drops_heavy_odds() -> void:
	var catalog := ResourceLoader.load("res://data/upgrades/edicts.tres", "", ResourceLoader.CACHE_MODE_REPLACE) as UpgradeCatalog
	assert_true(catalog != null)
	assert_eq(catalog.offers.size(), 6)
	var names: Array[String] = []
	for offer in catalog.offers:
		names.append(offer.display_name)
		assert_true(offer.rarity >= 2, offer.display_name)
		assert_ne(offer.id, "edict_heavy_odds")
		if offer.id == "edict_plus_two":
			assert_eq(offer.display_name, "Plus Two")
			assert_true(offer.blurb.contains("+2"))
		if offer.id == "edict_primed":
			assert_true(offer.blurb.contains("3"))
		if offer.id == "edict_field_repair":
			assert_true(offer.blurb.contains("fought"))
	assert_false(names.has("Heavy Odds"))
	assert_true(names.has("Plus Two"))
	var banner := _reload_scene("res://scenes/ui/mode_banner.tscn")
	var view := banner.instantiate()
	assert_true(view.get_node_or_null("Stripe/Row/Title") != null, "banner title")
	assert_true(view.get_node_or_null("Stripe/Row/ChargeMark") != null, "primed lightning")
	view.free()


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


func test_listing_tags_split_standard_upgrades_and_new_cards() -> void:
	var mech := _data("bastion")
	var memory := MissionUpgrades.new()
	var plain := UpgradeDeck.runtime_cards(mech, memory)
	assert_eq(UpgradeDeck.listing_tag(plain[0], mech), "Standard")
	assert_true(memory.apply_modify("bastion", "bastion_piledriver", _damage_offer()))
	var boosted := UpgradeDeck.runtime_cards(mech, memory)
	assert_eq(UpgradeDeck.listing_tag(boosted[0], mech), "Upgrade")
	assert_eq(boosted[1].id, "bastion_piledriver_2")
	assert_eq(UpgradeDeck.listing_tag(boosted[1], mech), "Standard")
	var granted := CardData.new()
	granted.id = "bastion_ram"
	memory.add_grant("bastion", granted)
	var with_grant := UpgradeDeck.runtime_cards(mech, memory)
	assert_eq(UpgradeDeck.listing_tag(with_grant[with_grant.size() - 1], mech), "New Card")
	var special: CardData
	for card in plain:
		if card.is_special:
			special = card
			break
	assert_eq(UpgradeDeck.listing_tag(special, mech), "Overdrive")


func _attack_card(damage: int) -> CardData:
	var card := CardData.new()
	card.card_type = "Attack"
	card.damage = damage
	card.display_name = "Strike"
	return card


func _guard_card(block: int) -> CardData:
	var card := CardData.new()
	card.card_type = "Defense"
	card.defense_kind = "Guard"
	card.block = block
	card.display_name = "Guard"
	return card


func _reload_scene(path: String) -> PackedScene:
	return ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene


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
