class_name MissionUpgrades
extends RefCounted

## mech id -> Array of granted CardData.
var _grants: Dictionary = {}
## mech id -> family -> summed boost.
var _mods: Dictionary = {}
## Edict ids picked this mission. A second copy is not offered.
var _edicts: Array[String] = []
## Rerolls left for every upgrade offer in this mission.
var refreshes_left := UpgradeRoller.refreshes_per_mission()


func clear() -> void:
	_grants.clear()
	_mods.clear()
	_edicts.clear()
	refreshes_left = UpgradeRoller.refreshes_per_mission()


func spend_refresh() -> bool:
	if refreshes_left <= 0:
		return false
	refreshes_left -= 1
	return true


func upgrade_count(mech_id: String, family: String) -> int:
	return int(mod_for(mech_id, family).get("upgrade_count", 0))


func has_edict(edict_id: String) -> bool:
	return edict_id != "" and _edicts.has(edict_id)


func add_edict(edict_id: String) -> void:
	if edict_id == "" or has_edict(edict_id):
		return
	_edicts.append(edict_id)


## Picked edicts, in the order they were taken. Names and blurbs come from the catalog.
func active_edicts() -> Array[UpgradeOffer]:
	var found: Array[UpgradeOffer] = []
	if _edicts.is_empty():
		return found
	var catalog := load(UpgradeRoller.EDICT_PATH) as UpgradeCatalog
	if catalog == null:
		return found
	var by_id := {}
	for offer in catalog.offers:
		if offer != null and offer.id != "":
			by_id[offer.id] = offer
	for edict_id in _edicts:
		var offer: Variant = by_id.get(edict_id)
		if offer is UpgradeOffer:
			found.append(offer)
	return found


func has_grant(mech_id: String, card_id: String) -> bool:
	if card_id == "":
		return false
	for card in grants_for(mech_id):
		if card.id == card_id:
			return true
	return false


func grants_for(mech_id: String) -> Array[CardData]:
	var found: Array[CardData] = []
	for card in _grants.get(mech_id, []):
		if card is CardData:
			found.append(card)
	return found


func add_grant(mech_id: String, card: CardData) -> void:
	if mech_id == "" or card == null or card.id == "":
		return
	if has_grant(mech_id, card.id):
		return
	if not _grants.has(mech_id):
		_grants[mech_id] = []
	(_grants[mech_id] as Array).append(card)


## A copy of the summed boost. Empty when this family has not been upgraded.
func mod_for(mech_id: String, family: String) -> Dictionary:
	var table: Dictionary = _mods.get(mech_id, {})
	var row: Dictionary = table.get(family, {})
	return row.duplicate(true)


## False once this family already has two upgrades.
func apply_modify(mech_id: String, family: String, offer: UpgradeOffer) -> bool:
	if mech_id == "" or family == "" or offer == null:
		return false
	if upgrade_count(mech_id, family) >= 2:
		return false
	if not _mods.has(mech_id):
		_mods[mech_id] = {}
	var table: Dictionary = _mods[mech_id]
	var stacked := UpgradeDeck.stacked_mod(table.get(family, {}), offer)
	table[family] = stacked
	_mods[mech_id] = table
	return true
