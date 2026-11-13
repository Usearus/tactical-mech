## Stat, status, and info icons all render in this box so badges match across screens.
class_name UiIcons
extends RefCounted

## The icon art is drawn at 32, so procedural icons use this for their own pixel math too.
const SIZE := 24
const BOX := Vector2(SIZE, SIZE)

## Same sentences as the legend. Card icons use these as their hover text.
const PHRASES := {
	"hp": "Health: Hit points left before this mech is destroyed.",
	"act": "Action: Cards left before this enemy takes a turn.",
	"atk": "Attack: Damage this card deals.",
	"rng": "Range: How far this card can reach.",
	"mov": "Move: Cells this card moves.",
	"evade": "Evade: Has [gold]Retain[/gold] and negates one incoming attack.",
	"int": "Intercept: Takes the hit of any ally that is 1 cell away.",
	"def": "Guard: Absorbs hits before hit points. Only active during a battle.",
	"bar": "Barrier: Absorbs hits after guard, before hit points. Remains after battle.",
	"chg": "Charge: Added to the squad gauge.",
}


static func phrase(kind: String) -> String:
	return str(PHRASES.get(kind, ""))


## [gold]Keyword:[/gold] for a note that starts with one word and a colon.
static func gold_lead(note: String) -> String:
	var split_at := note.find(":")
	if split_at <= 0:
		return note
	var lead := note.substr(0, split_at)
	if lead.contains(" ") or lead.contains("\n"):
		return note
	return "[gold]%s:[/gold]%s" % [lead, note.substr(split_at + 1)]


static func keeps_mouse(control: Control) -> bool:
	return control.name == "SpecialInfo" or control.has_meta("keep_mouse")
