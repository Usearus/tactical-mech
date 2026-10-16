@tool
extends McpTestSuite


func suite_name() -> String:
	return "weather"


func test_stage_keeps_rain_and_lightning() -> void:
	var stage := (load("res://scenes/stage/stage1b.tscn") as PackedScene).instantiate()
	var names: Array[String] = []
	for child in WeatherFit.layers(stage):
		names.append(child.name)
	assert_true(names.has("Rain"), "rain is weather")
	assert_true(names.has("Lightning"), "lightning is weather")
	var flash := stage.get_node("Weather/Lightning/Flash") as Polygon2D
	assert_true(flash.is_in_group("weather_flash"), "the flash is marked for the board")
	stage.free()


func test_fit_covers_the_board_and_leaves_the_stage() -> void:
	var stage := (load("res://scenes/stage/stage1b.tscn") as PackedScene).instantiate()
	var rain := stage.get_node("Weather/Rain") as GPUParticles2D
	var source_box: Vector3 = (rain.process_material as ParticleProcessMaterial).emission_box_extents
	var source_amount := rain.amount
	var board := Rect2(Vector2.ZERO, Vector2(640, 448))
	var copy := rain.duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS) as GPUParticles2D
	WeatherFit.apply(copy, board)
	var fitted := copy.process_material as ParticleProcessMaterial
	assert_eq((rain.process_material as ParticleProcessMaterial).emission_box_extents, source_box, "stage rain keeps its box")
	assert_eq(rain.amount, source_amount, "stage rain keeps its count")
	assert_gt(fitted.emission_box_extents.x, 300.0, "battle rain spans the board")
	assert_true(copy.position.y < 5.0, "battle rain starts along the top")
	var storm := stage.get_node("Weather/Lightning").duplicate(Node.DUPLICATE_GROUPS | Node.DUPLICATE_SCRIPTS)
	WeatherFit.apply(storm, board)
	var flash := storm.get_node("Flash") as Polygon2D
	assert_eq(flash.polygon[2], Vector2(640, 448), "the flash fills the board")
	stage.free()
	copy.free()
	storm.free()
