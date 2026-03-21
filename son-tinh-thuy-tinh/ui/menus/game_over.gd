extends Control

const HOVER_SCALE := Vector2(1.1, 1.1)
const NORMAL_SCALE := Vector2(1.0, 1.0)
const TWEEN_DURATION := 0.15

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_setup_hover_effect($MenuButton)

func _setup_hover_effect(btn: TextureButton) -> void:
	btn.pivot_offset = btn.size / 2.0
	btn.mouse_entered.connect(_on_btn_hover_enter.bind(btn))
	btn.mouse_exited.connect(_on_btn_hover_exit.bind(btn))

func _on_btn_hover_enter(btn: TextureButton) -> void:
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

func _on_menu_pressed() -> void:
	GameManager.reset()
	get_tree().change_scene_to_file("res://scenes/main_menu/main_menu.tscn")
