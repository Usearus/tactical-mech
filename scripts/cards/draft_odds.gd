@tool
class_name DraftOdds
extends Resource

const PATH := "res://data/upgrades/draft_odds.tres"

## Relative weights. They do not have to sum to 100.
@export var weight_1: int = 60
@export var weight_2: int = 30
@export var weight_3: int = 10
## Rerolls shared by every upgrade offer until the mission ends.
@export var refreshes_per_mission: int = 2


static func load_saved() -> DraftOdds:
	if ResourceLoader.exists(PATH):
		var loaded := load(PATH) as DraftOdds
		if loaded != null:
			return loaded
	return DraftOdds.new()


## 1v1 and a player advantage make 2- and 3-star cards rarer. An even fight of two or more keeps these weights. A smaller squad against more enemies makes them more common.
func for_fight(players: int, enemies: int) -> DraftOdds:
	var copy := duplicate() as DraftOdds
	if enemies <= 1 or players > enemies:
		var second := int(round(float(weight_2) * 0.5))
		var third := int(round(float(weight_3) * 0.5))
		copy.weight_2 = maxi(second, 0)
		copy.weight_3 = maxi(third, 0)
		copy.weight_1 = weight_1 + (weight_2 - copy.weight_2) + (weight_3 - copy.weight_3)
	elif players > 0 and players < enemies:
		var bonus_2 := int(round(float(weight_2) * 0.5))
		var bonus_3 := weight_3
		var room := weight_1
		var take_2 := mini(maxi(bonus_2, 0), room)
		var take_3 := mini(maxi(bonus_3, 0), room - take_2)
		copy.weight_1 = weight_1 - take_2 - take_3
		copy.weight_2 = weight_2 + take_2
		copy.weight_3 = weight_3 + take_3
	return copy


## Each card rolls on its own, so one row can hold more than one 3-star.
func roll_rarity(rng: RandomNumberGenerator) -> int:
	var first := maxi(weight_1, 0)
	var second := maxi(weight_2, 0)
	var third := maxi(weight_3, 0)
	var total := first + second + third
	if total <= 0 or rng == null:
		return 1
	var roll := rng.randi_range(1, total)
	if roll <= first:
		return 1
	if roll <= first + second:
		return 2
	return 3
