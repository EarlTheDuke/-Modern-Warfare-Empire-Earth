extends Node2D

@onready var map_view = $MapView
@onready var cam: Camera2D = $Camera2D
@onready var hud_label: Label = $CanvasLayer/HUD/Label
@onready var fow_mode: OptionButton = $CanvasLayer/HUD/HBox/FoWMode
@onready var btn_generate: Button = $CanvasLayer/HUD/HBox/BtnGenerate

var game_map
var active_player_view: String = ""
var generation_count: int = 0
var units: Array = []
var selected_index: int = -1

func _ready() -> void:
	print("[Main] ready")
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
	# Camera limits: loosen to allow panning at any zoom
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.make_current()

func _generate_and_render() -> void:
	print("[Gen] generating...")
	game_map.generate(0, 0.55)
	game_map.place_cities(12, 3)
	game_map.init_fow(["P1", "P2"]) # seed FoW containers
	# For now show entire map; FoW per-player can be toggled via dropdown
	map_view.render_map(game_map, active_player_view, units, selected_index)
	generation_count += 1
	# Center camera on map
	var cx := float(game_map.width * map_view.tile_size) * 0.5
	var cy := float(game_map.height * map_view.tile_size) * 0.5
	cam.position = Vector2(cx, cy)
	cam.make_current()
	_update_hud()
	print("[Gen] done. cities=", game_map.cities.size(), " gen=", generation_count)
	# Spawn two armies if none
	if units.is_empty():
		_spawn_initial_units()
	map_view.queue_redraw()

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
		elif mb.button_index == MOUSE_BUTTON_RIGHT:
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
	elif event is InputEventKey and event.pressed:
		var step := 32.0
		var ie := event as InputEventKey
		match ie.keycode:
			KEY_A, KEY_LEFT:
				cam.position.x -= step
			KEY_D, KEY_RIGHT:
				cam.position.x += step
			KEY_W, KEY_UP:
				cam.position.y -= step
			KEY_S, KEY_DOWN:
				cam.position.y += step
			KEY_R:
				_on_generate_pressed()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var mb2 := event as InputEventMouseButton
		_handle_click(mb2.position)

func _on_generate_pressed() -> void:
	print("[UI] Generate Map clicked")
	# Reset to All view to ensure map is visible after regeneration
	active_player_view = ""
	fow_mode.selected = 0
	_generate_and_render()
	# Force trigger MapView draw in case TileMap batching delays visuals
	map_view.queue_redraw()

func _handle_click(pos: Vector2) -> void:
	var view_pos := pos + (cam.position - get_viewport_rect().size * 0.5) * Vector2(1,1)
	var tile_x := int(floor(view_pos.x / float(map_view.tile_size)))
	var tile_y := int(floor(view_pos.y / float(map_view.tile_size)))
	if tile_x < 0 or tile_y < 0 or tile_x >= game_map.width or tile_y >= game_map.height:
		return
	# Select first unit at tile, else move selected one tile if adjacent and land
	var clicked := _unit_index_at(tile_x, tile_y)
	if clicked != -1:
		selected_index = clicked
		return
	if selected_index != -1:
		var u = units[selected_index]
		if abs(u.x - tile_x) + abs(u.y - tile_y) == 1 and game_map.tiles[tile_y][tile_x] == "+" and u.can_move():
			u.x = tile_x
			u.y = tile_y
			u.moves_left -= 1
			map_view.queue_redraw()

func _unit_index_at(tx: int, ty: int) -> int:
	for i in range(units.size()):
		var u = units[i]
		if u.x == tx and u.y == ty:
			return i
	return -1

func _spawn_initial_units() -> void:
	var p1 := "P1"
	var p2 := "P2"
	var u1 := UnitData.new(1, 1, p1)
	var u2 := UnitData.new(3, 1, p2)
	un1_reset(u1)
	un1_reset(u2)
	units.append(u1)
	units.append(u2)

func un1_reset(u) -> void:
	u.reset_moves()

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
	map_view.render_map(game_map, active_player_view, units, selected_index)
