extends Node2D
class_name MapView

@export var tile_size: int = 16

@onready var terrain: TileMap = $Terrain
@onready var cities: TileMap = $Cities
@onready var fow: TileMap = $FoW

var tileset: TileSet
var source_id: int = -1
var atlas_land := Vector2i(0, 0)
var atlas_ocean := Vector2i(1, 0)
var atlas_city := Vector2i(2, 0)
var atlas_fog := Vector2i(3, 0)
var _last_gm = null
var _units: Array = []
var _selected_index: int = -1

func _ready() -> void:
	tileset = _build_runtime_tileset()
	for tm in [terrain, cities, fow]:
		tm.tile_set = tileset
		tm.rendering_quadrant_size = 16
	print("[MapView] ready; tileset source=", source_id)

func render_map(gm, active_player: String = "", units: Array = [], selected_index: int = -1) -> void:
	terrain.clear()
	cities.clear()
	fow.clear()
	print("[MapView] render_map called")
	_last_gm = gm
	_units = units
	_selected_index = selected_index
	# Fill terrain
	for y in range(gm.height):
		for x in range(gm.width):
			var ch: String = gm.tiles[y][x]
			var coord := atlas_land if ch == "+" else atlas_ocean
			terrain.set_cell(0, Vector2i(x, y), source_id, coord)
	# Simple sanity tile
	terrain.set_cell(0, Vector2i(0, 0), source_id, atlas_land)
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
	print("[MapView] rendered tiles: ", gm.width, "x", gm.height, " cities=", gm.cities.size(), " active=", active_player)
	queue_redraw()

func _draw() -> void:
	# Visual sanity check: draw a semi-transparent green square at top-left
	draw_rect(Rect2(Vector2.ZERO, Vector2(64, 64)), Color(0.1, 0.8, 0.2, 0.4), true)
	# Debug fallback: draw first 60x40 tiles directly so we can see terrain
	if _last_gm != null:
		var max_y: int = min(_last_gm.height, 40)
		var max_x: int = min(_last_gm.width, 60)
		for y in range(max_y):
			for x in range(max_x):
				var ch: String = _last_gm.tiles[y][x]
				var col: Color = Color(0,0,0,1)
				if ch == "+":
					col = Color(0.1, 0.6, 0.2, 1.0)
				else:
					col = Color(0.1, 0.3, 0.8, 1.0)
				draw_rect(Rect2(Vector2(x * tile_size, y * tile_size), Vector2(tile_size, tile_size)), col, true)
		# Units as small squares; highlight selected
		for i in range(_units.size()):
			var u = _units[i]
			var ucol: Color
			if u.owner == "P1":
				ucol = Color(0.95, 0.95, 0.2, 1.0)
			else:
				ucol = Color(0.9, 0.2, 0.2, 1.0)
			draw_rect(Rect2(Vector2(u.x * tile_size + 3, u.y * tile_size + 3), Vector2(tile_size - 6, tile_size - 6)), ucol, true)
			if i == _selected_index:
				draw_rect(Rect2(Vector2(u.x * tile_size + 1, u.y * tile_size + 1), Vector2(tile_size - 2, tile_size - 2)), Color(1,1,1,0.8), false)

func _build_runtime_tileset() -> TileSet:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(tile_size, tile_size)
	var img := Image.create(4 * tile_size, tile_size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	# Ocean (blue)
	img.fill_rect(Rect2i(tile_size, 0, tile_size, tile_size), Color(0.1, 0.3, 0.8, 1.0))
	# Land (green)
	img.fill_rect(Rect2i(0, 0, tile_size, tile_size), Color(0.1, 0.6, 0.2, 1.0))
	# City (yellow)
	img.fill_rect(Rect2i(2 * tile_size, 0, tile_size, tile_size), Color(0.9, 0.8, 0.2, 1.0))
	# Fog (black transparent)
	img.fill_rect(Rect2i(3 * tile_size, 0, tile_size, tile_size), Color(0, 0, 0, 0.5))
	var tex := ImageTexture.create_from_image(img)
	var src := TileSetAtlasSource.new()
	src.texture = tex
	src.texture_region_size = Vector2i(tile_size, tile_size)
	source_id = ts.add_source(src)
	# Map atlas coords: (0,0)=land, (1,0)=ocean, (2,0)=city, (3,0)=fog
	return ts
