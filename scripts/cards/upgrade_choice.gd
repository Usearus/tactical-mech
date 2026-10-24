class_name UpgradeChoice
extends RefCounted

var offer: UpgradeOffer
var kind: String = ""
var rarity: int = 1
var mechs: Array[MechState] = []
## The mech who receives a grant, a modify, or a revive. Empty for a group effect.
var bound_mech: MechState
var preview: CardData
var family: String = ""
## One row will not show two choices that share this key.
var slot_key: String = ""
## Stat boosts already covered by this row, such as buff:barrier or buff:damage.
var buff_keys: PackedStringArray = []
