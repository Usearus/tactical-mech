class_name PowerUp
extends Node2D

## Overdrive aura. Port of Sprite Fusion's power-up effect (MIT, Hugo Duprez, 2026).
## After the opening burst, the outline holds until release(), then fades.

const PX := 2
const BURST := 0.32
const HOLD := 1.75
const FADE := 2.35
const END := 2.95
const PULSE1 := 0.87
const PULSE2 := 1.32
const HOLD_AT := 1.55
const SIZE := 0.8
const BW := 64
const BH := 76
const FRAME_W := 192
const FRAME_H := 192
const OX := -96
const OY := -96
## The outline holds for the whole Overdrive, so it does not need a fresh picture every frame.
const PAINT_STEP := 1.0 / 30.0
const MOTE_CAP := 180
const IN := 0
const DUST := 1
const STREAK := 2
const STAR := 3
const WISP := 4
const C0 := 0xFFFFFFFF
const C1 := 0xFFFFFCE0
const C2 := 0xFFFFF08F
const C3 := 0xFFFFD03F
const C4 := 0xFFE69022
const C5 := 0xFFAB4F1F
const DUSTC := 0xFF825E6A
const WHITE := 0xFFFFFFFF
const BAYER: Array[int] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

var _sustain := true
var _t := 0.0
var _burst := false
var _rng := 1
var _streak_bank := 0.0
var _wisp_bank := 0.0
var _mask_key := ""
var _feet := Vector2.ZERO
var _bx0 := 0
var _by0 := 0
var _mid_y := 0.0
var _cells: Dictionary = {}
var _mask := PackedInt32Array()
var _dist := PackedInt32Array()
var _ring_x := PackedInt32Array()
var _ring_y := PackedInt32Array()
var _ring_d := PackedFloat32Array()
var _since_paint := 0.0
var _bytes := PackedByteArray()
var _back_image: Image
var _front_image: Image
var _motes: Array = []

@onready var _back: Sprite2D = $Back
@onready var _front: Sprite2D = $Front


func _init() -> void:
	_rng = (randi() & 0xFFFFFFFF) | 1


func _ready() -> void:
	_bytes.resize(FRAME_W * FRAME_H * 4)
	_bytes.fill(0)
	_back_image = Image.create_from_data(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8, _bytes)
	_front_image = Image.create_from_data(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8, _bytes)
	_back.texture = ImageTexture.create_from_image(_back_image)
	_front.texture = ImageTexture.create_from_image(_front_image)
	_back.centered = true
	_front.centered = true
	_back.scale = Vector2(PX, PX)
	_front.scale = Vector2(PX, PX)
	_mask.resize(BW * BH)
	_dist.resize(BW * BH)


## Keep the aura on this sprite and cancel a fade if Overdrive is still on.
func attach(host: AnimatedSprite2D) -> void:
	if host == null:
		return
	_resume()
	if get_parent() != host:
		if is_inside_tree():
			reparent(host, false)
		else:
			host.add_child(self)
	position = Vector2.ZERO
	scale = Vector2.ONE


## Stay in the held outline without moving back onto a hidden cell sprite.
func hold() -> void:
	_resume()


## Play the fade. The node frees itself when the motes are gone.
func release() -> void:
	if not _sustain:
		return
	_sustain = false
	if _t > HOLD:
		_t = HOLD


func _resume() -> void:
	if not _sustain and _t >= HOLD:
		_t = HOLD_AT
	_sustain = true


func _process(delta: float) -> void:
	var host := get_parent() as AnimatedSprite2D
	if host == null or not is_instance_valid(host):
		queue_free()
		return
	var dt := minf(delta, 0.05)
	if is_visible_in_tree():
		_sync_silhouette(host)
	_step(dt)
	if is_visible_in_tree() and _back.texture != null:
		_since_paint += dt
		# The opening burst is short. After that, 30 pictures a second is enough.
		if _t < BURST + 0.45 or _since_paint >= PAINT_STEP:
			_since_paint = 0.0
			_paint(false)
			_paint(true)
	if not _sustain and _t > END and _motes.is_empty():
		queue_free()


