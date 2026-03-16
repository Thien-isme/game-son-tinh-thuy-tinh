extends CanvasLayer
class_name PlayerHUD

## HUD hiển thị máu + số mạng của player.
## Scene này có thể mở trực tiếp trong Godot Editor để chỉnh layout.

@onready var health_bar: ProgressBar = $Panel/VBox/HealthBar
@onready var heart1: Label = $Panel/VBox/TopRow/LivesRow/Heart1
@onready var heart2: Label = $Panel/VBox/TopRow/LivesRow/Heart2
@onready var heart3: Label = $Panel/VBox/TopRow/LivesRow/Heart3

var _hearts: Array = []

func _ready() -> void:
	_hearts = [heart1, heart2, heart3]
	_apply_panel_style()
	_apply_bar_style()
	update_lives(GameManager.lives)

func _apply_panel_style() -> void:
	var panel = $Panel
	if not panel:
		return
	var style = StyleBoxFlat.new()
	style.bg_color           = Color(0.08, 0.06, 0.04, 0.85)
	style.corner_radius_top_left     = 8
	style.corner_radius_top_right    = 8
	style.corner_radius_bottom_left  = 8
	style.corner_radius_bottom_right = 8
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.8, 0.6, 0.1, 0.9)
	panel.add_theme_stylebox_override("panel", style)

func _apply_bar_style() -> void:
	if not health_bar:
		return
	var bar_bg = StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.25, 0.05, 0.05)
	bar_bg.corner_radius_top_left = 4
	bar_bg.corner_radius_top_right = 4
	bar_bg.corner_radius_bottom_left = 4
	bar_bg.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("background", bar_bg)

	var bar_fill = StyleBoxFlat.new()
	bar_fill.bg_color = Color(0.9, 0.15, 0.15)
	bar_fill.corner_radius_top_left = 4
	bar_fill.corner_radius_top_right = 4
	bar_fill.corner_radius_bottom_left = 4
	bar_fill.corner_radius_bottom_right = 4
	health_bar.add_theme_stylebox_override("fill", bar_fill)

# --- Public API ---

func set_max_health(value: float) -> void:
	if health_bar:
		health_bar.max_value = value

func update_health(value: float) -> void:
	if health_bar:
		health_bar.value = value
		# Đổi màu khi máu thấp
		var low_threshold = health_bar.max_value * 0.3
		var fill_color = Color(0.95, 0.75, 0.0) if value < low_threshold else Color(0.9, 0.15, 0.15)
		var fill_style = StyleBoxFlat.new()
		fill_style.bg_color = fill_color
		fill_style.corner_radius_top_left = 4
		fill_style.corner_radius_top_right = 4
		fill_style.corner_radius_bottom_left = 4
		fill_style.corner_radius_bottom_right = 4
		health_bar.add_theme_stylebox_override("fill", fill_style)

func update_lives(lives_count: int) -> void:
	for i in range(_hearts.size()):
		var heart: Label = _hearts[i]
		if i < lives_count:
			heart.text = "❤"
			heart.modulate = Color(1, 1, 1, 1)
		else:
			heart.text = "♡"
			heart.modulate = Color(1, 1, 1, 0.35)
