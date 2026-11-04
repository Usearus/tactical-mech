extends BaseButton

## The battle confirm click, on every button that uses this script.


func _ready() -> void:
	pressed.connect(_play_click)


func _play_click() -> void:
	SoundBank.play("ui")
