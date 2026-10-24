class_name MechData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var short_name: String = ""
@export var team: String = "player"
@export var max_hp: int = 10
## Barrier this mech deploys with. Nothing refills it, so it lasts until attacks wear it down.
@export var barrier: int = 0
@export var move_range: int = 2
## Farthest cell this mech can attack across on the overworld. 1 is the next cell.
@export var attack_range: int = 1
## Nearest cell this mech can open a fight from. 0 matches attack_range, so that distance is exact.
@export var attack_range_min: int = 0
## Higher speed acts earlier on the overworld timeline.
@export var speed: int = 1
## Enemy only. How many player actions between this mech's actions.
## A free card, a charge card, and a discard do not count. After it acts, the count starts over.
@export var turn_count: int = 3
## Shown on the select screen. Grades are S, A, B, C, or D.
@export_multiline var blurb: String = ""
@export var hp_grade: String = ""
@export var atk_grade: String = ""
@export var rng_grade: String = ""
@export var move_grade: String = ""
@export var speed_grade: String = ""
@export var color: Color = Color.WHITE
@export var art_id: String = ""
## Drawn size against the other mechs. 1 is full size.
@export_range(0.2, 2.0, 0.05) var sprite_scale: float = 1.0

## Hover text for each stat on the select screen. Keys match the StatGrid node prefixes. The same lines are in How to Play.
const STAT_TIPS := {
	"Hp": "HP = Hit points at start of mission",
	"Atk": "ATK = Attack power from deck",
	"Rng": "RNG = Attack range from deck. Also initiate attack distance.",
	"Mov": "MOV = Movement range on map",
	"Spd": "SPD = Higher speed moves first on map",
}
