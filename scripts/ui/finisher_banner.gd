class_name FinisherBanner
extends Control

const HOLD := 1.38
const POSE_RISE := Vector2(-36, -64)

var _playing := false
var _pose_home := Vector2.ZERO

@onready var dim: ColorRect = %Dim
@onready var stripe: Control = %Stripe
@onready var pose: TextureRect = %Portrait
@onready var pilot: TextureRect = %Pilot
@onready var title: Label = %Title


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pose_home = pose.position
	title.add_theme_color_override("font_color", Color.WHITE)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 10)


func play(unit: MechState) -> void:
	if _playing or unit == null:
		return
	_playing = true
	if size.x < 2.0:
		await get_tree().process_frame
	if not is_inside_tree():
		_playing = false
		return
	_show_unit(unit)
	var stripe_w := stripe.size.x
	var stripe_h := stripe.size.y
	if stripe_w < 2.0 or stripe_h < 2.0:
		stripe_w = 1280.0
		stripe_h = 334.0
		stripe.size = Vector2(stripe_w, stripe_h)
	var mid_x := (size.x - stripe_w) * 0.5
	var y := (size.y - stripe_h) * 0.5
	stripe.position = Vector2(-stripe_w - 48.0, y)
	stripe.modulate.a = 1.0
	pose.position = _pose_home + POSE_RISE
	dim.color.a = 0.0
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	var enter := create_tween()
	enter.set_parallel(true)
	enter.tween_property(stripe, "position:x", mid_x, 0.36).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	enter.tween_property(dim, "color:a", 0.4, 0.2)
	await enter.finished
	if not is_inside_tree():
		return
	var drift := create_tween()
	drift.tween_property(pose, "position", _pose_home, HOLD).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await drift.finished
	if not is_inside_tree():
		return
	var leave := create_tween()
	leave.set_parallel(true)
	leave.tween_property(stripe, "position:x", size.x + 48.0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	leave.tween_property(stripe, "modulate:a", 0.0, 0.5)
	leave.tween_property(dim, "color:a", 0.0, 0.5)
	await leave.finished
	if is_inside_tree():
		visible = false
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	_playing = false


func _show_unit(unit: MechState) -> void:
	pose.texture = _pose_for(unit.art_id)
	pilot.texture = _load_art(unit.art_id, "pilot.png")


func _pose_for(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	var named := _load_art(art_id, "%s-fire-pose.png" % art_id)
	if named != null:
		return named
	return _load_art(art_id, "fire_pose.png")


func _load_art(art_id: String, file_name: String) -> Texture2D:
	if art_id == "":
		return null
	var path := "res://art/mechs/player/%s/%s" % [art_id, file_name]
	if not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