func _sync_silhouette(host: AnimatedSprite2D) -> void:
	var frames := host.sprite_frames
	if frames == null or host.animation == "" or not frames.has_animation(host.animation):
		return
	if host.frame < 0 or host.frame >= frames.get_frame_count(host.animation):
		return
	var key := "%s|%s|%s|%s|%s" % [frames.get_instance_id(), host.animation, host.frame, host.flip_h, host.offset]
	if key == _mask_key:
		return
	var tex := frames.get_frame_texture(host.animation, host.frame)
	if tex == null:
		return
	var image := tex.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	_mask_key = key
	_cells.clear()
	var width := image.get_width()
	var height := image.get_height()
	for ty in height:
		for tx in width:
			var sample := image.get_pixel(tx, ty)
			if sample.a < 0.5:
				continue
			var px := tx
			if host.flip_h:
				px = width - 1 - tx
			var local_x := float(px) + 0.5 - float(width) * 0.5 + host.offset.x
			var local_y := float(ty) + 0.5 - float(height) * 0.5 + host.offset.y
			var cell := Vector2i(floori(local_x / float(PX)), floori(local_y / float(PX)))
			_cells[cell] = _pack_color(sample)
	_place_window()
	_build_mask()
	_build_field()


func _place_window() -> void:
	if _cells.is_empty():
		_feet = Vector2(0, 16)
	else:
		var bottom := -999999
		var sum_x := 0
		var count := 0
		for key in _cells:
			var point: Vector2i = key
			if point.y > bottom:
				bottom = point.y
				sum_x = point.x
				count = 1
			elif point.y == bottom:
				sum_x += point.x
				count += 1
		_feet = Vector2(float(sum_x) / float(count) + 0.5, float(bottom + 1))
	var cx := roundi(_feet.x)
	var cy := roundi(_feet.y)
	_bx0 = cx - BW / 2
	_by0 = cy - BH + 6
	_mid_y = float(cy - 22)


func _build_mask() -> void:
	_mask.fill(0)
	var any := false
	if not _cells.is_empty():
		for y in BH:
			for x in BW:
				if _cells.has(Vector2i(_bx0 + x, _by0 + y)):
					_mask[y * BW + x] = 1
					any = true
	if any:
		return
	var cx := roundi(_feet.x)
	var cy := roundi(_feet.y)
	for y in BH:
		for x in BW:
			var px := float(_bx0 + x) + 0.5 - float(cx)
			var py := float(_by0 + y) + 0.5 - float(cy)
			var head := Vector2(px, py + 38.0).length() < 4.5
			var trunk := absf(px) < 2.2 and py > -34.0 and py < -14.0
			var legs := py >= -14.0 and py < 0.0 and absf(absf(px) - (py + 14.0) * 0.28) < 1.4
			if head or trunk or legs:
				_mask[y * BW + x] = 1


func _build_field() -> void:
	for i in _mask.size():
		_dist[i] = 0 if _mask[i] != 0 else 255
	for y in BH:
		for x in BW:
			var i := y * BW + x
			if x > 0:
				_relax(i, i - 1, 3)
			if y > 0:
				_relax(i, i - BW, 3)
				if x > 0:
					_relax(i, i - BW - 1, 4)
				if x < BW - 1:
					_relax(i, i - BW + 1, 4)
	for y in range(BH - 1, -1, -1):
		for x in range(BW - 1, -1, -1):
			var i := y * BW + x
			if x < BW - 1:
				_relax(i, i + 1, 3)
			if y < BH - 1:
				_relax(i, i + BW, 3)
				if x < BW - 1:
					_relax(i, i + BW + 1, 4)
				if x > 0:
					_relax(i, i + BW - 1, 4)
	_collect_ring()


