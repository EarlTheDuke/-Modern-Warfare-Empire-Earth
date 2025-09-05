extends RefCounted
class_name UnitData

var x: int
var y: int
var owner: String
var max_moves: int = 1
var moves_left: int = 1

func _init(px: int, py: int, p_owner: String) -> void:
	x = px
	y = py
	owner = p_owner
	moves_left = max_moves

func can_move() -> bool:
	return moves_left > 0

func reset_moves() -> void:
	moves_left = max_moves
