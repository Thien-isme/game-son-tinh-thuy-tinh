extends Node

## GameManager – Autoload singleton quản lý số mạng và trạng thái game.

const MAX_LIVES: int = 3

var lives: int = MAX_LIVES

# Đặt lại về trạng thái ban đầu (gọi khi bắt đầu game mới từ Menu)
func reset() -> void:
	lives = MAX_LIVES

# Gọi khi người chơi chết
func lose_life() -> void:
	lives -= 1
	print("[GameManager] Còn lại %d mạng." % lives)

	# Lấy map hiện tại từ scene đang chạy
	var current_map: String = get_tree().current_scene.scene_file_path

	if lives > 0:
		# Còn mạng – reload lại map hiện tại sau một khoảng trễ ngắn
		await get_tree().create_timer(1.5).timeout
		get_tree().paused = false
		get_tree().change_scene_to_file(current_map)
	else:
		# Hết mạng – hiện màn Game Over
		await get_tree().create_timer(1.5).timeout
		get_tree().paused = false
		var game_over_scene = preload("res://ui/menus/game_over.tscn")
		get_tree().change_scene_to_packed(game_over_scene)

# Gọi khi hoàn thành map (chuyển map tiếp theo)
func go_to_map(map_path: String) -> void:
	get_tree().change_scene_to_file(map_path)
