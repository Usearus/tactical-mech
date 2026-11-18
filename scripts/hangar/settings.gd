extends Control

@onready var back_button: BaseButton = %BackButton
@onready var music_slider: HSlider = %MusicSlider
@onready var effects_slider: HSlider = %EffectsSlider

var _leaving := false
var _dragging_effects := false


func _ready() -> void:
	back_button.pressed.connect(_on_back_pressed)
	music_slider.set_value_no_signal(SoundBank.music_percent())
	effects_slider.set_value_no_signal(SoundBank.effects_percent())
	music_slider.value_changed.connect(_on_music_changed)
	effects_slider.value_changed.connect(_on_effects_changed)
	effects_slider.drag_started.connect(_on_effects_drag_started)
	effects_slider.drag_ended.connect(_on_effects_drag_ended)


func _on_back_pressed() -> void:
	if _leaving:
		return
	_leaving = true
	back_button.disabled = true
	GameManager.go_to_command()


func _on_music_changed(value: float) -> void:
	SoundBank.set_music_percent(value)


func _on_effects_changed(value: float) -> void:
	SoundBank.set_effects_percent(value)
	if _dragging_effects:
		return
	SoundBank.play("ui")


func _on_effects_drag_started() -> void:
	_dragging_effects = true


func _on_effects_drag_ended(_value_changed: bool) -> void:
	_dragging_effects = false
	SoundBank.play("ui")
