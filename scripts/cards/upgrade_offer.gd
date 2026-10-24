@tool
class_name UpgradeOffer
extends Resource

## Grant adds a card. Modify boosts one the mech already has.
## Immediate is a group effect. Revive brings a destroyed mech back.
@export_enum("Grant", "Modify", "Immediate", "Revive") var kind: String = "Modify"
@export_range(1, 3, 1) var rarity: int = 1
@export var id: String = ""
## Set on a grant or a modify. Team and revive templates leave this empty.
@export var mech_id: String = ""
@export var display_name: String = ""
## The card added for the rest of the mission. Grant only.
@export var card: CardData
## Id stem of the deck card to boost. bastion_piledriver covers the _2 copy too.
@export var card_family: String = ""
@export var damage_add: int = 0
@export var movement_add: int = 0
@export var make_free: bool = false
## Used when this boost first gives an attack a step.
@export_enum("Before", "After") var movement_timing: String = "Before"
@export var barrier: int = 0
## One sentence shown on the preview and kept on the boosted card.
@export var blurb: String = ""
