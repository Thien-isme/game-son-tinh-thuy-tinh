extends Control

# Tỉ lệ scale khi hover
const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const TWEEN_DURATION := 0.15

func _ready() -> void:
	# Hiện chuột khi ở sảnh
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Gán hiệu ứng hover cho 3 nút
	_setup_hover_effect($PlayButton)
	_setup_hover_effect($SettingButton)
	_setup_hover_effect($QuitButton)

func _setup_hover_effect(btn: TextureButton) -> void:
	# Đặt pivot ở giữa nút để scale từ tâm
	btn.pivot_offset = btn.size / 2.0
	
	btn.mouse_entered.connect(_on_btn_hover_enter.bind(btn))
	btn.mouse_exited.connect(_on_btn_hover_exit.bind(btn))

func _on_btn_hover_enter(btn: TextureButton) -> void:
	# Cập nhật lại pivot phòng trường hợp size thay đổi
	btn.pivot_offset = btn.size / 2.0
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_BACK)
	tween.tween_property(btn, "scale", HOVER_SCALE, TWEEN_DURATION)

func _on_btn_hover_exit(btn: TextureButton) -> void:
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_SINE)
	tween.tween_property(btn, "scale", NORMAL_SCALE, TWEEN_DURATION)

func _on_play_button_pressed() -> void:
	# Reset mạng về 3 trước khi bắt đầu game mới
	GameManager.reset()
	# Chuyển sang intro trước, sau intro sẽ vào map_1
	get_tree().change_scene_to_file("res://scenes/intro/intro.tscn")
	#get_tree().change_scene_to_file("res://scenes/map/map_1.tscn")  # Dùng khi test

func _on_setting_button_pressed() -> void:
	# TODO: Mở màn hình cài đặt
	print("Cài đặt đang được phát triển...")

func _on_quit_button_pressed() -> void:
	# Thoát game
	get_tree().quit()
