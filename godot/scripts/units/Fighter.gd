extends UnitBase
class_name Fighter

func _init(px: int, py: int, p_owner: String) -> void:
	max_moves = 12
	moves_left = 12
	max_hp = 8
	hp = 8
	super._init(px, py, p_owner)

func can_enter(_gm: GameMap, _tx: int, _ty: int) -> bool:
	# Fighters can fly over any terrain and land on any tile
	return true


