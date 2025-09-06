extends UnitBase
class_name Carrier

func _init(px: int, py: int, p_owner: String) -> void:
	max_moves = 3
	moves_left = 3
	max_hp = 16
	hp = 16
	super._init(px, py, p_owner)

func can_enter(gm: GameMap, tx: int, ty: int) -> bool:
	# Carrier must stay on ocean
	return gm.tiles[ty][tx] == GameMap.OCEAN


