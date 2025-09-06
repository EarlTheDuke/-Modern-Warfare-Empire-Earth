extends RefCounted
class_name UnitBase

var x: int
var y: int
var owner: String

var max_moves: int = 1
var moves_left: int = 1

var max_hp: int = 10
var hp: int = 10

func _init(px: int, py: int, p_owner: String) -> void:
	x = px
	y = py
	owner = p_owner
	moves_left = max_moves

func is_alive() -> bool:
	return hp > 0

func can_move() -> bool:
	return is_alive() and moves_left > 0

func reset_moves() -> void:
	moves_left = max_moves

func can_enter(gm: GameMap, tx: int, ty: int) -> bool:
	# Default: land-only
	return gm.tiles[ty][tx] == GameMap.LAND


