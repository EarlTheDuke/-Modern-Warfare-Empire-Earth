extends Node
class_name CombatResolver

static func resolve_attack(attacker: UnitBase, defender: UnitBase, a_hit: float = 0.53, d_hit: float = 0.52) -> Array:
	# Clamp probabilities
	a_hit = clampf(a_hit, 0.2, 0.8)
	d_hit = clampf(d_hit, 0.2, 0.8)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	while attacker.hp > 0 and defender.hp > 0:
		if rng.randf() < a_hit:
			defender.hp -= 3
		if defender.hp <= 0:
			break
		if rng.randf() < d_hit:
			attacker.hp -= 2
	return [attacker.hp > 0, defender.hp > 0]


