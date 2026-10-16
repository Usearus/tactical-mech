class_name HandOwnerBadge
extends Control

## Matches the root scale on hand_owner_badge.tscn.
const PIN_SCALE := 0.7
## Above SceneryShade and the battle-cell Vitals, both drawn at z 8.
## A lifted card uses DRAW_Z + 1 so it covers this mark.
const DRAW_Z := 12

static var _portraits: Dictionary = {}

@onready var _pin: TextureRect = $Pin
@onready var _head: TextureRect = $Head


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	if _pin != null:
		_pin.mouse_filter = MOUSE_FILTER_IGNORE
		if _pin.material != null:
			_pin.material = _pin.material.duplicate()
	if _head != null:
		_head.mouse_filter = MOUSE_FILTER_IGNORE
		_head.texture = null


func show_head(art_id: String, rim: Color) -> void:
	if not is_node_ready():
		call_deferred("show_head", art_id, rim)
		return
	if _pin != null:
		var mat := _pin.material as ShaderMaterial
		if mat != null:
			mat.set_shader_parameter("rim", rim)
	var portrait := _portrait_for(art_id)
	if portrait == null:
		_show_crop(null, Rect2())
		return
	_show_crop(portrait, _head_uv(portrait))


func _show_crop(portrait: Texture2D, window: Rect2) -> void:
	if _head == null:
		return
	if portrait == null or window.size.x <= 0.0 or window.size.y <= 0.0:
		_head.texture = null
		return
	var frame := portrait.get_size()
	var crop := AtlasTexture.new()
	crop.atlas = portrait
	crop.region = Rect2(window.position * frame, window.size * frame)
	_head.texture = crop


static func _portrait_for(art_id: String) -> Texture2D:
	if art_id == "":
		return null
	if _portraits.has(art_id):
		return _portraits[art_id]
	var baked := _bake(_frame_of(MechSprites.frames_for(art_id)))
	_portraits[art_id] = baked
	return baked


static func _frame_of(frames: SpriteFrames) -> Texture2D:
	if frames == null or not frames.has_animation("idle") or frames.get_frame_count("idle") < 1:
		return null
	return frames.get_frame_texture("idle", 0)


static func _bake(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if texture is AtlasTexture:
		var image := (texture as AtlasTexture).get_image()
		if image == null:
			return null
		return ImageTexture.create_from_image(image)
	return texture


## Square around the head, in the texture's own UV space.
static func _head_uv(texture: Texture2D) -> Rect2:
	var frame := texture.get_size()
	if frame.x < 1.0 or frame.y < 1.0:
		return Rect2(0, 0, 1, 1)
	var used := MechSprites.content_rect(texture)
	if used.size.x < 1.0 or used.size.y < 1.0:
		used = Rect2(Vector2.ZERO, frame)
	var standing := used.size.y >= used.size.x * 0.85
	var fraction := 0.5 if standing else 0.82
	var side := minf(used.size.x, used.size.y * fraction)
	var window := Rect2(
		used.position.x + (used.size.x - side) * 0.5,
		used.position.y,
		side,
		side
	)
	return Rect2(window.position / frame, window.size / frame)


