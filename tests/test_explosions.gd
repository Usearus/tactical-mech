extends McpTestSuite


func suite_name() -> String:
	return "explosions"


func test_explosion_sheets_slice_into_square_frames() -> void:
	var mini := MechSprites.explosion_frames("mini")
	var small := MechSprites.explosion_frames("small")
	var medium := MechSprites.explosion_frames("medium")
	assert_ne(mini, null, "mini sheet loads")
	assert_ne(small, null, "small sheet loads")
	assert_ne(medium, null, "medium sheet loads")
	assert_eq(mini.get_frame_count("burst"), 11, "mini is eleven frames")
	assert_eq(small.get_frame_count("burst"), 7, "small is seven frames")
	assert_eq(medium.get_frame_count("burst"), 11, "medium is eleven frames")
	assert_eq(mini.get_frame_texture("burst", 0).get_width(), 16, "mini frames are 16 pixels")
	assert_eq(small.get_frame_texture("burst", 0).get_width(), 32, "small frames are 32 pixels")
	assert_eq(medium.get_frame_texture("burst", 0).get_width(), 64, "medium frames are 64 pixels")
	assert_false(mini.get_animation_loop("burst"), "a blast plays once")
