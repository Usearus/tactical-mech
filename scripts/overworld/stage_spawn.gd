@tool
class_name StageSpawn
extends Marker2D

## Slot 1 is the first mech the player picks, then 2, then 3.
## Leave this at 0 for an enemy, and assign that enemy in Mech.
## Editor stand-ins for empty player slots. The match still picks the real mechs.
const PLACEHOLDER_ART := ["purple", "red", "tan"]

@export var slot: int = 0:
	set(value):
		slot = value
		queue_redraw()
		if is_inside_tree() and Engine.is_editor_hint():
			_show_preview()

@export var mech: MechData:
	set(value):
		mech = value
		if is_inside_tree() and Engine.is_editor_hint():
			_show_preview()


func _enter_tree() -> void:
	if Engine.is_editor_hint():
		_show_preview()
		queue_redraw()
	else:
		visible = false


func cell() -> Vector2i:
	var map := get_parent() as TileMapLayer
	if map == null or map.tile_set == null or map.tile_set.tile_size.x <= 0:
		return Vector2i.ZERO
	var tile := map.tile_set.tile_size
	@warning_ignore("integer_division")
	var span := maxi(1, MechSprites.FRAME_SIZE / tile.x)
	# The marker is the sprite center. Stand on the mech cell under that sprite.
	var sample := position - Vector2(tile) * float(span - 1) * 0.5
	var tile_cell := map.local_to_map(sample)
	@warning_ignore("integer_division")
	return Vector2i(tile_cell.x / span, tile_cell.y / span)


func _draw() -> void:
	if not Engine.is_editor_hint() or slot <= 0:
		return
	var font := ThemeDB.fallback_font
	if font == null:
		return
	draw_string(font, Vector2(-8, -36), str(slot), HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color(0.4, 0.85, 1.0))


func _show_preview() -> void:
	var sprite := get_node_or_null("Preview") as Sprite2D
	if sprite == null:
		return
	var texture := _idle_texture()
	sprite.texture = texture
	sprite.visible = texture != null
	if texture == null:
		return
	var frame := mini(texture.get_width(), texture.get_height())
	sprite.region_enabled = true
	sprite.region_rect = Rect2(0, 0, frame, frame)


func _idle_texture() -> Texture2D:
	if mech != null and mech.art_id != "":
		return _art_texture(mech.art_id)
	if slot <= 0:
		return null
	var index := clampi(slot - 1, 0, PLACEHOLDER_ART.size() - 1)
	return _art_texture(PLACEHOLDER_ART[index])


func _art_texture(art_id: String) -> Texture2D:
	for folder in ["player", "enemy"]:
		var path := "res://art/mechs/%s/%s/idle.png" % [folder, art_id]
		if ResourceLoader.exists(path):
			return load(path) as Texture2D
	return null
