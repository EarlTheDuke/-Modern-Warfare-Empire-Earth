extends Node2D

var width: int = 60
var height: int = 40
var tile: int = 16
var tiles: Array = []

func _ready() -> void:
	_randomize_map()
	queue_redraw()

func _randomize_map() -> void:
	tiles.clear()
	var rng = RandomNumberGenerator.new()
	rng.randomize()
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(rng.randf() > 0.5)
		tiles.append(row)

func _draw() -> void:
	for y in range(height):
		for x in range(width):
			var land: bool = bool(tiles[y][x])
			var col: Color
			if land:
				col = Color(0.1,0.6,0.2,1.0)
			else:
				col = Color(0.1,0.3,0.8,1.0)
			draw_rect(Rect2(Vector2(x * tile, y * tile), Vector2(tile, tile)), col, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			_randomize_map()
			queue_redraw()