func _collect_ring() -> void:
	_ring_x.resize(0)
	_ring_y.resize(0)
	_ring_d.resize(0)
	for y in BH:
		for x in BW:
			var raw := _dist[y * BW + x]
			if raw == 0 or raw > 72:
				continue
			_ring_x.append(_bx0 + x)
			_ring_y.append(_by0 + y)
			_ring_d.append(float(raw) / 3.0)


func _relax(i: int, j: int, weight: int) -> void:
	if j < 0 or j >= _dist.size():
		return
	var next := _dist[j] + weight
	if next < _dist[i]:
		_dist[i] = mini(255, next)


func _step(dt: float) -> void:
	_t += dt
	var aura := _aura()
	var flare := _flare()
	var ccx := _feet.x
	var ccy := _mid_y
	if _t < BURST:
		for _i in int(round(3.0 * SIZE)):
			var angle := _rng_range(0.0, TAU)
			var radius := _rng_range(34.0, 64.0) * sqrt(SIZE)
			var speed := _rng_range(260.0, 420.0)
			var life := (radius * float(PX)) / speed
			_mote(IN, ccx + cos(angle) * radius, ccy + sin(angle) * radius * 0.8, -cos(angle) * speed, -sin(angle) * speed * 0.8, life, life, C1 if _rng_chance(0.3) else C2, 1.0, true)
	if not _burst and _t >= BURST:
		_burst = true
		for _i in int(round(18.0 * SIZE)):
			var side := float(_rng_sign())
			var life := _rng_range(0.45, 0.8)
			_mote(DUST, ccx + side * _rng_range(2.0, 10.0), _feet.y - _rng_range(0.0, 3.0), side * _rng_range(60.0, 170.0), -_rng_range(2.0, 16.0), life, 0.8, _mix(DUSTC, C4, 0.25), _rng_range(1.5, 3.0), false)
		for _i in int(round(22.0 * SIZE)):
			var spot := _on_body()
			var life := _rng_range(0.6, 1.3)
			var star_size := 2.0 if _rng_chance(0.35) else (1.0 if _rng_chance(0.5) else 0.0)
			_mote(STAR, spot.x, spot.y, _rng_range(-40.0, 40.0), -_rng_range(30.0, 110.0), life, 1.3, _pick_top(), star_size, _rng_chance(0.6))
	if _burst and aura > 0.05:
		_streak_bank += (5.0 + 5.0 * flare) * aura * SIZE * dt * 10.0
		var streak_count := int(_streak_bank)
		_streak_bank -= float(streak_count)
		for _n in streak_count:
			var spot_x := _on_body().x
			var side := float(_rng_sign())
			var life := _rng_range(0.14, 0.3)
			_mote(STREAK, spot_x + side * _rng_range(5.0, 16.0) * sqrt(SIZE), ccy + _rng_range(-16.0, 26.0), 0.0, -_rng_range(220.0, 420.0), life, 0.3, C2 if _rng_chance(0.5) else C1, _rng_range(6.0, 16.0), _rng_chance(0.5))
		_wisp_bank += 9.0 * aura * SIZE * dt
		var wisp_count := int(_wisp_bank)
		_wisp_bank -= float(wisp_count)
		for _n in wisp_count:
			var spot := _on_body()
			var up := _clamp01((_mid_y - spot.y) / 16.0)
			if _rng_chance(1.0 - up * 0.8):
				continue
			var life := _rng_range(0.3, 0.55)
			_mote(WISP, spot.x + _rng_range(-4.0, 4.0), spot.y - _rng_range(6.0, 12.0) * SIZE, _rng_range(-15.0, 15.0), -_rng_range(70.0, 130.0), life, 0.55, C2, _rng_range(1.4, 2.4) * sqrt(SIZE), false)
		if _rng_chance(0.5 * aura):
			var spot := _on_body()
			var life := _rng_range(0.6, 1.1)
			var star_size := 1.0 if _rng_chance(0.25) else 0.0
			_mote(STAR, spot.x + _rng_range(-8.0, 8.0), spot.y, _rng_range(-10.0, 10.0), -_rng_range(25.0, 70.0), life, 1.1, _pick_top(), star_size, _rng_chance(0.5))
	for i in range(_motes.size() - 1, -1, -1):
		var mote: Dictionary = _motes[i]
		var life := float(mote["life"]) - dt
		if life <= 0.0:
			_motes.remove_at(i)
			continue
		mote["life"] = life
		var drag := 3.5 if int(mote["k"]) == DUST else (1.4 if int(mote["k"]) == STAR else 0.0)
		var vx := float(mote["vx"])
		var vy := float(mote["vy"])
		vx -= vx * drag * dt
		vy -= vy * drag * dt
		if int(mote["k"]) == STAR:
			vy -= 18.0 * dt
		mote["vx"] = vx
		mote["vy"] = vy
		mote["x"] = float(mote["x"]) + (vx * dt) / float(PX)
		mote["y"] = float(mote["y"]) + (vy * dt) / float(PX)


