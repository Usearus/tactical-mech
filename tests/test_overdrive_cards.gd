@tool
extends McpTestSuite


func suite_name() -> String:
	return "overdrive_cards"


func test_last_card_is_held_for_overdrive() -> void:
	var expected := {
		"raven": "raven_break",
		"comet": "comet_spark",
		"bulldog": "bulldog_screen",
		"bastion": "bastion_anchor",
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


func test_raven_fights_from_two_or_three() -> void:
	var deck := load("res://data/decks/player/raven.tres") as MechDeck
	var bursts := 0
	for card in deck.cards:
		if card == null or card.card_type != "Attack":
			continue
		assert_true(card.reach == 2 or card.reach == 3, card.display_name)
		if card.display_name == "Burst Fire":
			bursts += 1
			assert_eq(card.damage, 4, "burst fire damage")
	assert_eq(bursts, 2, "needle was replaced with a second burst fire")
	var dive := deck.special_cards()[0]
	assert_eq(dive.display_name, "Break", "break is the overdrive card")
	assert_eq(dive.damage, 6, "break hits for 6")
	assert_eq(dive.reach, 2, "break reaches 2")
	assert_false(dive.exact_range, "break hits anyone inside that reach")
	assert_eq(dive.movement, 3, "break steps 3")
	assert_eq(dive.move_timing, "Before", "break steps first")
	assert_eq(dive.target_type, "enemies", "break hits every enemy in reach")


func test_shepherd_plates_from_range() -> void:
	var mech := load("res://data/mechs/player/bulldog.tres") as MechData
	assert_eq(mech.display_name, "Shepherd", "name")
	assert_eq(mech.attack_range, 2, "opens fights from 2 cells")
	var deck := load("res://data/decks/player/bulldog.tres") as MechDeck
	var wards := 0
	var darts := 0
	for card in deck.cards:
		if card == null:
			continue
		if card.card_type == "Attack":
			assert_true(card.reach == 2 or card.reach == 3, card.display_name)
			assert_true(card.damage <= 4, card.display_name)
		if card.display_name == "Ward":
			wards += 1
			assert_eq(card.movement, 1, "ward steps 1")
			assert_eq(card.move_timing, "Before", "ward steps first")
			assert_eq(card.barrier, 3, "ward gives 3 barrier")
			assert_eq(card.target_type, "ally", "ward plates an ally")
			assert_false(card.is_special, "ward is a normal card")
		if card.display_name == "Dart":
			darts += 1
	assert_eq(wards, 2, "two wards, no reposition")
	assert_eq(darts, 2, "two darts")
	var screen := deck.special_cards()[0]
	assert_eq(screen.display_name, "Screen", "screen is the overdrive card")
	assert_eq(screen.barrier, 4, "screen adds 4 barrier")
	assert_eq(screen.target_type, "team", "screen covers the squad")


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


func test_pitch_fills_one_and_stops_when_full() -> void:
	var saved_gauge := GameManager.player_attack_gauge
	var saved_max := GameManager.player_attack_max
	GameManager.player_attack_max = GameManager.SQUAD_ATTACK_MAX
	GameManager.player_attack_gauge = GameManager.SQUAD_ATTACK_MAX - 1
	assert_eq(GameManager.SQUAD_ATTACK_MAX, 12, "the squad gauge is 12 long")
	assert_true(GameManager.charge_from_pitch(), "one discard fills a point")
	assert_eq(GameManager.player_attack_gauge, 12, "the gauge holds that point")
	assert_false(GameManager.charge_from_pitch(), "a full gauge takes no more")
	GameManager.player_attack_gauge = saved_gauge
	GameManager.player_attack_max = saved_max


func test_bastion_holds_the_line() -> void:
	var bastion := load("res://data/mechs/player/bastion.tres") as MechData
	assert_eq(bastion.display_name, "Bastion", "name")
	assert_eq(bastion.art_id, "blue", "art")
	assert_eq(bastion.max_hp, 22, "hp")
	assert_eq(bastion.move_range, 2, "move")
	assert_eq(bastion.speed, 4, "speed")
	var listed := false
	for mech in StartingRoster.player_roster():
		if mech != null and mech.id == "bastion":
			listed = true
	assert_true(listed, "bastion is on the mech list")
	var copy := load("res://data/decks/player/bastion.tres") as MechDeck
	var names := ["Piledriver", "Piledriver", "Spike", "Spike", "Close In", "Brace"]
	for index in names.size():
		var card: CardData = copy.cards[index]
		assert_eq(card.display_name, names[index], card.id)
		assert_false(card.is_special, card.id)
	var anchor := copy.special_cards()[0]
	assert_eq(anchor.display_name, "Anchor", "bastion keeps anchor")
	assert_eq(anchor.barrier, 6, "anchor adds 6 barrier")
	assert_true(anchor.intercept, "anchor catches the next hit")
	var frames := MechSprites.frames_for("blue")
	assert_true(frames != null, "blue mech art")
	if frames == null:
		return
	assert_eq(frames.get_frame_count("idle"), 8, "idle frames")
	assert_true(frames.has_animation("attack"), "attack strip")
	assert_eq(frames.get_frame_count("attack"), 10, "attack frames")
	var idle := frames.get_frame_texture("idle", 0)
	var strike := frames.get_frame_texture("attack", 0)
	assert_eq(int(idle.get_height()), 64, "idle matches attack pixel size")
	assert_eq(int(strike.get_width()), 88, "attack cell width")
	assert_eq(int(strike.get_height()), 64, "attack cell height")
	var posed := AnimatedSprite2D.new()
	posed.sprite_frames = frames
	posed.animation = "idle"
	assert_eq(MechSprites.reach_offset(posed), Vector2.ZERO, "idle stays on its cell")
	posed.animation = "attack"
	assert_eq(MechSprites.reach_offset(posed), Vector2(12, 0), "spike grows past the idle's right edge")
	posed.flip_h = true
	assert_eq(MechSprites.reach_offset(posed), Vector2(-12, 0), "spike grows past the idle's left edge when facing left")
	posed.free()
	var unit := MechState.new()
	unit.data = bastion
	assert_true(FinisherBanner.uses_attack_strip(unit), "bastion finisher plays the attack")
	var raven_unit := MechState.new()
	raven_unit.data = load("res://data/mechs/player/raven.tres") as MechData
	assert_true(FinisherBanner.uses_attack_strip(raven_unit), "raven finisher plays the attack")
	var barrage_unit := MechState.new()
	barrage_unit.data = load("res://data/mechs/player/barrage.tres") as MechData
	assert_true(FinisherBanner.uses_attack_strip(barrage_unit), "barrage finisher plays the attack")
	var comet_unit := MechState.new()
	comet_unit.data = load("res://data/mechs/player/comet.tres") as MechData
	assert_false(FinisherBanner.uses_attack_strip(comet_unit), "comet keeps the still pose")
	var pilot := MechSprites.pilot_frames("blue")
	assert_true(pilot != null and pilot.get_frame_count("idle") >= 1, "blue pilot")


func test_a_card_pays_one_cost() -> void:
	var bulldog := load("res://data/decks/player/bulldog.tres") as MechDeck
	var wards := 0
	for card in bulldog.cards:
		if card.display_name == "Ward":
			wards += 1
			_assert_charge(card, "ward")
		elif card.display_name == "Screen":
			_assert_action(card, "screen")
	assert_eq(wards, 2, "bulldog has two wards")
	var anchor := (load("res://data/decks/player/bastion.tres") as MechDeck).special_cards()[0]
	_assert_action(anchor, "anchor")
	var comet := load("res://data/decks/player/comet.tres") as MechDeck
	for card in comet.cards:
		if card.display_name == "Sting" or card.display_name == "Dart":
			_assert_free(card, card.display_name)
		elif card.display_name == "Skim" or card.display_name == "Spark":
			_assert_action(card, card.display_name)
	var graze := _card_named(load("res://data/decks/player/lancer.tres"), "Graze")
	_assert_free(graze, "graze")
	var raven := load("res://data/decks/player/raven.tres") as MechDeck
	var evade := _card_named(raven, "Evade")
	_assert_free(evade, "evade")
	var blink := _card_named(raven, "Blink")
	_assert_free(blink, "blink")
	assert_eq(blink.movement, 1, "blink steps 1")
	assert_true(blink.moves_only(), "blink only moves")
	var bolt := CardData.new()
	bolt.card_type = "Attack"
	bolt.cost_kind = "Charge"
	_assert_charge(bolt, "charge card")
	var plated := CardData.new()
	plated.barrier = 2
	plated.cost_kind = "Free"
	_assert_charge(plated, "barrier stays a charge even when marked free")
	var special := CardData.new()
	special.is_special = true
	special.cost_kind = "Charge"
	special.barrier = 4
	_assert_action(special, "a special marked charge")
	if GameManager.get("player_attack_gauge") == null:
		return
	var saved_offense := GameManager.battle_offense
	var saved_gauge := GameManager.player_attack_gauge
	var saved_bank := GameManager.player_banked_gauge
	GameManager.battle_offense = false
	GameManager.player_attack_gauge = 0
	GameManager.player_banked_gauge = 4
	assert_false(GameManager.spend_charge(), "a short gauge refuses")
	assert_eq(GameManager.player_attack_gauge, 0, "the gauge stays empty")
	assert_eq(GameManager.player_banked_gauge, 4, "banked spark stays put")
	assert_eq(bolt.charge_due(true), 0, "overdrive waives the charge")
	GameManager.battle_offense = true
	assert_eq(GameManager.player_attack_gauge, 0, "a waived charge does not touch the gauge")
	assert_eq(GameManager.player_banked_gauge, 4, "a waived charge does not touch the bank")
	GameManager.battle_offense = false
	GameManager.player_attack_gauge = 2
	assert_true(GameManager.spend_charge(), "one charge is enough")
	assert_eq(GameManager.player_attack_gauge, 1, "the gauge drops by one")
	assert_eq(GameManager.player_banked_gauge, 4, "spending live charge leaves the bank")
	GameManager.battle_offense = saved_offense
	GameManager.player_attack_gauge = saved_gauge
	GameManager.player_banked_gauge = saved_bank


func _card_named(deck: MechDeck, card_name: String) -> CardData:
	for card in deck.cards:
		if card != null and card.display_name == card_name:
			return card
	return null


func _assert_charge(card: CardData, label: String) -> void:
	assert_true(card.pays_charge(), label)
	assert_false(card.pays_action(), label)
	assert_eq(card.charge_due(false), 1, label)
	assert_eq(card.charge_due(true), 0, label)


func _assert_action(card: CardData, label: String) -> void:
	assert_true(card.pays_action(), label)
	assert_false(card.pays_charge(), label)
	assert_eq(card.charge_due(false), 0, label)


func _assert_free(card: CardData, label: String) -> void:
	assert_false(card.pays_action(), label)
	assert_false(card.pays_charge(), label)
	assert_eq(card.charge_due(false), 0, label)
