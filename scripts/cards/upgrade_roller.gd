class_name UpgradeRoller
extends RefCounted

const PLAYER_PATH := "res://data/upgrades/player/%s.tres"
const TEAM_PATH := "res://data/upgrades/team.tres"
const REVIVE_PATH := "res://data/upgrades/revive.tres"
## Group effects are offered, just less often than a new card or an upgrade.
const KIND_WEIGHT := {
	"Grant": 4,
	"Modify": 4,
	"Revive": 4,
	"Immediate": 2,
}


static func refreshes_per_mission() -> int:
	return maxi(DraftOdds.load_saved().refreshes_per_mission, 0)


static func roll(units: Array, memory: MissionUpgrades, odds: DraftOdds = null, rng: RandomNumberGenerator = null) -> Array:
	if odds == null:
		odds = DraftOdds.load_saved()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	odds = odds.for_fight(_count_team(units, "player"), _count_team(units, "enemy"))
	return pick(legal_choices(units, memory), odds, rng)


static func any_alive(units: Array) -> bool:
	for unit in units:
		if unit is MechState and (unit as MechState).alive:
			return true
	return false


## Every offer this fight is allowed to show, before the row is dealt.
static func legal_choices(units: Array, memory: MissionUpgrades) -> Array[UpgradeChoice]:
	var found: Array[UpgradeChoice] = []
	if memory == null:
		memory = MissionUpgrades.new()
	var living: Array[MechState] = []
	var dead: Array[MechState] = []
	for unit in units:
		if not unit is MechState:
			continue
		var mech := unit as MechState
		if mech.data == null or mech.team != "player":
			continue
		if mech.alive:
			living.append(mech)
		else:
			dead.append(mech)
	for unit in living:
		var catalog := _catalog(PLAYER_PATH % unit.data.id)
		if catalog == null:
			continue
		var families := UpgradeDeck.families_in(unit.data)
		for offer in catalog.offers:
			if offer == null:
				continue
			if offer.mech_id != "" and offer.mech_id != unit.data.id:
				continue
			if offer.kind == "Grant":
				_add_grant(found, offer, unit, memory)
			elif offer.kind == "Modify":
				_add_modify(found, offer, unit, memory, families)
	if living.size() >= 2:
		var team := _catalog(TEAM_PATH)
		if team != null:
			for offer in team.offers:
				if offer != null and offer.kind == "Immediate":
					_add_immediate(found, offer, living)
	var revive := _revive_template()
	if revive != null:
		for unit in dead:
			_add_revive(found, revive, unit)
	return found


## Three cards when two or more kinds are legal. One kind stops at two, so a row is never three of a kind.
static func pick(legal: Array, odds: DraftOdds, rng: RandomNumberGenerator) -> Array:
	var by_kind := {}
	for choice in legal:
		var item := choice as UpgradeChoice
		if item == null or item.kind == "":
			continue
		if not by_kind.has(item.kind):
			by_kind[item.kind] = []
		var bucket: Array = by_kind[item.kind]
		bucket.append(item)
		by_kind[item.kind] = bucket
	var kinds: Array[String] = []
	for kind in by_kind.keys():
		kinds.append(str(kind))
	if kinds.is_empty():
		return []
	if odds == null:
		odds = DraftOdds.new()
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	if kinds.size() == 1:
		return _fill_kind(by_kind[kinds[0]], 2, odds, rng, {})
	var used := {}
	var counts := {}
	var row: Array = []
	for slot in 3:
		var avoid := ""
		if slot == 1 and not row.is_empty():
			avoid = (row[0] as UpgradeChoice).kind
		var taken := _take_slot(by_kind, odds, rng, used, counts, avoid)
		if taken == null:
			break
		row.append(taken)
		_mark_used(used, taken)
		counts[taken.kind] = int(counts.get(taken.kind, 0)) + 1
	_shuffle(row, rng)
	return row


