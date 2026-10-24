@tool
extends RichTextEffect

## [gold]keyword[/gold] in Rule Book directions. Same gold as S and A grades.
var bbcode := "gold"


func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	char_fx.color = Color(0.98, 0.84, 0.32)
	return true
