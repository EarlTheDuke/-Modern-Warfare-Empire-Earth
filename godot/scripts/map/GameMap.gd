extends RefCounted
class_name GameMap

# Terrain constants, match Python symbols
const OCEAN := "."
const LAND := "+"

# City structure: {x:int, y:int, owner:String|Nil, production_type:String|Nil, production_progress:int, production_cost:int, support_cap:int}
var width: int
var height: int
var tiles: Array = []              # 2D Array[String]
var cities: Array = []             # Array[Dictionary]
var explored := {}                 # player -> 2D Array[bool]
var visible := {}                  # player -> 2D Array[bool]

func _init(w: int, h: int) -> void:
	width = w
	height = h
	tiles = []
	for y in range(h):
		var row: Array = []
		for x in range(w):
			row.append(OCEAN)
		tiles.append(row)
	cities = []
	explored = {}
	visible = {}

func generate(rng_seed: int = 0, land_target: float = 0.55) -> void:
	var rng := RandomNumberGenerator.new()
	if rng_seed != 0:
		rng.seed = rng_seed
	# Noise seed
	var noise: Array = [] # 2D Array[float]
	for y in range(height):
		var row: Array = []
		for x in range(width):
			row.append(rng.randf())
		noise.append(row)
	# Cellular smoothing passes (inline neighbor counting)
	for _i in range(4):
		var new_noise: Array = []
		for y in range(height):
			var row := []
			for x in range(width):
				row.append(noise[y][x])
			new_noise.append(row)
		for y in range(height):
			for x in range(width):
				var n := 0
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						if dy == 0 and dx == 0:
							continue
						var ny := y + dy
						var nx := x + dx
						if ny >= 0 and ny < height and nx >= 0 and nx < width:
							if noise[ny][nx] > 0.5:
								n += 1
				if n >= 5:
					new_noise[y][x] = min(1.0, noise[y][x] + 0.2)
				elif n <= 3:
					new_noise[y][x] = max(0.0, noise[y][x] - 0.2)
		noise = new_noise
	# Threshold by target land ratio
	var flat: Array = []
	for y in range(height):
		for x in range(width):
			flat.append(noise[y][x])
	flat.sort()
	var idx: int = int((1.0 - land_target) * flat.size())
	idx = clampi(idx, 0, maxi(0, flat.size() - 1))
	var threshold: float = float(flat[idx])
	for y in range(height):
		for x in range(width):
			tiles[y][x] = LAND if noise[y][x] >= threshold else OCEAN
	# Clean up and ensure connectivity
	for _p in range(2):
		_smooth_terrain()
	_ensure_connected_land()

func _smooth_terrain() -> void:
	for y in range(height):
		for x in range(width):
			var land := 0
			var water := 0
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					if dy == 0 and dx == 0:
						continue
					var ny := y + dy
					var nx := x + dx
					if ny >= 0 and ny < height and nx >= 0 and nx < width:
						if tiles[ny][nx] == LAND:
							land += 1
						else:
							water += 1
			if land >= 5:
				tiles[y][x] = LAND
			elif water >= 5:
				tiles[y][x] = OCEAN

func _ensure_connected_land() -> void:
	var visited := []
	for _y in range(height):
		visited.append([])
		for _x in range(width):
			visited[_y].append(false)
	var components: Array = [] # Array[Array[Vector2i]]
	for y in range(height):
		for x in range(width):
			if not visited[y][x] and tiles[y][x] == LAND:
				components.append(_bfs_component(y, x, visited))
	if components.size() <= 1:
		return
	# pick largest component
	var main_comp: Array = components[0]
	for comp in components:
		if comp.size() > main_comp.size():
			main_comp = comp
	var main_rep: Vector2i = main_comp[0]
	for i in range(1, components.size()):
		var c: Array = components[i]
		var rep: Vector2i = c[0]
		_carve_path(rep.x, rep.y, main_rep.x, main_rep.y)

func _bfs_component(start_y: int, start_x: int, visited) -> Array:
	var q: Array = [Vector2i(start_x, start_y)]
	visited[start_y][start_x] = true
	var comp: Array = [Vector2i(start_x, start_y)]
	while q.size() > 0:
		var v: Vector2i = q.pop_front()
		var cy: int = v.y
		var cx: int = v.x
		for d in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var ny: int = cy + d.y
			var nx: int = cx + d.x
			if ny >= 0 and ny < height and nx >= 0 and nx < width and not visited[ny][nx]:
				if tiles[ny][nx] == LAND:
					visited[ny][nx] = true
					q.append(Vector2i(nx, ny))
					comp.append(Vector2i(nx, ny))
	return comp

func _carve_path(x0: int, y0: int, x1: int, y1: int) -> void:
	var x := x0
	var y := y0
	while x != x1:
		tiles[y][x] = LAND
		x += 1 if x1 > x else -1
	while y != y1:
		tiles[y][x] = LAND
		y += 1 if y1 > y else -1
	tiles[y][x] = LAND

func place_cities(count: int = 20, min_separation: int = 3) -> void:
	cities.clear()
	var land_positions: Array = []
	for y in range(height):
		for x in range(width):
			if tiles[y][x] == LAND:
				land_positions.append(Vector2i(x, y))
	land_positions.shuffle()
	var placed: Array = []
	for v in land_positions:
		if cities.size() >= count:
			break
		var ok := true
		for p in placed:
			if abs(p.x - v.x) + abs(p.y - v.y) < min_separation:
				ok = false
				break
		if ok:
			cities.append({
				"x": v.x,
				"y": v.y,
				"owner": null,
				"production_type": null,
				"production_progress": 0,
				"production_cost": 0,
				"support_cap": 2,
			})
			placed.append(v)

func init_fow(players: Array) -> void:
	explored.clear()
	visible.clear()
	for p in players:
		var e := []
		var v := []
		for y in range(height):
			var er := []
			var vr := []
			for x in range(width):
				er.append(false)
				vr.append(false)
			e.append(er)
			v.append(vr)
		explored[p] = e
		visible[p] = v

func clear_visible_for(player: String) -> void:
	if not visible.has(player):
		return
	var v = visible[player]
	for y in range(height):
		for x in range(width):
			v[y][x] = false

func mark_visible_circle(player: String, x: int, y: int, radius: int) -> void:
	if not visible.has(player) or not explored.has(player):
		return
	var r2 := radius * radius
	for yy in range(max(0, y - radius), min(height, y + radius + 1)):
		for xx in range(max(0, x - radius), min(width, x + radius + 1)):
			var dx := xx - x
			var dy := yy - y
			if dx * dx + dy * dy <= r2:
				visible[player][yy][xx] = true
				explored[player][yy][xx] = true
