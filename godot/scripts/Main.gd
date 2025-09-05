extends Node2D

@onready var map_view: MapView = $MapView
@onready var cam: Camera2D = $Camera2D
@onready var hud_label: Label = $CanvasLayer/HUD/Label
@onready var fow_mode: OptionButton = $CanvasLayer/HUD/HBox/FoWMode
@onready var btn_generate: Button = $CanvasLayer/HUD/HBox/BtnGenerate

var game_map
var active_player_view: String = ""
var generation_count: int = 0

func _ready() -> void:
	# Build a map similar to Python MVP
	var w := 120
	var h := 48
	game_map = GameMap.new(w, h)
	_generate_and_render()
	# HUD setup
	fow_mode.clear()
	fow_mode.add_item("All")
	fow_mode.add_item("P1")
	fow_mode.add_item("P2")
	fow_mode.selected = 0
	fow_mode.item_selected.connect(_on_fow_mode_selected)
	btn_generate.pressed.connect(_on_generate_pressed)
	# Camera limits
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = w * map_view.tile_size
	cam.limit_bottom = h * map_view.tile_size
	cam.make_current()

func _generate_and_render() -> void:
	print("[Gen] generating...")
	game_map.generate(0, 0.55)
	game_map.place_cities(12, 3)
	game_map.init_fow(["P1", "P2"]) # seed FoW containers
	# For now show entire map; FoW per-player can be toggled via dropdown
	map_view.render_map(game_map, active_player_view)
	generation_count += 1
	# Center camera on map
	var cx := float(game_map.width * map_view.tile_size) * 0.5
	var cy := float(game_map.height * map_view.tile_size) * 0.5
	cam.position = Vector2(cx, cy)
	cam.make_current()
	_update_hud()
	print("[Gen] done. cities=", game_map.cities.size(), " gen=", generation_count)

func _update_hud() -> void:
	var num_cities = game_map.cities.size()
	hud_label.text = "Map: %dx%d  Cities: %d  Gen: %d" % [game_map.width, game_map.height, num_cities, generation_count]

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

func _on_generate_pressed() -> void:
	print("[UI] Generate Map clicked")
	# Reset to All view to ensure map is visible after regeneration
	active_player_view = ""
	fow_mode.selected = 0
	_generate_and_render()

func _on_fow_mode_selected(index: int) -> void:
	match index:
		0:
			active_player_view = ""
		1:
			active_player_view = "P1"
		2:
			active_player_view = "P2"
		_:
			active_player_view = ""
	map_view.render_map(game_map, active_player_view)
