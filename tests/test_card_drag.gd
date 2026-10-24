@tool
extends McpTestSuite


func suite_name() -> String:
	return "card_drag"


## Same compensation as MechCard._drag_position. Scale pivots on the bottom edge.
func test_an_upward_drag_keeps_the_grab_on_the_pointer() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var slot := Control.new()
	tree.root.add_child(slot)
	track(slot)
	var card := Control.new()
	slot.add_child(card)
	card.position = Vector2(400, 500)
	card.size = Vector2(176, 268)
	card.pivot_offset = Vector2(88, 268)
	card.scale = Vector2(1.04, 1.04)
	var grab_local := Vector2(90, 36)
	var press: Vector2 = card.get_global_transform() * grab_local
	var lifted := press + Vector2(14, -96)
	var delta := lifted - press
	var next_scale := Vector2(1.04, 1.04).lerp(Vector2(1.07, 1.07), clampf(delta.length() / 160.0, 0.0, 1.0))
	var next_rot := deg_to_rad(clampf(delta.x / 22.0, -8.0, 8.0))
	var held := grab_local - card.pivot_offset
	var was := (held * card.scale).rotated(card.rotation)
	var now := (held * next_scale).rotated(next_rot)
	card.position = card.position + delta + was - now
	card.scale = next_scale
	card.rotation = next_rot
	var follow: Vector2 = card.get_global_transform() * grab_local
	assert_true(follow.distance_to(lifted) < 1.5, "card left the pointer at %s, pointer %s" % [follow, lifted])
