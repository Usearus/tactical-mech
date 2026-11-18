class_name MechProgressionTile
extends PanelContainer

signal chosen(mech_id: String)

var _data: MechData

@onready var _stage: Control = %Stage
@onready var _pilot: AnimatedSprite2D = %Pilot
@onready var _mech: AnimatedSprite2D = %Mech
@onready var _name_label: Label = %Name


func _ready() -> void:
	if _stage != null and not _stage.resized.is_connected(_place_pair):
		_stage.resized.connect(_place_pair)


func show_mech(data: MechData) -> void:
	_data = data
	if _name_label != null:
		_name_label.text = "" if data == null else data.display_name
	if data == null:
		return
	var pilot := MechSprites.pilot_frames(data.art_id)
	_apply_sprite(_pilot, pilot, MechSprites.portrait_plays(pilot))
	_apply_sprite(_mech, MechSprites.frames_for(data.art_id), true)
	_place_pair()


func _gui_input(event: InputEvent) -> void:
	if _data == null or _data.id == "":
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		SoundBank.play("ui")
		chosen.emit(_data.id)
		accept_event()


func _apply_sprite(sprite: AnimatedSprite2D, frames: SpriteFrames, animate: bool) -> void:
	if sprite == null:
		return
	if frames == null or not frames.has_animation("idle"):
		sprite.visible = false
		return
	sprite.visible = true
	if sprite.sprite_frames != frames:
		sprite.sprite_frames = frames
		sprite.play("idle")
	if animate:
		if not sprite.is_playing():
			sprite.play("idle")
	else:
		sprite.pause()
		sprite.frame = 0
	sprite.flip_h = false


## Same stagger as squad select: the pilot stands in front, the mech sits larger and to the right, both on one floor line. The pair is centered in the box.
func _place_pair() -> void:
	if _stage == null or _pilot == null or _mech == null:
		return
	if _stage.size.x < 8.0 or _stage.size.y < 8.0:
		return
	var pilot_shown := _pilot.visible
	var mech_shown := _mech.visible
	if not pilot_shown and not mech_shown:
		return
	var area_height := _stage.size.y - 8.0
	var area_width := _stage.size.x - 16.0
	var mech_slot := minf(area_height, area_width * 0.78)
	if mech_slot < 32.0:
		return
	var pilot_slot := mech_slot * 0.58
	var baseline := _stage.size.y - 4.0
	if pilot_shown and mech_shown:
		var mech_offset := (pilot_slot - mech_slot) * 0.5 + mech_slot * 0.34
		var group_left := 4.0
		var group_right := group_left + mech_offset + mech_slot
		var nudge := (_stage.size.x - (group_right - group_left)) * 0.5 - group_left
		_place_sprite(_pilot, pilot_slot, group_left + nudge, baseline, true)
		_place_sprite(_mech, mech_slot, group_left + mech_offset + nudge, baseline, false)
	elif pilot_shown:
		_place_sprite(_pilot, pilot_slot, (_stage.size.x - pilot_slot) * 0.5, baseline, true)
	else:
		_place_sprite(_mech, mech_slot, (_stage.size.x - mech_slot) * 0.5, baseline, false)


func _place_sprite(sprite: AnimatedSprite2D, slot: float, left: float, baseline: float, use_content: bool) -> void:
	var tex_size := Vector2(MechSprites.FRAME_SIZE, MechSprites.FRAME_SIZE)
	var tex: Texture2D = null
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation("idle"):
		tex = sprite.sprite_frames.get_frame_texture("idle", 0)
		if tex != null:
			tex_size = tex.get_size()
	var content := Rect2(Vector2.ZERO, tex_size)
	if use_content and tex != null:
		content = MechSprites.content_rect(tex)
	var longest := maxf(content.size.x, content.size.y)
	if longest < 1.0:
		longest = maxf(tex_size.x, tex_size.y)
	var fit := slot / longest
	sprite.scale = Vector2(fit, fit)
	var content_center_x := content.position.x + content.size.x * 0.5
	var content_bottom := content.position.y + content.size.y
	sprite.position = Vector2(
		left + slot * 0.5 - (content_center_x - tex_size.x * 0.5) * fit,
		baseline - (content_bottom - tex_size.y * 0.5) * fit
	)
