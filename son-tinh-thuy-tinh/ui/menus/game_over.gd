extends Control

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_retry_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/map/map_1.tscn")

func _on_menu_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
