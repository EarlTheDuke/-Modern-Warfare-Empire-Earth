extends Node
class_name SaveLoad

static func save_to_path(gs: GameState, path: String) -> bool:
	var payload := {
		"map": {
			"width": gs.game_map.width,
			"height": gs.game_map.height,
			"tiles": gs.game_map.tiles,
			"cities": gs.game_map.cities,
			"explored": gs.game_map.explored,
			"visible": gs.game_map.visible,
		},
		"players": gs.players,
		"current_player": gs.current_player,
		"turn_number": gs.turn_number,
		"units": _serialize_units(gs.units),
	}
	var json := JSON.stringify(payload)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(json)
	return true

static func load_from_path(gs: GameState, path: String) -> bool:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return false
	var txt := f.get_as_text()
	var pr := JSON.parse_string(txt)
	if typeof(pr) != TYPE_DICTIONARY:
		return false
	var data: Dictionary = pr
	# Rehydrate map
	var m := data.get("map", {})
	var w := int(m.get("width", 60))
	var h := int(m.get("height", 24))
	gs.game_map = GameMap.new(w, h)
	gs.game_map.tiles = m.get("tiles", [])
	gs.game_map.cities = m.get("cities", [])
	gs.game_map.explored = m.get("explored", {})
	gs.game_map.visible = m.get("visible", {})
	# Players and turn
	gs.players = m.get("players", gs.players) if data.has("players") else gs.players
	gs.current_player = data.get("current_player", "P1")
	gs.turn_number = int(data.get("turn_number", 1))
	# Units
	gs.units.clear()
	for ud in data.get("units", []):
		var u := _deserialize_unit(ud)
		if u != null:
			gs.units.append(u)
	# Selection & FoW
	gs.selected_index = -1
	gs.recompute_fow_for(gs.current_player)
	return true

static func _serialize_units(units: Array) -> Array:
	var out: Array = []
	for u in units:
		var d := {
			"class": u.get_class(),
			"x": u.x,
			"y": u.y,
			"owner": u.owner,
			"max_hp": u.max_hp,
			"hp": u.hp,
			"max_moves": u.max_moves,
			"moves_left": u.moves_left,
			"home_city": {"x": u.home_city.x, "y": u.home_city.y} if u.has_method("get") == false else {"x": u.home_city.x, "y": u.home_city.y},
		}
		out.append(d)
	return out

static func _deserialize_unit(d: Dictionary):
	var klass := String(d.get("class", "Army"))
	var x := int(d.get("x", 0))
	var y := int(d.get("y", 0))
	var owner := String(d.get("owner", "P1"))
	var u
	match klass:
		"Army":
			u = Army.new(x, y, owner)
		"Fighter":
			u = Fighter.new(x, y, owner)
		"Carrier":
			u = Carrier.new(x, y, owner)
		"NuclearMissile":
			u = NuclearMissile.new(x, y, owner)
		_:
			u = Army.new(x, y, owner)
	u.max_hp = int(d.get("max_hp", u.max_hp))
	u.hp = int(d.get("hp", u.hp))
	u.max_moves = int(d.get("max_moves", u.max_moves))
	u.moves_left = int(d.get("moves_left", u.moves_left))
	var hc := d.get("home_city", null)
	if typeof(hc) == TYPE_DICTIONARY:
		u.home_city = Vector2i(int(hc.get("x", -1)), int(hc.get("y", -1)))
	return u


