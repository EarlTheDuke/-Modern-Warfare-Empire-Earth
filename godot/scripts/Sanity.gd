extends Node2D

@onready var label: Label = $Label

func _ready() -> void:
	print("[Sanity] Scene loaded.")
	if label:
		label.text = "Sanity OK - Press Space to load Main"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		print("[Sanity] Switching to Main.tscn")
		get_tree().change_scene_to_file("res://scenes/Main.tscn")


