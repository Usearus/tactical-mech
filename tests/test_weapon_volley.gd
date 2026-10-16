extends McpTestSuite


func suite_name() -> String:
	return "weapon_volley"


func test_flipped_sprite_mirrors_the_muzzle() -> void:
	var sprite := AnimatedSprite2D.new()
	track(sprite)
	var offset := Vector2(22, -6)
	sprite.flip_h = false
	assert_eq(
		WeaponVolley.mirrored_muzzle(offset, sprite.flip_h),
		offset,
		"a right-facing gun keeps its muzzle",
	)
	sprite.flip_h = true
	assert_eq(
		WeaponVolley.mirrored_muzzle(offset, sprite.flip_h),
		Vector2(-22, -6),
		"a left-facing gun mirrors the muzzle",
	)


func test_dodge_aim_sits_past_the_target() -> void:
	var origin := Vector2(0, 40)
	var target := Vector2(90, 40)
	var aim: Vector2 = WeaponVolley.aim_point(origin, target, 12.0, true, null, 48.0)
	assert_eq(aim, Vector2(138, 40), "a dodge shot continues along the same line")
	assert_gt(origin.distance_to(aim), origin.distance_to(target), "the shot lands past the body")


func test_straight_shots_keep_each_barrel_height() -> void:
	var target := Vector2(200, 80)
	var upper := WeaponVolley.straight_aim(Vector2(10, 40), target, false, 72.0)
	var lower := WeaponVolley.straight_aim(Vector2(14, 52), target, false, 72.0)
	assert_eq(upper, Vector2(200, 40), "the upper gun stays level")
	assert_eq(lower, Vector2(200, 52), "the lower gun stays level")
	var past := WeaponVolley.straight_aim(Vector2(10, 40), target, true, 72.0)
	assert_eq(past, Vector2(272, 40), "a dodge keeps going straight past the target")
