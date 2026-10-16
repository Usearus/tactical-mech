class_name WeatherFit
extends RefCounted

## Battle copies every child of the stage's Weather node onto the board.
## Particle emitters and weather_flash polygons are refit to that view.
## The stage copies keep the size they were given in the editor.


static func layers(stage: Node) -> Array[Node]:
	var found: Array[Node] = []
	if stage == null:
		return found
	var weather := stage.get_node_or_null(StageMap.WEATHER_NODE)
	if weather == null:
		return found
	for child in weather.get_children():
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		found.append(child)
	return found


static func apply(root: Node, area: Rect2) -> void:
	if root == null or area.size.x < 1.0 or area.size.y < 1.0:
		return
	_fit(root, area)


static func _fit(node: Node, area: Rect2) -> void:
	if node is GPUParticles2D:
		_fit_particles(node as GPUParticles2D, area)
	elif node is Polygon2D and node.is_in_group("weather_flash"):
		_fit_flash(node as Polygon2D, area)
	for child in node.get_children():
		_fit(child, area)


static func _fit_particles(particles: GPUParticles2D, area: Rect2) -> void:
	var shared := particles.process_material as ParticleProcessMaterial
	if shared == null:
		return
	var mat := shared.duplicate() as ParticleProcessMaterial
	var old_span := maxf(mat.emission_box_extents.x * 2.0, 1.0)
	var half := area.size.x * 0.5 + 36.0
	var extents := mat.emission_box_extents
	extents.x = half
	mat.emission_box_extents = extents
	particles.process_material = mat
	particles.amount = maxi(1, roundi(float(particles.amount) * (half * 2.0) / old_span))
	var dir := mat.direction
	if dir.length() > 0.001:
		dir = dir.normalized()
	else:
		dir = Vector3(0, 1, 0)
	particles.position = Vector2(
		area.position.x + area.size.x * 0.5 - dir.x * area.size.x * 0.35,
		area.position.y - 8.0
	)
	particles.visibility_rect = Rect2(-half - 120.0, -48.0, half * 2.0 + 240.0, area.size.y + 220.0)
	if not particles.one_shot:
		particles.restart()


static func _fit_flash(poly: Polygon2D, area: Rect2) -> void:
	poly.position = Vector2.ZERO
	poly.rotation = 0.0
	poly.scale = Vector2.ONE
	var origin := area.position
	var end := area.end
	poly.polygon = PackedVector2Array([
		origin,
		Vector2(end.x, origin.y),
		end,
		Vector2(origin.x, end.y),
	])
