class_name MissionRecordRow
extends PanelContainer

## Same gold as the S and A grades on the select screen.
const TIER_GOLD := Color(0.98, 0.84, 0.32)
const PLAIN := Color(0.9, 0.92, 0.95)

@onready var _portrait_host: Control = %Portrait
@onready var _pilot: AnimatedSprite2D = %Pilot
@onready var _name_label: Label = %Name
@onready var _destroyed_label: Label = %Destroyed
@onready var _dealt_label: Label = %Dealt
@onready var _taken_label: Label = %Taken
@onready var _mvp_label: Label = %Mvp


func show_line(unit: MechState, destroyed: int, dealt: int, taken: int, mvp: bool, gold_destroyed: bool, gold_dealt: bool, gold_taken: bool) -> void:
	_name_label.text = "" if unit == null else unit.display_name
	_destroyed_label.text = str(destroyed)
	_dealt_label.text = str(dealt)
	_taken_label.text = str(taken)
	_paint(_destroyed_label, gold_destroyed)
	_paint(_dealt_label, gold_dealt)
	_paint(_taken_label, gold_taken)
	_mvp_label.text = "MVP" if mvp else ""
	_mvp_label.add_theme_color_override("font_color", TIER_GOLD)
	_bind_portrait(unit)


func _paint(label: Label, gold: bool) -> void:
	label.add_theme_color_override("font_color", TIER_GOLD if gold else PLAIN)


func _bind_portrait(unit: MechState) -> void:
	var frames := MechSprites.pilot_frames("" if unit == null else unit.art_id)
	if frames == null or not frames.has_animation("idle"):
		_pilot.visible = false
		return
	_pilot.visible = true
	_pilot.sprite_frames = frames
	if MechSprites.portrait_plays(frames):
		_pilot.play("idle")
	else:
		_pilot.play("idle")
		_pilot.pause()
		_pilot.frame = 0
	_pilot.modulate = Color(0.42, 0.42, 0.46) if unit != null and not unit.alive else Color.WHITE
	if not _portrait_host.resized.is_connected(_fit_portrait):
		_portrait_host.resized.connect(_fit_portrait)
	_fit_portrait()
	_fit_portrait.call_deferred()


func _fit_portrait() -> void:
	if _pilot.sprite_frames == null or _portrait_host.size.x < 1.0:
		return
	if not _pilot.sprite_frames.has_animation("idle"):
		return
	var tex := _pilot.sprite_frames.get_frame_texture("idle", 0)
	if tex == null:
		return
	var content := MechSprites.content_rect(tex)
	var longest := maxf(maxf(content.size.x, content.size.y), 1.0)
	var fit := minf(_portrait_host.size.x, _portrait_host.size.y) / longest
	_pilot.scale = Vector2(fit, fit)
	var shift := (content.get_center() - tex.get_size() * 0.5) * fit
	_pilot.position = _portrait_host.size * 0.5 - shift
