extends HBoxContainer

## Help and menu buttons that live in a screen's own layout.
## The star opens the mission's bonuses. Mech select leaves it off.
## The rewards gallery leaves the help button off.
@export var show_star := false
@export var show_help := true


func _ready() -> void:
	var help := $HowToButton as BaseButton
	help.visible = show_help
	help.pressed.connect(GameMenu.open_help)
	$MenuButton.pressed.connect(GameMenu.toggle)
	var star := $StarButton as BaseButton
	star.visible = show_star
	star.pressed.connect(GameMenu.open_bonuses)
	var slots := 1
	if show_star:
		slots += 1
	if show_help:
		slots += 1
	custom_minimum_size = Vector2(slots * 56 + (slots - 1) * 12, 56)