func _paint(front: bool) -> void:
	_bytes.fill(0)
	if not front:
		_paint_back()
		_upload(_back_image, _back.texture as ImageTexture)
		return
	_paint_front()
	_upload(_front_image, _front.texture as ImageTexture)


func _upload(image: Image, texture: ImageTexture) -> void:
	image.set_data(FRAME_W, FRAME_H, false, Image.FORMAT_RGBA8, _bytes.duplicate())
	texture.update(image)


func _paint_back() -> void:
	for mote in _motes:
		if int(mote["k"]) != DUST:
			continue
		var life := float(mote["life"]) / float(mote["max"])
		_alpha_disc(float(mote["x"]), float(mote["y"]), float(mote["s"]) * (1.6 - life * 0.6), int(mote["c"]), life * 0.6)
	var aura := _aura()
	var flare := _flare()
	if aura > 0.02:
		var scroll := int(_t * 34.0)
		for i in _ring_x.size():
			var px := _ring_x[i]
			var py := _ring_y[i]
			var dist := _ring_d[i]
			var n := _hash(px * 13 + (py + scroll) * 7)
			var up := _clamp01((_mid_y - float(py)) / 16.0)
			var reach := aura * SIZE * (3.4 + 14.0 * n * (0.3 + 1.15 * up)) * (1.0 + 0.3 * flare)
			if dist > reach:
				continue
			var band := dist / reach
			if band < 0.22:
				_put(px, py, C0 if flare > 0.35 and band < 0.14 else C1)
			elif band < 0.45:
				_put(px, py, C2)
			elif band < 0.7:
				_put(px, py, C3)
			elif _bayer(px, py) < (1.0 - band) * 2.6:
				_put(px, py, C4 if band < 0.86 else C5)
	for mote in _motes:
		if not bool(mote["front"]):
			_draw_mote(mote)


func _paint_front() -> void:
	if _burst:
		_shock(_feet.x, _feet.y, _t - BURST, 0.45 * SIZE)
	var flash := 0.0
	if _burst:
		flash = maxf(
			exp(-pow((_t - BURST) / 0.07, 2.0)),
			maxf(exp(-pow((_t - PULSE1) / 0.07, 2.0)), exp(-pow((_t - PULSE2) / 0.07, 2.0)))
		)
	if flash > 0.03:
		if not _cells.is_empty():
			for key in _cells:
				var point: Vector2i = key
				_dot(float(point.x), float(point.y), _flash_color(_lum(int(_cells[key])), flash), flash * 1.2)
		else:
			for i in _mask.size():
				if _mask[i] == 0:
					continue
				_dot(float(_bx0 + (i % BW)), float(_by0 + int(i / BW)), _flash_color(0.6, flash), flash * 1.2)
	for mote in _motes:
		if bool(mote["front"]):
			_draw_mote(mote)


