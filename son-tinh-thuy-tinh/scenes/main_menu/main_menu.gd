extends Control

func _ready() -> void:
	# Hiện chuột khi ở sảnh
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_play_button_pressed() -> void:
	# Reset mạng về 3 trước khi bắt đầu game mới
	GameManager.reset()
	# Chuyển sang map_1.tscn khi bấm Bắt Đầu
	get_tree().change_scene_to_file("res://scenes/map/map_1.tscn")

func _on_quit_button_pressed() -> void:
	# Thoát game
	get_tree().quit()
