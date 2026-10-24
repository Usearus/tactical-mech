class_name MissionUpgrades
extends RefCounted

## mech id -> Array of granted CardData.
var _grants: Dictionary = {}
## mech id -> family -> summed boost.
var _mods: Dictionary = {}
## Rerolls left for every upgrade offer in this mission.
var refreshes_left := UpgradeRoller.refreshes_per_mission()


func clear() -> void:
	_grants.clear()
	_mods.clear()
	refreshes_left = UpgradeRoller.refreshes_per_mission()


func spend_refresh() -> bool:
	if refreshes_left <= 0:
		return false
	refreshes_left -= 1
	return true


func upgrade_count(mech_id: String, family: String) -> int:
	return int(mod_for(mech_id, family).get("upgrade_count", 0))


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
