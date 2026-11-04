extends HBoxContainer

## Help and menu buttons that live in a screen's own layout.
## The star opens the mission's bonuses. Mech select and the briefing leave it off.
@export var show_star := false


func _ready() -> void:
	$HowToButton.pressed.connect(GameMenu.open_help)
	$MenuButton.pressed.connect(GameMenu.toggle)
	var star := $StarButton as BaseButton
	star.visible = show_star
	if show_star:
		custom_minimum_size = Vector2(192, 56)
	star.pressed.connect(GameMenu.open_bonuses)
