class_name UpgradeDeck
extends RefCounted


## bastion_piledriver_2 and bastion_piledriver are one family. The first copy takes every boost.
static func family_of(card_id: String) -> String:
	var split := card_id.rfind("_")
	if split <= 0:
		return card_id
	var tail := card_id.substr(split + 1)
	if tail.is_valid_int():
		return card_id.substr(0, split)
	return card_id


static func first_of_family(mech: MechData, family: String) -> CardData:
	var deck := MechDecks.for_mech(mech)
	if deck == null:
		return null
	for card in deck.cards:
		if card != null and family_of(card.id) == family:
			return card
	return null


static func families_in(mech: MechData) -> Dictionary:
	var have := {}
	var deck := MechDecks.for_mech(mech)
	if deck == null:
		return have
	for card in deck.cards:
		if card != null:
			have[family_of(card.id)] = true
	return have


## The next boost stacked on top of what this family already has.
static func stacked_mod(base: Dictionary, offer: UpgradeOffer) -> Dictionary:
	var blurbs: Array = []
	var existing: Variant = base.get("blurbs", [])
	if existing is Array:
		blurbs = (existing as Array).duplicate()
	var timing := str(base.get("movement_timing", ""))
	if offer != null and offer.movement_add > 0 and timing == "":
		timing = offer.movement_timing
	if offer != null and offer.blurb != "" and not blurbs.has(offer.blurb):
		blurbs.append(offer.blurb)
	var damage := int(base.get("damage_add", 0))
	var movement := int(base.get("movement_add", 0))
	var free := bool(base.get("make_free", false))
	var count := int(base.get("upgrade_count", 0))
	if offer != null:
		damage += offer.damage_add
		movement += offer.movement_add
		free = free or offer.make_free
		count += 1
	return {
		"damage_add": damage,
		"movement_add": movement,
		"make_free": free,
		"movement_timing": timing,
		"upgrade_count": count,
		"blurbs": blurbs,
	}


## Copies the deck, paints the first card of each upgraded family, then appends grants.
static func runtime_cards(mech: MechData, memory: MissionUpgrades) -> Array[CardData]:
	var built: Array[CardData] = []
	var deck := MechDecks.for_mech(mech)
	if deck == null or mech == null:
		return built
	if memory == null:
		memory = MissionUpgrades.new()
	var painted := {}
	for card in deck.cards:
		if card == null:
			continue
		var copy := card.duplicate() as CardData
		var family := family_of(card.id)
		if not painted.has(family):
			painted[family] = true
			paint(copy, memory.mod_for(mech.id, family))
		built.append(copy)
	for granted in memory.grants_for(mech.id):
		built.append(granted.duplicate() as CardData)
	return built


static func paint(card: CardData, mod: Dictionary) -> void:
	if card == null or int(mod.get("upgrade_count", 0)) <= 0:
		return
	var damage_add := int(mod.get("damage_add", 0))
	var movement_add := int(mod.get("movement_add", 0))
	if damage_add != 0:
		card.damage += damage_add
		card.mark_upgrade("damage")
	if movement_add != 0:
		card.movement += movement_add
		card.mark_upgrade("movement")
		if card.card_type == "Attack" and card.move_timing == "None":
			var timing := str(mod.get("movement_timing", "Before"))
			card.move_timing = "After" if timing == "After" else "Before"
	if bool(mod.get("make_free", false)):
		card.cost_kind = "Free"
		card.mark_upgrade("cost")
	card.display_name = upgraded_name(card.display_name, int(mod.get("upgrade_count", 0)))
	var blurbs: Variant = mod.get("blurbs", [])
	if blurbs is Array:
		for blurb in blurbs:
			_append_blurb(card, str(blurb))


static func upgraded_name(base: String, count: int) -> String:
	var stem := base
	while stem.ends_with("+"):
		stem = stem.substr(0, stem.length() - 1)
	var plus := ""
	for _step in maxi(count, 0):
		plus += "+"
	return stem + plus


static func apply(choice: UpgradeChoice, memory: MissionUpgrades) -> void:
	if choice == null or memory == null:
		return
	match choice.kind:
		"Grant":
			if choice.bound_mech != null and choice.bound_mech.data != null and choice.offer != null:
				memory.add_grant(choice.bound_mech.data.id, choice.offer.card)
		"Modify":
			if choice.bound_mech != null and choice.bound_mech.data != null and choice.offer != null:
				memory.apply_modify(choice.bound_mech.data.id, choice.family, choice.offer)
		"Immediate":
			var amount := 0 if choice.offer == null else choice.offer.barrier
			for unit in choice.mechs:
				if unit != null and unit.alive:
					unit.add_barrier(amount)
		"Revive":
			var unit := choice.bound_mech
			if unit == null or unit.data == null:
				return
			unit.alive = true
			unit.hp = maxi(1, int(unit.data.max_hp / 2.0))
			unit.guard = 0


static func _append_blurb(card: CardData, blurb: String) -> void:
	if blurb == "" or card.description.contains(blurb):
		return
	if card.description == "":
		card.description = blurb
	else:
		card.description = "%s %s" % [card.description, blurb]
