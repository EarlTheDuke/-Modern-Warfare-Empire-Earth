extends Node2D
class_name MapView

@export var tile_size: int = 32

@onready var terrain: TileMap = $Terrain
@onready var cities: TileMap = $Cities
@onready var fow: TileMap = $FoW

var tileset: TileSet
var source_id: int = -1
var atlas_land := Vector2i(0, 0)
var atlas_ocean := Vector2i(1, 0)
var atlas_city := Vector2i(2, 0)
var atlas_fog := Vector2i(3, 0)

func _ready() -> void:
	tileset = _build_runtime_tileset()
	for tm in [terrain, cities, fow]:
		tm.tile_set = tileset
		tm.tile_set.tile_size = Vector2i(tile_size, tile_size)
		tm.rendering_quadrant_size = 16

func render_map(gm: GameMap, active_player: String = "") -> void:
	terrain.clear()
	cities.clear()
	fow.clear()
	# Fill terrain
	for y in range(gm.height):
		for x in range(gm.width):
			var ch: String = gm.tiles[y][x]
			var coord := atlas_land if ch == GameMap.LAND else atlas_ocean
			terrain.set_cell(0, Vector2i(x, y), source_id, coord)
	# Cities
	for c in gm.cities:
		var cx: int = c["x"]
		var cy: int = c["y"]
		cities.set_cell(0, Vector2i(cx, cy), source_id, atlas_city)
	# FoW: if active player provided, hide unexplored/unknown
	if active_player != "" and gm.explored.has(active_player) and gm.visible.has(active_player):
		for y in range(gm.height):
			for x in range(gm.width):
				if not gm.explored[active_player][y][x]:
					fow.set_cell(0, Vector2i(x, y), source_id, atlas_fog)
				elif not gm.visible[active_player][y][x]:
					fow.set_cell(0, Vector2i(x, y), source_id, atlas_fog)

func _build_runtime_tileset() -> TileSet:
	var ts := TileSet.new()
	var img := Image.create(4 * 16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Ocean (blue)
	img.fill_rect(Rect2i(16, 0, 16, 16), Color(0.1, 0.3, 0.8, 1.0))
	# Land (green)
	img.fill_rect(Rect2i(0, 0, 16, 16), Color(0.1, 0.6, 0.2, 1.0))
	# City (yellow)
	img.fill_rect(Rect2i(32, 0, 16, 16), Color(0.9, 0.8, 0.2, 1.0))
	# Fog (black transparent)
	img.fill_rect(Rect2i(48, 0, 16, 16), Color(0, 0, 0, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(16, 16)
	source_id = ts.add_source(src)
	# Map atlas coords: (0,0)=land, (1,0)=ocean, (2,0)=city, (3,0)=fog
	return ts
