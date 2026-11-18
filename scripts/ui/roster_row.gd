extends Button

@export var open_style: StyleBox
@export var open_hover_style: StyleBox
@export var open_pressed_style: StyleBox
@export var filled_style: StyleBox
@export var filled_hover_style: StyleBox
@export var filled_pressed_style: StyleBox

var _checked := false


func _ready() -> void:
	pressed.connect(func() -> void:
		SoundBank.play("ui")
	)
	_apply()


func set_checked(on: bool) -> void:
	_checked = on
	_apply()


func _apply() -> void:
	if open_style == null:
		return
	if not _checked:
		var open_hover := open_hover_style if open_hover_style != null else open_style
		var open_down := open_pressed_style if open_pressed_style != null else open_style
		add_theme_stylebox_override("normal", open_style)
		add_theme_stylebox_override("disabled", open_style)
		add_theme_stylebox_override("hover", open_hover)
		add_theme_stylebox_override("focus", open_hover)
		add_theme_stylebox_override("pressed", open_down)
		add_theme_stylebox_override("hover_pressed", open_down)
		return
	var hover := filled_hover_style if filled_hover_style != null else filled_style
	var down := filled_pressed_style if filled_pressed_style != null else filled_style
	add_theme_stylebox_override("normal", filled_style)
	add_theme_stylebox_override("disabled", filled_style)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("pressed", down)
	add_theme_stylebox_override("hover_pressed", down)
