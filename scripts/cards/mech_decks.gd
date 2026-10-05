class_name MechDecks
extends RefCounted

const DECK_PATH := "res://data/decks/%s/%s.tres"


static func for_mech(mech: MechData) -> MechDeck:
	if mech == null or mech.id == "" or mech.team == "":
		return null
	var path := DECK_PATH % [mech.team, mech.id]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as MechDeck


## The strike an enemy uses when its turn comes up. Player hands are dealt separately.
static func strike_card(mech: MechData) -> CardData:
	var deck := for_mech(mech)
	if deck == null:
		return null
	for card in deck.cards:
		if card != null and card.card_type == "Attack":
			return card
	return null
