@tool
extends Marker2D
class_name LevelBounds

@export var is_right_bound: bool = true :
	set(value):
		is_right_bound = value
		queue_redraw()

func _draw():
	if Engine.is_editor_hint():
		# Vẽ một đường kẻ dọc rực rỡ để dễ nhìn thấy trong Editor
		# Đường kẻ dài từ -2000 đến +2000 pixel theo trục Y
		var color = Color.RED if is_right_bound else Color.CYAN
		var line_start = Vector2(0, -3000)
		var line_end = Vector2(0, 3000)
		draw_line(line_start, line_end, color, 10.0)
		
		# Nhãn chữ bự
		var font_string = "RIGHT BOUNDARY" if is_right_bound else "LEFT BOUNDARY"
		draw_string_outline(ThemeDB.fallback_font, Vector2(-60, 0), font_string, 1, -1, 32, 5, Color.BLACK)
		draw_string(ThemeDB.fallback_font, Vector2(-60, 0), font_string, 1, -1, 32, color)


func _ready():
	if Engine.is_editor_hint():
		return
	
	# Đợi 1 frame để Player đã hoàn toàn ready (tránh race condition)
	await get_tree().physics_frame
	
	# Khi vào game, gởi vị trí X của mình cho Player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		if is_right_bound:
			player.set_right_bound(global_position.x)
		else:
			player.set_left_bound(global_position.x)
