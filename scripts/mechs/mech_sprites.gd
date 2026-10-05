class_name MechSprites
extends RefCounted

const FRAME_SIZE := 64
const IDLE_FPS := 6.0
const ATTACK_FPS := 8.0

static var _cache: Dictionary = {}
static var _pilots: Dictionary = {}
static var _impact: SpriteFrames
static var _barrier: SpriteFrames
static var _content_rects: Dictionary = {}


static func frames_for(art_id: String) -> SpriteFrames:
	if art_id == "":
		return null
	if _cache.has(art_id):
		return _cache[art_id]
	var texture := _load_idle(art_id)
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	_add_strip(frames, "idle", texture, true, IDLE_FPS)
	var attack := _load_attack(art_id)
	if attack != null:
		_add_strip(frames, "attack", attack, false, ATTACK_FPS)
	_cache[art_id] = frames
	return frames


static func _slice_size(texture: Texture2D) -> Vector2i:
	var width := texture.get_width()
	var height := texture.get_height()
	for size in [65, 64]:
		if height == size and width % size == 0:
			return Vector2i(size, size)
	return Vector2i(mini(FRAME_SIZE, width), mini(FRAME_SIZE, height))


static func _add_strip(frames: SpriteFrames, anim_name: String, texture: Texture2D, looping: bool, fps: float) -> void:
	var slice := _slice_size(texture)
	var frame_w := slice.x
	var frame_h := slice.y
	if frame_w < 1 or frame_h < 1:
		return
	var frame_count := maxi(int(texture.get_width() / float(frame_w)), 1)
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, looping)
	frames.set_animation_speed(anim_name, fps)
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * frame_w, 0, frame_w, frame_h)
		frames.add_frame(anim_name, atlas)


static func pilot_frames(art_id: String) -> SpriteFrames:
	if art_id == "":
		return null
	if _pilots.has(art_id):
		return _pilots[art_id]
	var path := "res://art/mechs/player/%s/pilot.png" % art_id
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	var slice := _slice_size(texture)
	if texture.get_height() == slice.y and texture.get_width() > slice.x and texture.get_width() % slice.x == 0:
		_add_strip(frames, "idle", texture, true, IDLE_FPS)
	else:
		frames.add_animation("idle")
		frames.set_animation_loop("idle", false)
		frames.add_frame("idle", texture)
	_pilots[art_id] = frames
	return frames


## Visible pixels of a frame, ignoring the transparent margin around the drawing.
static func content_rect(texture: Texture2D) -> Rect2:
	var full := Rect2(Vector2.ZERO, texture.get_size()) if texture != null else Rect2()
	if texture == null:
		return full
	var key := texture.get_instance_id()
	if _content_rects.has(key):
		return _content_rects[key]
	var image := texture.get_image()
	if image == null:
		_content_rects[key] = full
		return full
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var min_x := width
	var min_y := height
	var max_x := -1
	var max_y := -1
	for y in height:
		for x in width:
			if image.get_pixel(x, y).a <= 0.06:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	var rect := full
	if max_x >= min_x and max_y >= min_y:
		rect = Rect2(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	_content_rects[key] = rect
	return rect


static func portrait_plays(frames: SpriteFrames) -> bool:
	return frames != null and frames.has_animation("idle") and frames.get_frame_count("idle") > 1


static func barrier_frames() -> SpriteFrames:
	if _barrier != null:
		return _barrier
	var path := "res://art/effects/barrier.png"
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	_add_strip(frames, "idle", texture, true, IDLE_FPS)
	if not frames.has_animation("idle"):
		return null
	_barrier = frames
	return _barrier


static func impact_frames() -> SpriteFrames:
	if _impact != null:
		return _impact
	var path := "res://art/effects/bullet_explosion.png"
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	_add_strip(frames, "impact", texture, false, ATTACK_FPS)
	if not frames.has_animation("impact"):
		return null
	_impact = frames
	return _impact


static func _load_idle(art_id: String) -> Texture2D:
	for folder in ["player", "enemy"]:
		var path := "res://art/mechs/%s/%s/idle.png" % [folder, art_id]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null


static func _load_attack(art_id: String) -> Texture2D:
	for folder in ["player", "enemy"]:
		var dir_path := "res://art/mechs/%s/%s" % [folder, art_id]
		for file_name in ["fire_gun.png", "fire_rifle.png", "fire_missiles.png", "fire_rocket.png", "fire_rocket_launcher.png", "fire_laser.png"]:
			var path := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null