func _draw_mote(mote: Dictionary) -> void:
	var kind := int(mote["k"])
	var x := float(mote["x"])
	var y := float(mote["y"])
	var life := float(mote["life"]) / float(mote["max"])
	var color := int(mote["c"])
	if kind == IN:
		var vx := float(mote["vx"])
		var vy := float(mote["vy"])
		var speed := sqrt(vx * vx + vy * vy)
		if speed < 0.001:
			speed = 1.0
		var ux := vx / speed
		var uy := vy / speed
		_line(x - ux * 7.0, y - uy * 7.0, x - ux * 3.0, y - uy * 3.0, color)
		_line(x - ux * 2.5, y - uy * 2.5, x, y, WHITE)
	elif kind == STREAK:
		var length := float(mote["s"]) * (0.5 + 0.5 * life)
		var steps := int(floor(length))
		for j in range(0, steps + 1):
			var along := float(j)
			var alpha := 1.0 if along < length * 0.5 else (1.0 - along / (length + 1.0)) * 1.6
			_dot(x, y + along, WHITE if along < 1.5 else color, alpha)
		_glow(x, y + length * 0.3, 4.0, color, 0.3 * life)
	elif kind == WISP:
		var radius := float(mote["s"]) * (0.35 + 0.65 * life)
		_disc(x, y, radius + 0.7, color if life > 0.5 else _scale_color(color, 0.7))
		if life > 0.35:
			_disc(x - 0.3, y - 0.4, radius * 0.55, WHITE if life > 0.7 else color)
		_glow(x, y, 5.0 + radius * 2.0, color, 0.3 * life)
	elif kind == STAR:
		var px := int(floor(x))
		var py := int(floor(y))
		var twinkle := 0.6 + 0.4 * sin(float(mote["life"]) * 26.0 + x)
		if twinkle * life < 0.2:
			return
		var arm := int(round(float(mote["s"]) * twinkle * minf(1.0, life * 2.5)))
		for d in range(1, arm + 1):
			var arm_color := _scale_color(color, 0.75) if d == arm and arm > 1 else color
			_put(px + d, py, arm_color)
			_put(px - d, py, arm_color)
			_put(px, py + d, arm_color)
			_put(px, py - d, arm_color)
		_put(px, py, WHITE if twinkle > 0.75 else color)
		_glow(x, y, 3.0 + float(arm) * 2.0, color, 0.45 * life * twinkle)


