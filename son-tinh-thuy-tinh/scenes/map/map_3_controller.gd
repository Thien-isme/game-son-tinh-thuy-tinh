extends Node

## Controller cho màn 3 — quản lý win condition và rising water event
signal win_triggered

@export var win_message: String = "Sơn Tinh đã thoát nạn!"

var _won: bool = false


func _ready() -> void:
	# Connect WinZone signal từ sibling node
	var win_zone = get_parent().get_node_or_null("WinZone")
	if win_zone:
		win_zone.body_entered.connect(_on_win_zone_body_entered)
	else:
		push_warning("[Map3Controller] Không tìm thấy WinZone node!")

	# Thêm RisingWater vào group để dễ tìm
	var water = get_parent().get_node_or_null("RisingWater")
	if water:
		water.add_to_group("rising_water")


func _on_win_zone_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		trigger_win()


func trigger_win() -> void:
	if _won:
		return
	_won = true
	print("[Map3] WIN: ", win_message)
	win_triggered.emit()

	# Dừng nước
	var water = get_tree().get_first_node_in_group("rising_water")
	if water:
		water._active = false

	# Gọi game manager nếu có
	var gm = get_tree().get_first_node_in_group("game_manager")
	if gm and gm.has_method("on_map3_win"):
		gm.on_map3_win()
