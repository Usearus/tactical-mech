extends RefCounted

## Damage, block, cost, heal, and starting charge from the battle edicts.
## Opening Strike, Opening Guard, and Free Opener are passed in only while that first card is still waiting.

const OPENING := 3
const PLUS_TWO := 2
const FIELD_REPAIR := 2
const PRIMED_CHARGE := 3


## Stepped quarter-step. 1–4 gains 1, 5–10 gains 2, 11–15 gains 3.
static func tactic_bonus(amount: int) -> int:
	if amount <= 4:
		return 1 if amount > 0 else 0
	if amount <= 10:
		return 2
	if amount <= 15:
		return 3
	return 4


## Printed damage, then Overdrive, Plus Two, and Opening Strike.
static func attack_amount(card: CardData, overdrive: bool, opening_strike: bool, plus_two: bool) -> int:
	var amount := 0 if card == null else maxi(card.damage, 0)
	if card == null or card.card_type != "Attack":
		return amount
	if overdrive:
		amount += tactic_bonus(maxi(card.damage, 0))
	if plus_two:
		amount += PLUS_TWO
	if opening_strike:
		amount += OPENING
	return amount


## Printed block, then Overdrive, Plus Two, and Opening Guard. Dodges stay printed.
static func guard_amount(card: CardData, overdrive: bool, opening_guard: bool, plus_two: bool) -> int:
	var amount := 0 if card == null else maxi(card.block, 0)
	if card == null or not card.is_guard():
		return amount
	if overdrive:
		amount += tactic_bonus(maxi(card.block, 0))
	if plus_two:
		amount += PLUS_TWO
	if opening_guard:
		amount += OPENING
	return amount


## Living player mechs who were in the fight. A downed mech and the enemy stay as they are.
static func repairs(unit: MechState) -> bool:
	return unit != null and unit.alive and unit.team == "player"


## Health after Field Repair. The result never passes the mech's maximum, and never drops.
static func healed_hp(current: int, max_hp: int) -> int:
	var held := maxi(current, 0)
	var cap := maxi(max_hp, held)
	return mini(held + FIELD_REPAIR, cap)


## Charge that fits on the squad gauge when a battle opens.
static func primed_gain(current: int, max_charge: int) -> int:
	return mini(PRIMED_CHARGE, maxi(max_charge - maxi(current, 0), 0))


## Free Opener waives the first card's charge. Later cards use the printed cost.
static func charge_due(card: CardData, overdrive: bool, free_opener: bool) -> int:
	if card == null or free_opener:
		return 0
	return card.charge_due(overdrive)


## Free Opener waives the first card's action. A card that was already free stays free.
static func pays_action(card: CardData, free_opener: bool) -> bool:
	if card == null or free_opener:
		return false
	return card.pays_action()
