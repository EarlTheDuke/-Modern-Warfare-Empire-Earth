extends UnitBase
class_name Army

func _init(px: int, py: int, p_owner: String) -> void:
	max_moves = 1
	moves_left = 1
	max_hp = 10
	hp = 10
	super._init(px, py, p_owner)


