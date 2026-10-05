## Stat, status, and info icons all render in this box so badges match across screens.
class_name UiIcons
extends RefCounted

## The icon art is drawn at 32, so procedural icons use this for their own pixel math too.
const SIZE := 24
const BOX := Vector2(SIZE, SIZE)

## Same sentences as the legend. Card icons use these as their hover text.
const PHRASES := {
	"atk": "Damage this card deals.",
	"rng": "How far this card can reach.",
	"mov": "Cells this card moves.",
	"dodge": "This card negates one incoming attack.",
	"def": "Guard that absorbs hits before hit points. Only active during a battle.",
	"bar": "Barrier that absorbs hits after guard, before hit points. Remains after battle.",
}


static func phrase(kind: String) -> String:
	return str(PHRASES.get(kind, ""))


static func keeps_mouse(control: Control) -> bool:
	return control.name == "SpecialInfo" or control.has_meta("keep_mouse")
