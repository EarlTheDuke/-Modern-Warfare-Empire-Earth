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
			KEY_N:
				if units.size() > 0:
					selected_index = (selected_index + 1) % units.size()
					map_view.render_map(game_map, active_player_view, units, selected_index)
			# Numpad movement for selected unit (8/2/4/6 and diagonals 7/9/1/3)
			KEY_KP_8:
				_try_move_selected(0, -1)
			KEY_KP_2:
				_try_move_selected(0, 1)
			KEY_KP_4:
				_try_move_selected(-1, 0)
			KEY_KP_6:
				_try_move_selected(1, 0)
			KEY_KP_7:
				_try_move_selected(-1, -1)
			KEY_KP_9:
				_try_move_selected(1, -1)
			KEY_KP_1:
				_try_move_selected(-1, 1)
			KEY_KP_3:
				_try_move_selected(1, 1)
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
	# Convert screen coords to world using Camera2D API (handles zoom/offset)
	var view_pos: Vector2 = cam.screen_to_world(pos)
	var tile_x := int(floor(view_pos.x / float(map_view.tile_size)))
	var tile_y := int(floor(view_pos.y / float(map_view.tile_size)))
	if tile_x < 0 or tile_y < 0 or tile_x >= game_map.width or tile_y >= game_map.height:
		return
	# Select first unit at tile, else move selected one tile if adjacent and land
	var clicked := _unit_index_at(tile_x, tile_y)
	if clicked != -1:
		selected_index = clicked
		map_view.render_map(game_map, active_player_view, units, selected_index)
		return
	if selected_index != -1:
		var u = units[selected_index]
		if abs(u.x - tile_x) + abs(u.y - tile_y) == 1 and game_map.tiles[tile_y][tile_x] == "+" and u.can_move():
			u.x = tile_x
			u.y = tile_y
			u.moves_left -= 1
			map_view.render_map(game_map, active_player_view, units, selected_index)

func _try_move_selected(dx: int, dy: int) -> void:
	if selected_index < 0 or selected_index >= units.size():
		return
	var u = units[selected_index]
	if not u.can_move():
		return
	var nx := u.x + dx
	var ny := u.y + dy
	if nx < 0 or ny < 0 or nx >= game_map.width or ny >= game_map.height:
		return
	if game_map.tiles[ny][nx] != "+":
		return
	# Prevent stepping onto another unit for now
	if _unit_index_at(nx, ny) != -1:
		return
	u.x = nx
	u.y = ny
	u.moves_left -= 1
	map_view.render_map(game_map, active_player_view, units, selected_index)

func _unit_index_at(tx: int, ty: int) -> int:
	for i in range(units.size()):
		var u = units[i]
		if u.x == tx and u.y == ty:
			return i
	return -1


func _spawn_initial_units() -> void:
	var p1 := "P1"
	var p2 := "P2"
	var u1_pos := _find_first_land(1, 1)
	var u2_pos := _find_first_land(3, 1)
	var u1 := UnitData.new(u1_pos.x, u1_pos.y, p1)
	var u2 := UnitData.new(u2_pos.x, u2_pos.y, p2)
	un1_reset(u1)
	un1_reset(u2)
	units.append(u1)
	units.append(u2)
	selected_index = 0
	map_view.render_map(game_map, active_player_view, units, selected_index)

func un1_reset(u) -> void:
	u.reset_moves()

func _find_first_land(start_x: int, start_y: int) -> Vector2i:
	for radius in range(0, 10):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x := start_x + dx
				var y := start_y + dy
				if x >= 0 and y >= 0 and x < game_map.width and y < game_map.height:
					if game_map.tiles[y][x] == "+":
						return Vector2i(x, y)
	return Vector2i(clamp(start_x, 0, game_map.width - 1), clamp(start_y, 0, game_map.height - 1))

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
