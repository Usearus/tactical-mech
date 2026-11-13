@tool
extends McpTestSuite

## Which tutorial presses reach the board. The coach eats the rest.

const _coach := preload("res://scripts/ui/tutorial_coach.gd")


func suite_name() -> String:
	return "tutorial_spotlight"


func test_a_press_in_the_hole_passes_and_one_outside_does_not() -> void:
	var holes: Array[Rect2] = _coach.lesson_holes(false, Rect2(10, 10, 20, 20), true, Rect2(), Rect2())
	assert_true(_coach.pointer_passes(true, Vector2(20, 20), holes, false, false), "the outlined control accepts the press")
	assert_false(_coach.pointer_passes(true, Vector2(0, 0), holes, false, false), "a press outside the hole is eaten")


func test_continue_steps_ignore_the_outlined_control() -> void:
	var outline := Rect2(100, 100, 40, 40)
	var cont := Rect2(400, 300, 140, 48)
	var holes: Array[Rect2] = _coach.lesson_holes(true, outline, true, cont, Rect2())
	assert_false(_coach.pointer_passes(true, outline.get_center(), holes, false, false), "the outline is only a pointer")
	assert_true(_coach.pointer_passes(true, cont.get_center(), holes, false, false), "Continue accepts the press")


func test_a_drag_that_starts_inside_can_finish_outside() -> void:
	var holes: Array[Rect2] = _coach.lesson_holes(false, Rect2(10, 10, 20, 20), true, Rect2(), Rect2())
	assert_true(_coach.pointer_passes(false, Vector2(0, 0), holes, false, true), "the release follows a press that started in the hole")
	assert_false(_coach.pointer_passes(false, Vector2(20, 20), holes, false, false), "a release with no gesture is eaten")


func test_an_open_menu_lets_presses_through() -> void:
	var holes: Array[Rect2] = _coach.lesson_holes(false, Rect2(10, 10, 20, 20), true, Rect2(), Rect2())
	assert_true(_coach.pointer_passes(true, Vector2(0, 0), holes, true, false), "the pause menu is above the lock")


func test_the_menu_corner_stays_clickable() -> void:
	var menu := Rect2(700, 8, 124, 56)
	var holes: Array[Rect2] = _coach.lesson_holes(false, Rect2(10, 10, 20, 20), true, Rect2(), menu)
	assert_true(_coach.pointer_passes(true, menu.get_center(), holes, false, false), "Help and Menu stay available")


func test_an_aim_step_includes_the_sprite() -> void:
	var button := Rect2(0, 0, 32, 32)
	var sprite := Rect2(-10, -40, 52, 80)
	var aimed: Rect2 = _coach.aim_bounds(button, sprite, true)
	assert_true(aimed.has_point(Vector2(-5, -20)), "the mech art belongs to the tile")
	assert_false(_coach.aim_bounds(button, sprite, false).has_point(Vector2(-5, -20)), "other steps stay on the button")


func test_an_above_step_sits_over_the_highlight() -> void:
	var hole := Rect2(400, 300, 80, 24)
	var box := Vector2(340, 90)
	var spot: Vector2 = _coach.callout_spot(hole, box, Vector2(1280, 720), true)
	assert_true(spot.y + box.y <= hole.position.y, "the callout stays above the highlight")
	assert_true(absf(spot.x + box.x * 0.5 - hole.get_center().x) < 2.0, "the callout is centered on the highlight")
	var beside: Vector2 = _coach.callout_spot(hole, box, Vector2(1280, 720), false)
	assert_true(beside.x >= hole.end.x, "other steps stay beside the highlight")


func test_a_bottom_step_sits_on_the_lower_edge() -> void:
	var box := Vector2(340, 90)
	var view := Vector2(1280, 720)
	var spot: Vector2 = _coach.center_spot(box, view, true)
	assert_eq(spot.y, view.y - box.y - 12.0)
	assert_true(absf(spot.x + box.x * 0.5 - view.x * 0.5) < 2.0, "the callout stays centered")
	var middle: Vector2 = _coach.center_spot(box, view, false)
	assert_true(middle.y < spot.y, "other continue steps stay in the middle")


func test_a_spanning_step_covers_both_contacts() -> void:
	var extras: Array[Rect2] = [Rect2(64, 0, 32, 32)]
	var frame: Rect2 = _coach.span_bounds(Rect2(0, 0, 32, 32), extras)
	assert_true(frame.has_point(Vector2(8, 8)), "the first contact stays inside the frame")
	assert_true(frame.has_point(Vector2(80, 8)), "the second contact stays inside the frame")
	assert_eq(frame.size, Vector2(96, 32))
