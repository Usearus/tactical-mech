class_name CardData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var card_type: String = "Attack"
## Held out of the hand until Overdrive. A deck can mark more than one.
@export var is_special: bool = false
## Guard adds block to a mech. Dodge stays in hand and negates one attack.
@export_enum("Guard", "Dodge") var defense_kind: String = "Guard"
@export var damage: int = 0
## Guard added when this card is played. Dodge cards ignore this and negate the attack.
@export var block: int = 0
## Standing barrier added when this card is played. It stays after the battle.
@export var barrier: int = 0
@export var reach: int = 1
## When set, the target must be exactly `reach` cells away.
@export var exact_range: bool = false
@export var movement: int = 0
## When an attack also moves: step first, strike first, or do not move.
@export_enum("None", "Before", "After") var move_timing: String = "None"
@export var target_type: String = "enemy"
## When set, this mech catches the next hit aimed at an adjacent ally.
@export var intercept: bool = false
@export var cut_in: String = ""


func is_guard() -> bool:
	return card_type == "Defense" and defense_kind == "Guard"


func is_dodge() -> bool:
	return card_type == "Defense" and defense_kind == "Dodge"


## Played onto an adjacent ally. Other guard cards protect the owner.
func guards_ally() -> bool:
	return is_guard() and target_type == "ally"


## A step with no strike and no guard.
func moves_only() -> bool:
	return card_type == "Move" and movement > 0


func moves_before() -> bool:
	return card_type == "Attack" and movement > 0 and move_timing == "Before"


## Step first, then strike or guard. The step is legal even when the follow-up is not.
func steps_then_acts() -> bool:
	return movement > 0 and move_timing == "Before"


func moves_after() -> bool:
	return card_type == "Attack" and movement > 0 and move_timing == "After"


## Hits the cell ahead and the cells above and below it. Allies are hit too.
func hits_front() -> bool:
	return target_type == "front"


func reaches(distance: int) -> bool:
	if distance <= 0 or reach <= 0:
		return false
	if exact_range:
		return distance == reach
	return distance <= reach
