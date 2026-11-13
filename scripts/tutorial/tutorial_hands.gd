class_name TutorialHands
extends RefCounted

## Lesson cards for this round go at the front of the hand.
## The second Burst Fire stays at the back of the deck until round 2.


static func wanted(phase: String, round: int = 1) -> PackedStringArray:
	match phase:
		"b1":
			if round <= 1:
				return PackedStringArray(["raven_burst_fire"])
			return PackedStringArray(["raven_burst_fire_2"])
		"b2":
			if round <= 1:
				return PackedStringArray([
					"comet_dart",
					"raven_snap_shot",
					"raven_burst_fire",
					"comet_dart_2",
				])
			return PackedStringArray(["raven_burst_fire_2"])
		_:
			return PackedStringArray()


## Cards the opening hand must not spend as fillers. They stay at the back of the deck.
static func held_back(phase: String, round: int = 1) -> PackedStringArray:
	if round <= 1 and (phase == "b1" or phase == "b2"):
		return PackedStringArray(["raven_burst_fire_2"])
	return PackedStringArray()


static func arrange(
	deck: Array[CardData],
	hand: Array[CardData],
	phase: String,
	limit: int,
	round: int = 1
) -> void:
	var order := wanted(phase, round)
	if order.is_empty() or limit <= 0:
		return
	var pool: Array[CardData] = []
	pool.append_array(hand)
	pool.append_array(deck)
	var next: Array[CardData] = []
	for card_id in order:
		if next.size() >= limit:
			break
		var index := _find(pool, card_id)
		if index < 0:
			continue
		next.append(pool[index])
		pool.remove_at(index)
	var reserved: Array[CardData] = []
	for card_id in held_back(phase, round):
		var held := _find(pool, card_id)
		if held < 0:
			continue
		reserved.append(pool[held])
		pool.remove_at(held)
	while next.size() < limit and not pool.is_empty():
		next.append(pool.pop_front())
	hand.clear()
	deck.clear()
	hand.append_array(next)
	deck.append_array(pool)
	deck.append_array(reserved)


static func _find(pool: Array[CardData], card_id: String) -> int:
	for index in pool.size():
		var card := pool[index]
		if card != null and card.id == card_id:
			return index
	return -1