func _shock(cx: float, fy: float, time: float, scale: float) -> void:
	var radius := 72.0 * scale
	var q := time / 0.55
	if q < 0.0 or q >= 1.8:
		return
	if q < 0.5:
		var span := maxi(int(round(14.0 * scale)), 1)
		for dx in range(-span, span + 1):
			var across := absf(float(dx)) / (14.0 * scale)
			var alpha := (1.0 - q / 0.5) * (1.0 - across) * 2.2
			_dot(cx + float(dx), fy, C0 if across < 0.3 else (C1 if across < 0.6 else C2), alpha)
			_dot(cx + float(dx), fy - 1.0, C1 if across < 0.4 else C2, alpha * 0.7)
			_dot(cx + float(dx), fy + 1.0, C2, alpha * 0.5)
	var reach := 4.0 + radius * _out_expo(minf(1.0, q))
	var after := 1.0 - _clamp01((q - 0.25) / 1.4)
	var flicker := int(floor(time * 20.0))
	var reach_i := int(round(reach))
	for dx in range(-reach_i, reach_i + 1):
		var across := 0.0 if reach <= 0.0 else absf(float(dx)) / reach
		var spark := _hash(int(round(cx + float(dx))) * 7 + flicker * 613) < 0.04 * after
		_dot(cx + float(dx), fy, C0 if spark else (C2 if across < 0.5 else C3), 1.0 if spark else after * 0.8 * (1.0 - across * 0.5))
		_dot(cx + float(dx), fy - 1.0, C3, after * 0.3 * (1.0 - across))
	if q < 1.0:
		var head := 4.0 + radius * _out_expo(q)
		var length := (6.0 + 22.0 * (1.0 - q)) * scale
		var crest := 6.0 * scale * pow(1.0 - q, 0.7)
		for side in [-1, 1]:
			var sd := float(side)
			for j in int(floor(length)):
				var x := cx + sd * (head - float(j))
				var alpha := (1.0 - float(j) / length) * (1.0 - q) * 2.2
				var lift := int(round(crest * maxf(0.0, 1.0 - float(j) / (length * 0.5))))
				var color := C3
				if j < 2:
					color = C0
				elif float(j) < length * 0.35:
					color = C1
				elif float(j) < length * 0.7:
					color = C2
				_dot(x, fy, color, alpha)
				for r in range(1, lift + 1):
					var tip := j < 2 and float(r) > float(lift) - 2.0
					var crest_color := C0 if tip else (C1 if r == lift else C2)
					_dot(x, fy - float(r), crest_color, alpha * (1.0 - float(r) / (float(lift) + 2.0)) * 1.4)
			for r in int(floor(crest + 3.0)):
				_dot(cx + sd * head, fy - float(r), C0, (1.0 - q) * 1.6 * (1.0 - float(r) / (crest + 3.0)))
			_glow(cx + sd * head, fy - 3.0, 12.0 * scale, C2, 0.8 * (1.0 - q))
		_glow(cx, fy, reach, C3, 0.25 * (1.0 - q))
	for i in int(round(24.0 * scale)):
		var born := _hash(i, 1) * 0.32
		var age := time - born
		var life := 0.3 + _hash(i, 4) * 0.3
		if age < 0.0 or age > life:
			continue
		var sd := 1.0 if i % 2 != 0 else -1.0
		var x := cx + sd * (4.0 + radius * _out_expo(born / 0.55)) + sd * (15.0 + _hash(i, 2) * 70.0) * age
		var y := fy - 1.0 - ((60.0 + _hash(i, 3) * 90.0) * age - 110.0 * age * age)
		var fade := 1.0 - age / life
		if y > fy - 1.0:
			continue
		_dot(x, y, C0 if age < life * 0.3 else C1, 1.4 * fade)
		if _hash(i, 5) < 0.4 and fade > 0.4:
			_dot(x + 1.0, y, C2, fade * 1.2)
			_dot(x - 1.0, y, C2, fade * 1.2)
			_dot(x, y + 1.0, C2, fade * 1.2)
			_dot(x, y - 1.0, C2, fade * 1.2)
		_glow(x, y, 4.0, C2, 0.45 * fade)


func _mote(kind: int, x: float, y: float, vx: float, vy: float, life: float, max_life: float, color: int, size: float, front: bool) -> void:
	if _motes.size() >= MOTE_CAP:
		return
	_motes.append({
		"k": kind,
		"x": x,
		"y": y,
		"vx": vx,
		"vy": vy,
		"life": life,
		"max": max_life,
		"c": color,
		"s": size,
		"front": front,
	})


func _on_body() -> Vector2:
	if _mask.is_empty():
		return Vector2(float(_bx0) + float(BW) * 0.5, _mid_y)
	for _n in 40:
		var x := _rng_int(0, BW - 1)
		var y := _rng_int(0, BH - 1)
		if _mask[y * BW + x] != 0:
			return Vector2(float(_bx0 + x) + 0.5, float(_by0 + y) + 0.5)
	return Vector2(float(_bx0) + float(BW) * 0.5, _mid_y)


func _aura() -> float:
	var env := minf(_t, HOLD_AT) if _sustain else _t
	return _smooth(BURST - 0.04, BURST + 0.12, env) * (1.0 - _smooth(HOLD, FADE, env)) * (0.85 + 0.15 * sin(_t * 13.0))


func _flare() -> float:
	return maxf(exp(-pow((_t - PULSE1) / 0.07, 2.0)), exp(-pow((_t - PULSE2) / 0.07, 2.0))) + exp(-pow((_t - BURST) / 0.08, 2.0))


func _flash_color(luma: float, amount: float) -> int:
	if luma > 0.5:
		return C0 if amount > 0.75 else C1
	if luma > 0.22:
		return C2
	return C4


