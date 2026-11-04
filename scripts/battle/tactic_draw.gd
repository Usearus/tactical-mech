class_name TacticDraw
extends RefCounted

## A favored card is 30% more likely to be drawn ahead of any one other card.
const FAVORED_WEIGHT := 1.3


## Removes one card from the pile. An empty favored type takes the back, same as a fair shuffle.
static func take(pile: Array[CardData], favored: String, rng: RandomNumberGenerator = null) -> CardData:
	if pile.is_empty():
		return null
	if favored == "":
		return pile.pop_back()
	var total := 0.0
	var weights: Array[float] = []
	for card in pile:
		var weight := FAVORED_WEIGHT if card != null and card.card_type == favored else 1.0
		weights.append(weight)
		total += weight
	var roll := _unit(rng) * total
	var cursor := 0.0
	for index in pile.size():
		cursor += weights[index]
		if roll < cursor or index == pile.size() - 1:
			var card := pile[index]
			pile.remove_at(index)
			return card
	return null


static func _unit(rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf()
	return randf()
