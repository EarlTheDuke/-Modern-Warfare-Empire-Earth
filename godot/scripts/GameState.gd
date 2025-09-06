extends Node
class_name GameState

# Centralized game state and core helpers for Godot version

@onready var rng := RandomNumberGenerator.new()

# Map and players
var game_map: GameMap
var players: Array[String] = ["P1", "P2"]
var current_player: String = "P1"
var turn_number: int = 1

# Units and selection
var units: Array = [] # Array[UnitBase]
var selected_index: int = -1

# Fog-of-war toggle for HUD ("", "P1", "P2")
var active_player_view: String = ""

func _ready() -> void:
    rng.randomize()

func new_game(width: int, height: int) -> void:
    game_map = GameMap.new(width, height)
    game_map.generate(0, 0.55)
    game_map.place_cities(12, 3)
    game_map.init_fow(players)
    current_player = players[0]
    turn_number = 1
    units.clear()
    selected_index = -1
    _spawn_initial_units()
    recompute_fow_for(current_player)

func _spawn_initial_units() -> void:
    if game_map.cities.size() < 2:
        return
    var best_a := 0
    var best_b := 1
    var best_d := -1
    for i in range(game_map.cities.size()):
        for j in range(i + 1, game_map.cities.size()):
            var a = game_map.cities[i]
            var b = game_map.cities[j]
            var dx = a["x"] - b["x"]
            var dy = a["y"] - b["y"]
            var d = dx * dx + dy * dy
            if d > best_d:
                best_d = d
                best_a = i
                best_b = j
    game_map.cities[best_a]["owner"] = players[0]
    game_map.cities[best_b]["owner"] = players[1]
    var a_pos := Vector2i(game_map.cities[best_a]["x"], game_map.cities[best_a]["y"])
    var b_pos := Vector2i(game_map.cities[best_b]["x"], game_map.cities[best_b]["y"])
    var u1p := _find_nearby_free_land(a_pos.x, a_pos.y)
    var u2p := _find_nearby_free_land(b_pos.x, b_pos.y)
    var u1 := Army.new(u1p.x, u1p.y, players[0])
    var u2 := Army.new(u2p.x, u2p.y, players[1])
    u1.reset_moves()
    u2.reset_moves()
    units.append(u1)
    units.append(u2)
    selected_index = 0

func _find_nearby_free_land(cx: int, cy: int) -> Vector2i:
    for radius in range(0, 8):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                var x := cx + dx
                var y := cy + dy
                if x >= 0 and y >= 0 and x < game_map.width and y < game_map.height:
                    if game_map.tiles[y][x] == GameMap.LAND and unit_index_at(x, y) == -1:
                        return Vector2i(x, y)
    return Vector2i(cx, cy)

func unit_index_at(tx: int, ty: int) -> int:
    for i in range(units.size()):
        var u: UnitBase = units[i]
        if u.x == tx and u.y == ty and u.is_alive():
            return i
    return -1

func try_move_selected(dx: int, dy: int) -> bool:
    if selected_index < 0 or selected_index >= units.size():
        return false
    var u: UnitBase = units[selected_index]
    if u.owner != current_player or not u.can_move():
        return false
    return try_move_unit(u, dx, dy)

func try_move_unit(u: UnitBase, dx: int, dy: int) -> bool:
    var nx: int = u.x + dx
    var ny: int = u.y + dy
    if nx < 0 or ny < 0 or nx >= game_map.width or ny >= game_map.height:
        return false
    # Terrain constraint: basic parity for Army only for now
    if not u.can_enter(game_map, nx, ny):
        return false
    # Prevent stepping onto another unit (combat later)
    if unit_index_at(nx, ny) != -1:
        return false
    u.x = nx
    u.y = ny
    u.moves_left -= 1
    recompute_fow_for(current_player)
    return true

func end_turn_and_handoff() -> void:
    # Production, basing, victory checks will be added later
    var idx := players.find(current_player)
    if idx == -1:
        idx = 0
    current_player = players[(idx + 1) % players.size()]
    turn_number += 1
    # Reset moves for next side
    for u: UnitBase in units:
        if u.owner == current_player:
            u.reset_moves()
    _select_first_movable()
    recompute_fow_for(current_player)

func _select_first_movable() -> void:
    for i in range(units.size()):
        var u: UnitBase = units[i]
        if u.owner == current_player and u.can_move():
            selected_index = i
            return
    selected_index = -1

func recompute_fow_for(owner: String) -> void:
    if game_map == null:
        return
    game_map.clear_visible_for(owner)
    for c in game_map.cities:
        if c["owner"] == owner:
            game_map.mark_visible_circle(owner, c["x"], c["y"], 5)
    for u: UnitBase in units:
        if u.owner == owner and u.is_alive():
            game_map.mark_visible_circle(owner, u.x, u.y, 3)


