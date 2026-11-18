@tool
extends McpTestSuite

const STAGES: Array[String] = [
	"res://scenes/stage/stage-tutorial.tscn",
	"res://scenes/stage/stage-0-0.tscn",
	"res://scenes/stage/stage-0-1.tscn",
	"res://scenes/stage/stage-0-2.tscn",
]

var _brief: GDScript


func suite_name() -> String:
	return "mission_preview"


func setup() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/briefing/mission_brief.gd")
	_brief = GDScript.new()
	_brief.source_code = source
	var err := _brief.reload()
	assert_eq(err, OK, "mission brief compiles")


func test_preview_keeps_tiles_and_drops_units_and_weather() -> void:
	for path in STAGES:
		var stage := (load(path) as PackedScene).instantiate()
		track(stage)
		var had_weather := stage.get_node_or_null(StageMap.WEATHER_NODE) != null
		_brief.strip_map_preview(stage)
		assert_eq(stage.get_node_or_null(StageMap.WEATHER_NODE), null, "%s drops weather" % path)
		assert_eq(_marker_count(stage), 0, "%s drops placed mechs" % path)
		assert_true(stage.get_node_or_null("Ground") is TileMapLayer, "%s keeps the ground" % path)
		if had_weather:
			assert_true(stage.get_node_or_null("Shadows") is Node, "%s keeps the shadows" % path)
		var bounds: Rect2 = _brief.tile_bounds(stage)
		assert_gt(bounds.size.x, 32.0, "%s has tile width" % path)
		assert_gt(bounds.size.y, 32.0, "%s has tile height" % path)


func test_brief_scene_has_the_preview() -> void:
	var packed := ResourceLoader.load(
		"res://scenes/briefing/mission_brief.tscn", "", ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	var brief := packed.instantiate()
	track(brief)
	var view := brief.get_node_or_null("Briefing/Window/Margin/Column/ArtClip/StageView")
	assert_eq(brief.get_node_or_null("Margin/Root/MapPanel/Inset/Clip/StageView"), null, "the city map stays a photo")
	assert_eq(brief.get_node_or_null("Briefing/Window/Margin/Column/ArtClip/Alley"), null, "the alley art is gone")
	assert_true(view is SubViewportContainer, "the preview fills the briefing art")
	assert_true(view.get_node_or_null("StageViewport") is SubViewport, "the stage draws in a viewport")
	assert_true(view.get_node_or_null("StageViewport/StageCamera") is Camera2D, "a camera frames the tiles")
	assert_true(view.get_node_or_null("StageViewport/StageHost") is Node2D, "the stage has a host")


func test_cover_frame_crops_the_long_side() -> void:
	var frame: Dictionary = _brief.cover_frame(Vector2(400, 400), Rect2(Vector2.ZERO, Vector2(1000, 500)))
	assert_true(is_equal_approx(frame.zoom, 0.8), "the short side fills the view")
	assert_eq(frame.center, Vector2(500, 250), "the camera sits on the map")


func _marker_count(node: Node) -> int:
	var count := 0
	for child in node.get_children():
		if child is Marker2D:
			count += 1
		else:
			count += _marker_count(child)
	return count
