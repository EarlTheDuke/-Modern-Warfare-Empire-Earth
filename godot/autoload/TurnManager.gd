extends Node

signal turn_changed(current_player: String)

const PLAYERS: Array[String] = ["P1", "P2"]
var current_player: String = PLAYERS[0]
var turn_number: int = 1

func end_turn() -> void:
	var idx := PLAYERS.find(current_player)
	if idx == -1:
		idx = 0
	current_player = PLAYERS[(idx + 1) % PLAYERS.size()]
	turn_number += 1
	emit_signal("turn_changed", current_player)