static func _add_grant(found: Array[UpgradeChoice], offer: UpgradeOffer, unit: MechState, memory: MissionUpgrades) -> void:
	if offer.card == null or offer.card.id == "":
		return
	if memory.has_grant(unit.data.id, offer.card.id):
		return
	var choice := UpgradeChoice.new()
	choice.offer = offer
	choice.kind = "Grant"
	choice.rarity = clampi(offer.rarity, 1, 3)
	choice.bound_mech = unit
	choice.mechs = _one(unit)
	choice.preview = offer.card.duplicate() as CardData
	choice.slot_key = "grant:%s:%s" % [unit.data.id, offer.card.id]
	found.append(choice)


static func _add_modify(found: Array[UpgradeChoice], offer: UpgradeOffer, unit: MechState, memory: MissionUpgrades, families: Dictionary) -> void:
	if offer.card_family == "" or not families.has(offer.card_family):
		return
	if memory.upgrade_count(unit.data.id, offer.card_family) >= 2:
		return
	var source := UpgradeDeck.first_of_family(unit.data, offer.card_family)
	if source == null:
		return
	var preview := source.duplicate() as CardData
	UpgradeDeck.paint(preview, UpgradeDeck.stacked_mod(memory.mod_for(unit.data.id, offer.card_family), offer))
	var choice := UpgradeChoice.new()
	choice.offer = offer
	choice.kind = "Modify"
	choice.rarity = clampi(offer.rarity, 1, 3)
	choice.bound_mech = unit
	choice.mechs = _one(unit)
	choice.preview = preview
	choice.family = offer.card_family
	choice.slot_key = "modify:%s:%s" % [unit.data.id, offer.card_family]
	choice.buff_keys = _buff_keys(offer)
	found.append(choice)


static func _add_immediate(found: Array[UpgradeChoice], offer: UpgradeOffer, living: Array[MechState]) -> void:
	var preview := CardData.new()
	preview.id = offer.id
	preview.display_name = offer.display_name if offer.display_name != "" else "Squad Barrier"
	preview.description = offer.blurb
	preview.card_type = "Defense"
	preview.defense_kind = "Guard"
	preview.barrier = offer.barrier
	preview.reach = 0
	preview.target_type = "team"
	preview.hide_cost = true
	var choice := UpgradeChoice.new()
	choice.offer = offer
	choice.kind = "Immediate"
	choice.rarity = clampi(offer.rarity, 1, 3)
	var owners: Array[MechState] = []
	owners.append_array(living)
	choice.mechs = owners
	choice.preview = preview
	choice.slot_key = "immediate:%s" % offer.id
	choice.buff_keys = _buff_keys(offer)
	found.append(choice)


static func _add_revive(found: Array[UpgradeChoice], offer: UpgradeOffer, unit: MechState) -> void:
	var preview := CardData.new()
	preview.display_name = "Revive %s" % unit.display_name
	preview.description = offer.blurb if offer.blurb != "" else "Returns with half health."
	preview.card_type = "Defense"
	preview.reach = 0
	preview.hide_cost = true
	var choice := UpgradeChoice.new()
	choice.offer = offer
	choice.kind = "Revive"
	choice.rarity = clampi(offer.rarity, 1, 3)
	choice.bound_mech = unit
	choice.mechs = _one(unit)
	choice.preview = preview
	choice.slot_key = "revive:%s" % unit.instance_id
	found.append(choice)


static func _one(unit: MechState) -> Array[MechState]:
	var owners: Array[MechState] = []
	owners.append(unit)
	return owners


static func _catalog(path: String) -> UpgradeCatalog:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as UpgradeCatalog


static func _revive_template() -> UpgradeOffer:
	if not ResourceLoader.exists(REVIVE_PATH):
		return null
	return load(REVIVE_PATH) as UpgradeOffer


static func _fill_kind(pool: Array, limit: int, odds: DraftOdds, rng: RandomNumberGenerator, used: Dictionary) -> Array:
	var row: Array = []
	while row.size() < limit:
		var choice := _take_kind(pool, odds, rng, used)
		if choice == null:
			break
		row.append(choice)
		_mark_used(used, choice)
	return row


