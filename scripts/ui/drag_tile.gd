class_name DragTile
extends RefCounted


## Godot pins a drag preview's top-left to the cursor. A plain parent keeps the tile's center on the pointer.
static func center_on_cursor(tile: Control) -> Control:
	var tile_size := tile.size
	if tile_size.x < 1.0 or tile_size.y < 1.0:
		tile_size = tile.custom_minimum_size
	tile.size = tile_size
	tile.position = -tile_size * 0.5
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var anchor := Control.new()
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor.add_child(tile)
	return anchor
