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
## Cells this mech can attack across on the overworld. 1 is the next cell.
@export var attack_range: int = 1
## Higher speed acts earlier on the overworld timeline.
@export var speed: int = 1
## Enemy only. How many cards the player plays between this mech's actions.
## A discard does not count. After it acts, the count starts over.
@export var turn_count: int = 3
## How much this mech adds to the squad attack gauge's length. Player mechs only.
@export var charge: int = 1
## Shown on the select screen. Grades are S, A, B, C, or D. Charge is labeled OVD there.
@export_multiline var blurb: String = ""
@export var hp_grade: String = ""
@export var atk_grade: String = ""
@export var rng_grade: String = ""
@export var move_grade: String = ""
@export var speed_grade: String = ""
@export var charge_grade: String = ""
@export var color: Color = Color.WHITE
@export var art_id: String = ""

## Hover text for the mech select stats. The same lines are in How to Play.
const STAT_GUIDE := "HP = Hit points at start of mission\nATK = Attack power from deck\nRNG = Attack range from deck. Also initiate attack distance.\nMOV = Movement range on map\nSPD = Higher speed moves first on map\nOVD = Additional actions needed to activate Overdrive"
