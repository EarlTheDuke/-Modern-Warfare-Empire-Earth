extends Node2D

@onready var map_view: MapView = $MapView
@onready var cam: Camera2D = $Camera2D
@onready var hud_label: Label = $CanvasLayer/HUD/Label

var game_map: GameMap

func _ready() -> void:
	# Build a map similar to Python MVP
	var w := 120
	var h := 48
	game_map = GameMap.new(w, h)
	game_map.generate(0, 0.55)
	game_map.place_cities(12, 3)
	game_map.init_fow(["P1", "P2"]) # seed FoW
	# Seed visibility around all cities (as in Python)
	for c in game_map.cities:
		if c["owner"] != null:
			game_map.mark_visible_circle(str(c["owner"]), c["x"], c["y"], 5)
	map_view.render_map(game_map, "")
	_update_hud()
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = w * map_view.tile_size
	cam.limit_bottom = h * map_view.tile_size

func _update_hud() -> void:
	var num_cities := game_map.cities.size()
	hud_label.text = "Map: %dx%d  Cities: %d" % [game_map.width, game_map.height, num_cities]

var dragging := false
var last_mouse := Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE:
			dragging = mb.pressed
			last_mouse = mb.position
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			cam.zoom *= Vector2(0.9, 0.9)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			cam.zoom *= Vector2(1.1, 1.1)
	elif event is InputEventMouseMotion and dragging:
		var mm := event as InputEventMouseMotion
		var delta := (mm.position - last_mouse) * cam.zoom
		cam.position -= delta
		last_mouse = mm.position