## The star roll is kept. A kind with no card of that star loses the slot to a kind that has one, instead of being promoted to a higher star.
static func _take_slot(
	by_kind: Dictionary,
	odds: DraftOdds,
	rng: RandomNumberGenerator,
	used: Dictionary,
	counts: Dictionary,
	avoid: String
) -> UpgradeChoice:
	var order := _rarity_order(odds.roll_rarity(rng))
	for band in order:
		var open := _kinds_at(by_kind, band, used, counts, avoid)
		if open.is_empty() and avoid != "":
			open = _kinds_at(by_kind, band, used, counts, "")
		if open.is_empty():
			continue
		return _take_exact(by_kind[_roll_kind(open, rng)], band, rng, used)
	return null


static func _kinds_at(
	by_kind: Dictionary,
	band: int,
	used: Dictionary,
	counts: Dictionary,
	avoid: String
) -> Array[String]:
	var open: Array[String] = []
	for kind in by_kind.keys():
		var name := str(kind)
		if name == avoid or int(counts.get(name, 0)) >= 2:
			continue
		if not _band_hits(by_kind[kind], band, used).is_empty():
			open.append(name)
	return open


static func _band_hits(pool: Array, band: int, used: Dictionary) -> Array[UpgradeChoice]:
	var hits: Array[UpgradeChoice] = []
	for choice in pool:
		var item := choice as UpgradeChoice
		if item == null or item.rarity != band or _is_used(used, item):
			continue
		hits.append(item)
	return hits


static func _take_exact(pool: Array, band: int, rng: RandomNumberGenerator, used: Dictionary) -> UpgradeChoice:
	var hits := _band_hits(pool, band, used)
	if hits.is_empty():
		return null
	return hits[rng.randi_range(0, hits.size() - 1)]


static func _take_kind(pool: Array, odds: DraftOdds, rng: RandomNumberGenerator, used: Dictionary) -> UpgradeChoice:
	if pool.is_empty():
		return null
	for band in _rarity_order(odds.roll_rarity(rng)):
		var hits: Array[UpgradeChoice] = []
		for choice in pool:
			var item := choice as UpgradeChoice
			if item == null or _is_used(used, item):
				continue
			if item.rarity == band:
				hits.append(item)
		if not hits.is_empty():
			return hits[rng.randi_range(0, hits.size() - 1)]
	return null


static func _buff_keys(offer: UpgradeOffer) -> PackedStringArray:
	var keys: PackedStringArray = []
	if offer.damage_add != 0:
		keys.append("buff:damage")
	if offer.movement_add != 0:
		keys.append("buff:movement")
	if offer.make_free:
		keys.append("buff:free")
	if offer.barrier != 0:
		keys.append("buff:barrier")
	return keys


static func _is_used(used: Dictionary, choice: UpgradeChoice) -> bool:
	if choice.slot_key != "" and used.has(choice.slot_key):
		return true
	for key in choice.buff_keys:
		if used.has(key):
			return true
	return false


static func _mark_used(used: Dictionary, choice: UpgradeChoice) -> void:
	if choice.slot_key != "":
		used[choice.slot_key] = true
	for key in choice.buff_keys:
		used[key] = true


static func _roll_kind(kinds: Array[String], rng: RandomNumberGenerator) -> String:
	var total := 0
	for kind in kinds:
		total += int(KIND_WEIGHT.get(kind, 4))
	if total <= 0:
		return kinds[0]
	var roll := rng.randi_range(1, total)
	var cursor := 0
	for kind in kinds:
		cursor += int(KIND_WEIGHT.get(kind, 4))
		if roll <= cursor:
			return kind
	return kinds[kinds.size() - 1]


static func _count_team(units: Array, team: String) -> int:
	var count := 0
	for unit in units:
		if unit is MechState and (unit as MechState).team == team:
			count += 1
	return count


static func _rarity_order(rarity: int) -> Array[int]:
	if rarity <= 1:
		return [1, 2, 3]
	if rarity >= 3:
		return [3, 2, 1]
	return [2, 1, 3]


static func _shuffle(row: Array, rng: RandomNumberGenerator) -> void:
	for index in range(row.size() - 1, 0, -1):
		var swap := rng.randi_range(0, index)
		var held = row[index]
		row[index] = row[swap]
		row[swap] = held
