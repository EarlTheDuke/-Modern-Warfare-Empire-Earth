extends Node2D

@onready var map_view = $MapView
@onready var cam: Camera2D = $Camera2D
@onready var hud_label: Label = $CanvasLayer/HUD/Label
@onready var fow_mode: OptionButton = $CanvasLayer/HUD/HBox/FoWMode
@onready var btn_generate: Button = $CanvasLayer/HUD/HBox/BtnNewGame
@onready var btn_end_turn: Button = $CanvasLayer/HUD/HBox/BtnEndTurn
@onready var handoff: ColorRect = $CanvasLayer/Handoff

var gs: GameState
var awaiting_handoff: bool = false

func _ready() -> void:
	print("[Main] ready")
	# Init centralized game state
	gs = GameState
	var w := 120
	var h := 48
	gs.new_game(w, h)
	_center_camera_on_map()
	_render_all()
	# HUD setup
	fow_mode.clear()
	fow_mode.add_item("All")
	fow_mode.add_item("P1")
	fow_mode.add_item("P2")
	fow_mode.selected = 0
	fow_mode.item_selected.connect(_on_fow_mode_selected)
	btn_generate.pressed.connect(_on_generate_pressed)
	btn_end_turn.pressed.connect(_on_end_turn_pressed)
	# Camera limits: loosen to allow panning at any zoom
	cam.limit_left = -100000
	cam.limit_top = -100000
	cam.limit_right = 100000
	cam.limit_bottom = 100000
	cam.make_current()

func _generate_and_render() -> void:
	print("[Gen] generate deprecated; use GameState.new_game")
	_center_camera_on_map()
	_render_all()

func _update_hud() -> void:
	var num_cities = gs.game_map.cities.size()
	hud_label.text = "Map: %dx%d  Cities: %d  Turn: %d  Player: %s" % [gs.game_map.width, gs.game_map.height, num_cities, gs.turn_number, gs.current_player]

func _center_camera_on_map() -> void:
	if gs == null or gs.game_map == null:
		return
	var cx := float(gs.game_map.width * map_view.tile_size) * 0.5
	var cy := float(gs.game_map.height * map_view.tile_size) * 0.5
	cam.position = Vector2(cx, cy)
	cam.make_current()

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
			KEY_SPACE:
				_on_end_turn_pressed()
			# Found city with 'F' key (align with Python hotkeys)
			KEY_F:
				if gs.selected_index != -1:
					var u = gs.units[gs.selected_index]
					if gs.found_city(u):
						_render_all()
			# City production hotkeys: B set Army, R set Fighter, P cycle production
			KEY_B:
				var c = _city_under_selection()
				if c != null and c["owner"] == gs.current_player:
					if gs.set_city_production(c, "Army"):
						_update_hud()
			KEY_P:
				var c2 = _city_under_selection()
				if c2 != null and c2["owner"] == gs.current_player:
					gs.cycle_city_production(c2)
					_update_hud()
			KEY_R:
				var c3 = _city_under_selection()
				if c3 != null and c3["owner"] == gs.current_player:
					if gs.set_city_production(c3, "Fighter"):
						_update_hud()
			KEY_N:
				if gs.units.size() > 0:
					gs.selected_index = (gs.selected_index + 1) % gs.units.size()
					_render_all()
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
	print("[UI] New Game")
	# Reset state and generate a fresh map
	fow_mode.selected = 0
	gs.active_player_view = ""
	gs.new_game(gs.game_map.width if gs.game_map else 120, gs.game_map.height if gs.game_map else 48)
	_render_all()

func _on_end_turn_pressed() -> void:
	if not awaiting_handoff:
		# First press: show blackout handoff screen
		awaiting_handoff = true
		handoff.visible = true
		return
	# Second press: actually switch sides and resume
	awaiting_handoff = false
	handoff.visible = false
	gs.end_turn_and_handoff()
	_render_all()

func _handle_click(pos: Vector2) -> void:
	# Convert screen coords to world using Camera2D API (handles zoom/offset)
	var view_pos: Vector2 = cam.screen_to_world(pos)
	var tile_x := int(floor(view_pos.x / float(map_view.tile_size)))
	var tile_y := int(floor(view_pos.y / float(map_view.tile_size)))
	if tile_x < 0 or tile_y < 0 or tile_x >= gs.game_map.width or tile_y >= gs.game_map.height:
		return
	# Select first unit at tile, else move selected one tile if adjacent and land
	var clicked := gs.unit_index_at(tile_x, tile_y)
	if clicked != -1:
		# Enforce side: only select current player's units
		if gs.units[clicked].owner == gs.current_player:
			gs.selected_index = clicked
		_render_all()
		return
	if gs.selected_index != -1:
		var u = gs.units[gs.selected_index]
		if u.owner != gs.current_player:
			return
		if abs(u.x - tile_x) + abs(u.y - tile_y) == 1 and gs.game_map.tiles[tile_y][tile_x] == "+" and u.can_move():
			u.x = tile_x
			u.y = tile_y
			u.moves_left -= 1
			gs.recompute_fow_for(gs.current_player)
			_render_all()

func _try_move_selected(dx: int, dy: int) -> void:
	if gs.try_move_selected(dx, dy):
		_render_all()

func _render_all() -> void:
	map_view.render_map(gs.game_map, gs.active_player_view, gs.units, gs.selected_index)
	_update_hud()

func _city_under_selection():
	if gs.selected_index == -1:
		return null
	var u = gs.units[gs.selected_index]
	for c in gs.game_map.cities:
		if c["x"] == u.x and c["y"] == u.y:
			return c
	return null


func _spawn_initial_units() -> void:
	# handled by GameState
	pass

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

func _find_nearby_free_land(cx: int, cy: int) -> Vector2i:
	for radius in range(0, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x := cx + dx
				var y := cy + dy
				if x >= 0 and y >= 0 and x < game_map.width and y < game_map.height:
					if game_map.tiles[y][x] == "+" and _unit_index_at(x, y) == -1:
						return Vector2i(x, y)
	return _find_first_land(cx, cy)

func _select_next_owned() -> void:
	if units.size() == 0:
		selected_index = -1
		return
	for k in range(units.size()):
		selected_index = (selected_index + 1) % units.size()
		if units[selected_index].owner == current_player:
			return
	selected_index = -1

func _reset_moves_for_next_side() -> void:
	for u in units:
		if u.owner != current_player:
			u.reset_moves()

func _select_first_movable() -> void:
	for i in range(units.size()):
		if units[i].owner == current_player and units[i].can_move():
			selected_index = i
			return
	selected_index = -1

func _recompute_fow() -> void:
	game_map.clear_visible_for(current_player)
	for c in game_map.cities:
		if c["owner"] == current_player:
			game_map.mark_visible_circle(current_player, c["x"], c["y"], 5)
	for u in units:
		if u.owner == current_player:
			game_map.mark_visible_circle(current_player, u.x, u.y, 3)

func _on_fow_mode_selected(index: int) -> void:
	match index:
		0:
			gs.active_player_view = ""
		1:
			gs.active_player_view = "P1"
		2:
			gs.active_player_view = "P2"
		_:
			gs.active_player_view = ""
	_render_all()
