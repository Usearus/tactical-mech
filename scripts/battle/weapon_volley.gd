class_name WeaponVolley
extends RefCounted

## Visual shots for mechs that have a firing pose. Damage, dodge, and guard
## are already decided; this only draws the rounds.

const BULLET_SCENE := preload("res://scenes/battle/bullet.tscn")
const ROCKET_SCENE := preload("res://scenes/battle/rocket.tscn")

## Muzzles are frame pixels from the sprite center, facing right.
## Purple flash starts on frame 2 of the 8 fps strip. Orange's painted
## rocket is gone by frame 4, so the real one leaves the tube mouth then.
const _PURPLE_MUZZLES: Array[Vector2] = [Vector2(22, -6), Vector2(26, 1)]
const _ORANGE_MUZZLES: Array[Vector2] = [Vector2(4, -30)]


static func has_profile(art_id: String) -> bool:
	return not _profile(art_id).is_empty()


static func muzzle_delay(art_id: String) -> float:
	return float(_profile(art_id).get("delay", 0.0))


## Signed bend that lifts the midpoint above the straight shot. Screen-up is negative Y.
static func upward_bend(origin: Vector2, target: Vector2, amount: float) -> float:
	var span := target - origin
	var side := Vector2(-span.y, span.x)
	if side.y > 0.0:
		return -absf(amount)
	return absf(amount)


## flip_h mirrors the drawing without changing the node transform, so the
## muzzle offset has to be mirrored by hand.
static func mirrored_muzzle(offset: Vector2, flip_h: bool) -> Vector2:
	if flip_h:
		return Vector2(-offset.x, offset.y)
	return offset


static func muzzle_global(sprite: AnimatedSprite2D, offset: Vector2) -> Vector2:
	if sprite == null:
		return Vector2.ZERO
	return sprite.to_global(mirrored_muzzle(offset, sprite.flip_h))


## A dodge keeps traveling along the shot, past the body.
static func dodge_aim(origin: Vector2, target: Vector2, extra: float) -> Vector2:
	var dir := target - origin
	if dir.length_squared() < 0.01:
		return target + Vector2(extra, 0.0)
	return target + dir.normalized() * extra


static func aim_point(
	origin: Vector2,
	target: Vector2,
	spread: float,
	dodged: bool,
	rng: RandomNumberGenerator,
	overshoot: float,
) -> Vector2:
	if dodged:
		var lateral := 0.0
		if rng != null and spread > 0.0:
			lateral = rng.randf_range(-spread, spread)
		var side := Vector2.ZERO
		var dir := target - origin
		if dir.length_squared() > 0.01:
			side = Vector2(-dir.y, dir.x).normalized()
		return dodge_aim(origin, target, overshoot) + side * lateral
	if rng != null and spread > 0.0:
		var angle := rng.randf() * TAU
		var radius := sqrt(rng.randf()) * spread
		return target + Vector2(cos(angle), sin(angle)) * radius
	return target


## Level tracers. Each barrel keeps its own height instead of angling into one point.
static func straight_aim(origin: Vector2, target: Vector2, dodged: bool, overshoot: float) -> Vector2:
	var dx := target.x - origin.x
	if absf(dx) < 1.0:
		if dodged:
			return dodge_aim(origin, target, overshoot)
		return target
	var aim := Vector2(target.x, origin.y)
	if dodged:
		aim.x += signf(dx) * overshoot
	return aim


## centers are global points, one per target. on_arrive(index) runs once,
## when the first round fired at that target arrives.
static func play(
	shots: Node2D,
	attacker: AnimatedSprite2D,
	centers: Array[Vector2],
	dodged: Array[bool],
	art_id: String,
	on_arrive: Callable,
) -> void:
	var profile := _profile(art_id)
	if shots == null or attacker == null or profile.is_empty() or centers.is_empty():
		return
	var scene: PackedScene = profile["scene"]
	var muzzles: Array[Vector2] = []
	for point in profile["muzzles"]:
		muzzles.append(point)
	if scene == null or muzzles.is_empty():
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var count := int(profile["count"])
	var gap := float(profile["gap"])
	var flight := float(profile["flight"])
	var jitter := float(profile["jitter"])
	var spread := float(profile["spread"])
	var arc_size := float(profile["arc"])
	var overshoot := float(profile["overshoot"])
	var straight := bool(profile.get("straight", false))
	var flying: Array[BattleShot] = []
	var shot_i := 0
	for target_index in centers.size():
		var center := shots.to_local(centers[target_index])
		var missed := target_index < dodged.size() and dodged[target_index]
		for round_i in count:
			var muzzle: Vector2 = muzzles[shot_i % muzzles.size()]
			var from := shots.to_local(muzzle_global(attacker, muzzle))
			var aim := straight_aim(from, center, missed, overshoot) if straight else aim_point(from, center, spread, missed, rng, overshoot)
			var bend := 0.0
			if arc_size > 0.0:
				var lift := rng.randf_range(arc_size * 0.65, arc_size)
				bend = upward_bend(from, aim, lift)
			var seconds := maxf(flight + rng.randf_range(-jitter, jitter), 0.08)
			var delay := shot_i * gap
			var shot := scene.instantiate() as BattleShot
			shot_i += 1
			if shot == null:
				continue
			if round_i == 0 and on_arrive.is_valid():
				shot.arrived.connect(on_arrive.bind(target_index), CONNECT_ONE_SHOT)
			shot.visible = false
			shots.add_child(shot)
			flying.append(shot)
			shot.fly(from, aim, seconds, bend, delay)
	while true:
		var live := 0
		for shot in flying:
			if is_instance_valid(shot):
				live += 1
		if live == 0:
			return
		if not is_instance_valid(shots) or not shots.is_inside_tree():
			return
		await shots.get_tree().process_frame


static func _profile(art_id: String) -> Dictionary:
	match art_id:
		"purple":
			return {
				"scene": BULLET_SCENE,
				"muzzles": _PURPLE_MUZZLES,
				"count": 16,
				"gap": 0.05,
				"flight": 0.15,
				"jitter": 0.04,
				"spread": 0.0,
				"arc": 0.0,
				"overshoot": 72.0,
				"straight": true,
				"delay": 0.25,
			}
		"orange":
			return {
				"scene": ROCKET_SCENE,
				"muzzles": _ORANGE_MUZZLES,
				"count": 3,
				"gap": 0.12,
				"flight": 0.75,
				"jitter": 0.03,
				"spread": 10.0,
				"arc": 100.0,
				"overshoot": 88.0,
				"delay": 0.5,
			}
		_:
			return {}
