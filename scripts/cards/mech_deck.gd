@tool
class_name MechDeck
extends Resource

@export var mech_id: String = ""
## Defense slots are filled from Guard cards, Dodge cards, or one of each.
@export var cards: Array[CardData] = []


## Cards held out of the draw until Overdrive.
func special_cards() -> Array[CardData]:
	var found: Array[CardData] = []
	for card in cards:
		if card != null and card.is_special:
			found.append(card)
	return found
