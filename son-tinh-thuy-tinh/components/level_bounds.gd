@tool
extends Marker2D
class_name LevelBounds

# Tên node xác định loại boundary: "LeftBoundary" hoặc "RightBoundary"
# camera_lock.gd sẽ tự scan và set camera.limit_left/right
@export var is_right_bound: bool = false :
	set(value):
		is_right_bound = value
		queue_redraw()

func _is_right() -> bool:
	if name.to_lower().contains("right"):
		return true
	if name.to_lower().contains("left"):
		return false
	return is_right_bound

func _draw():
	# Chỉ vẽ trong editor để preview vị trí boundary
	if not Engine.is_editor_hint():
		return
	var is_r = _is_right()
	var color = Color.RED if is_r else Color.CYAN
	draw_line(Vector2(0, -3000), Vector2(0, 3000), color, 10.0)
	var label = "RIGHT BOUNDARY" if is_r else "LEFT BOUNDARY"
	draw_string_outline(ThemeDB.fallback_font, Vector2(-60, 0), label, 1, -1, 32, 5, Color.BLACK)
	draw_string(ThemeDB.fallback_font, Vector2(-60, 0), label, 1, -1, 32, color)
