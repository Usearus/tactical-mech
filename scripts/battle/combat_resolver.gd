class_name CombatResolver
extends RefCounted


## Attack cards deal their own damage. A dodge in hand negates the hit.
## Otherwise guard is spent first, then barrier, and health takes the rest.
static func resolve_attack(attacker: MechState, defender: MechState, card: CardData, dodge: CardData = null) -> Dictionary:
	var amount := _attack_damage(attacker, card)
	var blocked := 0
	var from_guard := 0
	var from_barrier := 0
	var defense_name := ""
	var defense_kind := ""
	if dodge != null and dodge.is_dodge():
		defense_name = dodge.display_name
		defense_kind = "Dodge"
		blocked = amount
		amount = 0
	elif amount > 0 and (defender.guard > 0 or defender.standing_guard > 0):
		var guard_before := defender.guard
		var barrier_before := defender.standing_guard
		blocked = defender.spend_guard(amount)
		from_guard = guard_before - defender.guard
		from_barrier = barrier_before - defender.standing_guard
		defense_kind = "Barrier" if from_guard <= 0 else "Guard"
		amount -= blocked
	defender.hp = maxi(defender.hp - amount, 0)
	var destroyed := defender.hp == 0
	if destroyed:
		defender.alive = false
	return {
		"attacker_id": attacker.id,
		"defender_id": defender.id,
		"damage": amount,
		"blocked": blocked,
		"from_guard": from_guard,
		"from_barrier": from_barrier,
		"defense_name": defense_name,
		"defense_kind": defense_kind,
		"destroyed": destroyed,
		"defender_hp": defender.hp,
	}


## Same kill check as resolve_attack, without spending guard or health.
static func would_destroy(attacker: MechState, defender: MechState, card: CardData, dodge: CardData = null) -> bool:
	if defender == null or not defender.alive or card == null:
		return false
	var amount := _attack_damage(attacker, card)
	if dodge != null and dodge.is_dodge():
		return false
	if amount > 0 and (defender.guard > 0 or defender.standing_guard > 0):
		var soak := maxi(defender.guard, 0) + maxi(defender.standing_guard, 0)
		amount -= mini(amount, soak)
	return amount >= defender.hp and defender.hp > 0


static func _attack_damage(attacker: MechState, card: CardData) -> int:
	if card == null:
		return 0
	if card.card_type != "Attack":
		return 0
	if attacker != null and attacker.team == "player":
		return GameManager.card_damage(card)
	return maxi(card.damage, 0)
