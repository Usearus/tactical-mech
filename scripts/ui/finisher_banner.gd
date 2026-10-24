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
@onready var fire_pose: AnimatedSprite2D = %FirePose


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pose_home = pose.position
	fire_pose.visible = false
	fire_pose.animation_finished.connect(_on_fire_pose_finished)
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
		_stop_fire_pose()
	_playing = false


func _show_unit(unit: MechState) -> void:
	pilot.texture = _load_pilot(unit.art_id)
	if _show_attack_strip(unit):
		return
	_stop_fire_pose()
	pose.texture = _pose_for(unit.art_id)


## Raven and Bastion play their attack strip. A still pose is used for everyone else.
static func uses_attack_strip(unit: MechState) -> bool:
	if unit == null:
		return false
	var mech_id := ""
	if unit.data != null:
		mech_id = unit.data.id
	return unit.art_id == "purple" or mech_id == "raven" or unit.art_id == "blue" or mech_id == "bastion"


func _show_attack_strip(unit: MechState) -> bool:
	if not uses_attack_strip(unit):
		return false
	var frames := MechSprites.frames_for(unit.art_id)
	if frames == null or not frames.has_animation("attack"):
		return false
	var tex := frames.get_frame_texture("attack", 0)
	var frame := tex.get_size() if tex != null else Vector2(64, 64)
	var box := pose.size
	if box.x < 2.0 or box.y < 2.0:
		box = Vector2(566, 527)
	var longest := maxf(frame.x, frame.y)
	if longest <= 0.0:
		return false
	pose.texture = null
	fire_pose.sprite_frames = frames
	fire_pose.scale = Vector2.ONE * (minf(box.x, box.y) / longest)
	fire_pose.position = box * 0.5
	fire_pose.visible = true
	fire_pose.play("attack")
	return true


func _on_fire_pose_finished() -> void:
	_replay_fire_pose.call_deferred()


func _replay_fire_pose() -> void:
	if _playing and fire_pose.visible and is_inside_tree():
		fire_pose.play("attack")


func _stop_fire_pose() -> void:
	fire_pose.visible = false
	if fire_pose.sprite_frames != null:
		fire_pose.stop()


func _pose_for(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	var named := _load_art(art_id, "%s.fire-pose.png" % art_id)
	if named != null:
		return named
	named = _load_art(art_id, "%s-fire-pose.png" % art_id)
	if named != null:
		return named
	return _load_art(art_id, "fire_pose.png")


func _load_pilot(art_id: String) -> Texture2D:
	return _load_from("res://art/characters/player/%s/pilot.png" % art_id)


func _load_art(art_id: String, file_name: String) -> Texture2D:
	return _load_from("res://art/mechs/player/%s/%s" % [art_id, file_name])


func _load_from(path: String) -> Texture2D:
	if path == "" or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D
