extends HBoxContainer

## Help and menu buttons that live in a screen's own layout.


func _ready() -> void:
	$HowToButton.pressed.connect(GameMenu.open_help)
	$MenuButton.pressed.connect(GameMenu.toggle)