func _at(x: float, y: float) -> int:
	var ix := int(x - float(OX))
	var iy := int(y - float(OY))
	if ix < 0 or iy < 0 or ix >= FRAME_W or iy >= FRAME_H:
		return -1
	return iy * FRAME_W + ix


func _put(x: float, y: float, color: int) -> void:
	var i := _at(x, y)
	if i < 0:
		return
	var o := i * 4
	_bytes[o] = color & 255
	_bytes[o + 1] = (color >> 8) & 255
	_bytes[o + 2] = (color >> 16) & 255
	_bytes[o + 3] = (color >> 24) & 255


func _blend(x: float, y: float, color: int, amount: float) -> void:
	if amount <= 0.01:
		return
	var i := _at(x, y)
	if i < 0:
		return
	var o := i * 4
	var a := minf(amount, 1.0)
	var dest_a := float(_bytes[o + 3]) / 255.0
	var out_a := a + dest_a * (1.0 - a)
	if out_a <= 0.0:
		return
	var keep := a / out_a
	var hold := 1.0 - keep
	_bytes[o] = clampi(int(float(color & 255) * keep + float(_bytes[o]) * hold), 0, 255)
	_bytes[o + 1] = clampi(int(float((color >> 8) & 255) * keep + float(_bytes[o + 1]) * hold), 0, 255)
	_bytes[o + 2] = clampi(int(float((color >> 16) & 255) * keep + float(_bytes[o + 2]) * hold), 0, 255)
	_bytes[o + 3] = clampi(int(out_a * 255.0), 0, 255)


func _disc(cx: float, cy: float, radius: float, color: int) -> void:
	if radius <= 0.5:
		_put(round(cx), round(cy), color)
		return
	var r2 := radius * radius
	for y in range(int(floor(cy - radius)), int(ceil(cy + radius)) + 1):
		var dy := float(y) + 0.5 - cy
		for x in range(int(floor(cx - radius)), int(ceil(cx + radius)) + 1):
			var dx := float(x) + 0.5 - cx
			if dx * dx + dy * dy <= r2:
				_put(x, y, color)


func _alpha_disc(cx: float, cy: float, radius: float, color: int, amount: float) -> void:
	if amount <= 0.01 or radius <= 0.0:
		return
	var r2 := radius * radius
	for y in range(int(floor(cy - radius)), int(ceil(cy + radius)) + 1):
		var dy := float(y) + 0.5 - cy
		for x in range(int(floor(cx - radius)), int(ceil(cx + radius)) + 1):
			var dx := float(x) + 0.5 - cx
			if dx * dx + dy * dy <= r2:
				_blend(x, y, color, amount)


func _line(x0: float, y0: float, x1: float, y1: float, color: int) -> void:
	var ix0 := int(round(x0))
	var iy0 := int(round(y0))
	var ix1 := int(round(x1))
	var iy1 := int(round(y1))
	var dx := absi(ix1 - ix0)
	var dy := -absi(iy1 - iy0)
	var sx := 1 if ix0 < ix1 else -1
	var sy := 1 if iy0 < iy1 else -1
	var err := dx + dy
	for _n in 4096:
		_put(ix0, iy0, color)
		if ix0 == ix1 and iy0 == iy1:
			return
		var doubled := err * 2
		if doubled >= dy:
			err += dy
			ix0 += sx
		if doubled <= dx:
			err += dx
			iy0 += sy


## Hard pixels instead of a soft disc. Wide blooms were most of the battle cost.
func _glow(cx: float, cy: float, radius: float, color: int, amount: float) -> void:
	if radius < 1.0 or amount <= 0.04:
		return
	if radius > 8.0:
		radius = 8.0
	var x0 := maxi(OX, int(floor(cx - radius)))
	var x1 := mini(OX + FRAME_W - 1, int(ceil(cx + radius)))
	var y0 := maxi(OY, int(floor(cy - radius)))
	var y1 := mini(OY + FRAME_H - 1, int(ceil(cy + radius)))
	var reach2 := radius * radius
	for y in range(y0, y1 + 1):
		var dy := float(y) + 0.5 - cy
		for x in range(x0, x1 + 1):
			var dx := float(x) + 0.5 - cx
			var dist := (dx * dx + dy * dy) / reach2
			if dist >= 1.0:
				continue
			if amount * (1.0 - dist) > _bayer(x, y):
				_put(x, y, color)


