extends UnitBase
class_name NuclearMissile

var direction_dx: int = 0
var direction_dy: int = 0
var has_direction: bool = false
var traveled: int = 0

func _init(px: int, py: int, p_owner: String) -> void:
	max_moves = 40
	moves_left = 40
	max_hp = 1
	hp = 1
	super._init(px, py, p_owner)

func can_enter(gm: GameMap, tx: int, ty: int) -> bool:
	# Missiles can fly over any terrain
	return true


