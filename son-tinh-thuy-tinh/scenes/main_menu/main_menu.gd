extends Control

func _ready() -> void:
	# Hiện chuột khi ở sảnh
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_play_button_pressed() -> void:
	# Chuyển sang map_2.tscn khi bấm Bắt Đầu
	get_tree().change_scene_to_file("res://scenes/map/map_2.tscn")

func _on_quit_button_pressed() -> void:
	# Thoát game
	get_tree().quit()