func _dot(x: float, y: float, color: int, amount: float = 1.0) -> void:
	var px := int(floor(x))
	var py := int(floor(y))
	if amount >= 1.0 or amount > _bayer(px, py):
		_put(px, py, color)


func _bayer(x: int, y: int) -> float:
	var index := ((y & 3) << 2) | (x & 3)
	return (float(BAYER[index]) + 0.5) / 16.0


func _pack_color(sample: Color) -> int:
	return (255 << 24) | (int(sample.b * 255.0) << 16) | (int(sample.g * 255.0) << 8) | int(sample.r * 255.0)


func _lum(color: int) -> float:
	return (float(color & 255) * 0.3 + float((color >> 8) & 255) * 0.59 + float((color >> 16) & 255) * 0.11) / 255.0


func _mix(first: int, second: int, amount: float) -> int:
	var keep := 1.0 - amount
	var r := int(float(first & 255) * keep + float(second & 255) * amount)
	var g := int(float((first >> 8) & 255) * keep + float((second >> 8) & 255) * amount)
	var b := int(float((first >> 16) & 255) * keep + float((second >> 16) & 255) * amount)
	var a := int(float((first >> 24) & 255) * keep + float((second >> 24) & 255) * amount)
	return (a << 24) | (b << 16) | (g << 8) | r


func _scale_color(color: int, amount: float) -> int:
	var r := mini(255, int(float(color & 255) * amount))
	var g := mini(255, int(float((color >> 8) & 255) * amount))
	var b := mini(255, int(float((color >> 16) & 255) * amount))
	return ((color >> 24) & 255) << 24 | (b << 16) | (g << 8) | r


func _pick_top() -> int:
	var roll := _rng_int(0, 2)
	if roll == 0:
		return C0
	if roll == 1:
		return C1
	return C2


func _clamp01(value: float) -> float:
	return clampf(value, 0.0, 1.0)


func _smooth(edge0: float, edge1: float, value: float) -> float:
	var t := _clamp01((value - edge0) / (edge1 - edge0))
	return t * t * (3.0 - 2.0 * t)


func _out_expo(value: float) -> float:
	if value >= 1.0:
		return 1.0
	return 1.0 - pow(2.0, -10.0 * _clamp01(value))


func _hash(n: int, salt: int = 0) -> float:
	var mixed := _imul(n + 1 + salt * 7919, 2654435761)
	return float(mixed % 100000) / 100000.0


func _imul(a: int, b: int) -> int:
	var left := a & 0xFFFFFFFF
	var right := b & 0xFFFFFFFF
	if left >= 0x80000000:
		left -= 0x100000000
	if right >= 0x80000000:
		right -= 0x100000000
	return (left * right) & 0xFFFFFFFF


func _rng_next() -> float:
	_rng = (_rng + 0x6D2B79F5) & 0xFFFFFFFF
	var t := _rng
	t = _imul(t ^ (t >> 15), t | 1)
	t = (t ^ (t + _imul(t ^ (t >> 7), t | 61))) & 0xFFFFFFFF
	t = (t ^ (t >> 14)) & 0xFFFFFFFF
	return float(t) / 4294967296.0


func _rng_range(a: float, b: float) -> float:
	return a + (b - a) * _rng_next()


func _rng_int(a: int, b: int) -> int:
	return int(floor(_rng_range(float(a), float(b + 1))))


func _rng_sign() -> int:
	return -1 if _rng_next() < 0.5 else 1


func _rng_chance(odds: float) -> bool:
	return _rng_next() < odds
