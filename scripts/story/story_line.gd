class_name StoryLine
extends Resource

## Name on the dialogue bar. Blank hides the name.
@export var speaker: String = ""
@export_multiline var text: String = ""
## Bust drawn in the bar. Blank is a name-only line.
@export var portrait: Texture2D
## Idle mech on the street. Matches a folder under art/mechs/player, such as "purple".
@export var art_id: String = ""
