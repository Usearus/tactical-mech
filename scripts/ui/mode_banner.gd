class_name ModeBanner
extends Control

const ATTACK_BAR := Color(0.07, 0.16, 0.28)
const DEFENCE_BAR := Color(0.12, 0.15, 0.18)
const ATTACK_EDGE := Color(0.95, 0.46, 0.16)
const DEFENCE_EDGE := Color(0.45, 0.78, 1.0)

var _playing := false
var _holding_world := false

@onready var dim: ColorRect = %Dim
@onready var stripe: Control = %Stripe
@onready var bar: ColorRect = %Bar
@onready var edge: ColorRect = %Edge
@onready var title: Label = %Title


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 10)


func _exit_tree() -> void:
	_release_world()


## hold_world freezes the rest of the game until the stripe has left.
func play(line: String, attack: bool, hold_world := false) -> void:
	if _playing:
		return
	_playing = true
	if size.x < 2.0:
		await get_tree().process_frame
	if not is_inside_tree():
		_playing = false
		return
	if hold_world:
		_hold_world()
	title.text = line
	bar.color = ATTACK_BAR if attack else DEFENCE_BAR
	edge.color = ATTACK_EDGE if attack else DEFENCE_EDGE
	var stripe_w := clampf(size.x * 0.68, 520.0, 900.0)
	var stripe_h := 132.0
	stripe.size = Vector2(stripe_w, stripe_h)
	var mid_x := (size.x - stripe_w) * 0.5
	var y := (size.y - stripe_h) * 0.5
	stripe.position = Vector2(-stripe_w - 48.0, y)
	stripe.modulate.a = 1.0
	dim.color.a = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var enter := _tween()
	enter.set_parallel(true)
	enter.tween_property(stripe, "position:x", mid_x, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(dim, "color:a", 0.4, 0.2)
	await enter.finished
	if not is_inside_tree():
		_end_play()
		return
	var hold := get_tree().create_timer(0.38, true) if _holding_world else get_tree().create_timer(0.38)
	await hold.timeout
	if not is_inside_tree():
		_end_play()
		return
	var leave := _tween()
	leave.set_parallel(true)
	leave.tween_property(stripe, "position:x", size.x + 48.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(stripe, "modulate:a", 0.0, 0.5)
	leave.tween_property(dim, "color:a", 0.0, 0.5)
	await leave.finished
	if is_inside_tree():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	_end_play()


func _tween() -> Tween:
	var tween := create_tween()
	if _holding_world:
		tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	return tween


func _hold_world() -> void:
	_holding_world = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true


func _release_world() -> void:
	if not _holding_world:
		return
	_holding_world = false
	process_mode = Node.PROCESS_MODE_INHERIT
	if is_inside_tree():
		get_tree().paused = false


func _end_play() -> void:
	_release_world()
	_playing = false
