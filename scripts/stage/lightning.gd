extends Node2D

## A strike is a short flash plus one burst of bolts. The gap timer owns the rhythm.
@export var min_gap := 4.0
@export var max_gap := 9.0
@export var flash_alpha := 0.4
@export var flash_time := 0.14

@onready var flash: Polygon2D = $Flash
@onready var bolts: GPUParticles2D = $Bolts
@onready var gap: Timer = $Gap

var _flash_tween: Tween


func _ready() -> void:
	_set_flash_alpha(0.0)
	gap.one_shot = true
	gap.timeout.connect(_strike)
	gap.start(randf_range(1.0, 3.2))


func _strike() -> void:
	bolts.restart()
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_set_flash_alpha(flash_alpha)
	_flash_tween = create_tween()
	_flash_tween.tween_property(flash, "color:a", 0.0, flash_time)
	gap.start(randf_range(min_gap, max_gap))


func _set_flash_alpha(alpha: float) -> void:
	var color := flash.color
	color.a = alpha
	flash.color = color
