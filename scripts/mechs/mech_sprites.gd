class_name MechSprites
extends RefCounted

const FRAME_SIZE := 64
const IDLE_FPS := 6.0
const ATTACK_FPS := 8.0
const BOOST_FPS := 10.0

static var _cache: Dictionary = {}
static var _pilots: Dictionary = {}
static var _explosions: Dictionary = {}
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
	var attack := _load_attack(art_id)
	texture = _match_attack_scale(texture, attack)
	var frames := SpriteFrames.new()
	_add_strip(frames, "idle", texture, true, IDLE_FPS)
	if attack != null:
		_add_strip(frames, "attack", attack, false, ATTACK_FPS)
	var boosting := _load_boosting(art_id)
	if boosting != null:
		_add_strip(frames, "boosting", boosting, true, BOOST_FPS)
	_cache[art_id] = frames
	return frames


## Wider attack frames keep the idle frame's back edge and grow toward the facing side.
## flip_h mirrors the texture in place, so the shift is mirrored by hand.
static func reach_offset(sprite: AnimatedSprite2D) -> Vector2:
	if sprite == null or sprite.sprite_frames == null or sprite.animation != "attack":
		return Vector2.ZERO
	var frames := sprite.sprite_frames
	if not frames.has_animation("idle") or not frames.has_animation("attack"):
		return Vector2.ZERO
	var idle := frames.get_frame_texture("idle", 0)
	var strike := frames.get_frame_texture("attack", 0)
	if idle == null or strike == null:
		return Vector2.ZERO
	var extra := strike.get_width() - idle.get_width()
	if extra <= 0.0:
		return Vector2.ZERO
	var shift := extra * 0.5
	if sprite.flip_h:
		shift = -shift
	return Vector2(shift, 0.0)


## Boost pose while a mech travels. Mechs without a boosting sheet keep idle.
static func play_moving(sprite: AnimatedSprite2D) -> void:
	if sprite == null or sprite.sprite_frames == null:
		return
	if sprite.sprite_frames.has_animation("boosting"):
		sprite.play("boosting")
	elif sprite.sprite_frames.has_animation("idle"):
		sprite.play("idle")


static func _slice_size(texture: Texture2D) -> Vector2i:
	var width := texture.get_width()
	var height := texture.get_height()
	for size in [66, 65, 64, 32]:
		if height == size and width % size == 0:
			return Vector2i(size, size)
	if width > height and (height == 32 or height == 64 or height == 65 or height == 66):
		var frame_w := _repeating_width(texture)
		if frame_w > 0:
			return Vector2i(frame_w, height)
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
	var path := "res://art/characters/player/%s/pilot.png" % art_id
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


## Square frames across a horizontal strip. Mini is 16px, so it cannot share the mech slicer.
static func explosion_frames(size_name: String) -> SpriteFrames:
	if _explosions.has(size_name):
		return _explosions[size_name] as SpriteFrames
	var path := ""
	match size_name:
		"mini":
			path = "res://art/effects/explosion.mini.png"
		"small":
			path = "res://art/effects/explosion_small.png"
		"medium":
			path = "res://art/effects/explosion_medium.png"
		_:
			return null
	if not ResourceLoader.exists(path):
		return null
	var texture := load(path) as Texture2D
	if texture == null:
		return null
	var frames := SpriteFrames.new()
	var fps := 12.0
	if size_name == "medium":
		fps = 10.0
	_add_square_strip(frames, "burst", texture, fps)
	if not frames.has_animation("burst"):
		return null
	_explosions[size_name] = frames
	return frames


static func _add_square_strip(frames: SpriteFrames, anim_name: String, texture: Texture2D, fps: float) -> void:
	var frame := texture.get_height()
	var width := texture.get_width()
	if frame < 1 or width % frame != 0:
		return
	var frame_count := int(float(width) / float(frame))
	if frame_count < 1:
		return
	frames.add_animation(anim_name)
	frames.set_animation_loop(anim_name, false)
	frames.set_animation_speed(anim_name, fps)
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(index * frame, 0, frame, frame)
		frames.add_frame(anim_name, atlas)


static func idle_texture(art_id: String) -> Texture2D:
	return _load_idle(art_id)


## Idle drawn at half the attack sheet's pixel size is doubled so both poses match.
static func _match_attack_scale(idle: Texture2D, attack: Texture2D) -> Texture2D:
	if idle == null or attack == null:
		return idle
	var idle_h := _slice_size(idle).y
	var attack_h := _slice_size(attack).y
	if idle_h > 0 and attack_h == idle_h * 2:
		return _scaled(idle, 2)
	return idle


static func _scaled(texture: Texture2D, factor: int) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	image = image.duplicate()
	image.resize(image.get_width() * factor, image.get_height() * factor, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(image)


## Width of one cell on a strip that is wider than it is tall.
## A weak repeat returns 0 and the caller keeps the square fallback.
static func _repeating_width(texture: Texture2D) -> int:
	var image := texture.get_image()
	if image == null:
		return 0
	if image.is_compressed():
		image.decompress()
	var width := image.get_width()
	var height := image.get_height()
	var columns := PackedInt32Array()
	columns.resize(width)
	for x in width:
		var count := 0
		for y in height:
			if image.get_pixel(x, y).a > 0.06:
				count += 1
		columns[x] = count
	var best_w := 0
	var best_diff := 12.0
	for frame_w in range(height, height * 2 + 1):
		if width % frame_w != 0 or width < frame_w * 2:
			continue
		var diff := 0.0
		var samples := width - frame_w
		for x in samples:
			diff += absi(columns[x] - columns[x + frame_w])
		diff /= float(samples)
		if diff < best_diff:
			best_diff = diff
			best_w = frame_w
	return best_w


static func _load_idle(art_id: String) -> Texture2D:
	return _load_named(art_id, ["%s.idle.png" % art_id, "idle.png"])


static func _load_boosting(art_id: String) -> Texture2D:
	return _load_pose(art_id, "boosting")


static func _load_attack(art_id: String) -> Texture2D:
	for pose in ["attack", "fire_gun", "fire_rifle", "fire_missiles", "fire_rocket", "fire_rocket_launcher", "fire_laser"]:
		var texture := _load_pose(art_id, pose)
		if texture != null:
			return texture
	return null


## Player sheets, then the flat enemy folder, then each corp. Mission 1 is green. Mission 2 is red.
const _ART_ROOTS := [
	"res://art/mechs/player",
	"res://art/mechs/enemy",
	"res://art/mechs/enemy/Corp1-Green",
	"res://art/mechs/enemy/Corp2-Red",
]


static func _load_pose(art_id: String, pose: String) -> Texture2D:
	return _load_named(art_id, ["%s.%s.png" % [art_id, pose], "%s.png" % pose])


static func _load_named(art_id: String, file_names: Array) -> Texture2D:
	for root in _ART_ROOTS:
		var dir_path := "%s/%s" % [root, art_id]
		for file_name in file_names:
			var path := "%s/%s" % [dir_path, file_name]
			if ResourceLoader.exists(path):
				return load(path) as Texture2D
	return null
