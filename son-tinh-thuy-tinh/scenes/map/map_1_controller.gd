class_name Map1Controller
extends Node

## Controller cho Map 1 – quản lý việc thu thập sính lễ.
## Nhận signal từ 3 SinhLeItem, cập nhật HUD, hiển thị thông báo hoàn thành.

@onready var hud: SinhLeHud = get_node_or_null("../SinhLeHud")

func _ready() -> void:
	# Kết nối HUD signal all_collected
	call_deferred("_connect_items")

func _connect_items() -> void:
	# Tìm HUD
	var root = get_tree().current_scene
	if root:
		hud = _find_sinh_le_hud(root)

	if hud:
		if not hud.all_collected.is_connected(_on_all_collected):
			hud.all_collected.connect(_on_all_collected)
	else:
		push_warning("[Map1Controller] Không tìm thấy SinhLeHud trong scene!")

	# Tìm tất cả SinhLeItem trong scene và kết nối signal
	if root:
		_connect_all_items(root)

func _find_sinh_le_hud(node: Node) -> SinhLeHud:
	if node is SinhLeHud:
		return node
	for child in node.get_children():
		var result = _find_sinh_le_hud(child)
		if result:
			return result
	return null

func _connect_all_items(node: Node) -> void:
	# Tìm SinhLeWrapper (collectible items)
	if node is SinhLeWrapper:
		if not node.collected.is_connected(_on_item_collected):
			node.collected.connect(_on_item_collected)
	for child in node.get_children():
		_connect_all_items(child)

func _on_item_collected(item_name: String) -> void:
	print("[Map1Controller] Đã thu thập: ", item_name)
	if hud:
		hud.collect(item_name)

func _on_all_collected() -> void:
	print("[Map1Controller] Thu đủ sính lễ! Chuyển sang phân cảnh...")
	_show_completion_message()
	# Đợi animation hoàn thành rồi chuyển sang cutscene
	await get_tree().create_timer(2.5).timeout
	get_tree().change_scene_to_file("res://scenes/cutscene/cutscene_map1_win.tscn")

func _show_completion_message() -> void:
	# Tạo overlay thông báo ở giữa màn hình
	var canvas = CanvasLayer.new()
	canvas.layer = 10
	get_tree().current_scene.add_child(canvas)

	var bg = ColorRect.new()
	bg.color = Color(0, 0, 0, 0.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(bg)

	var vbox = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 12)
	canvas.add_child(vbox)

	# Icon sính lễ hoàn thành
	var icon_lbl = Label.new()
	icon_lbl.text = "🎊"
	icon_lbl.add_theme_font_size_override("font_size", 52)
	icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(icon_lbl)

	var msg = Label.new()
	msg.text = "ĐÃ THU ĐỦ SÍNH LỄ!"
	msg.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2))
	msg.add_theme_font_size_override("font_size", 36)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Outline
	msg.add_theme_constant_override("outline_size", 4)
	msg.add_theme_color_override("font_outline_color", Color(0.5, 0.2, 0))
	vbox.add_child(msg)

	var sub_msg = Label.new()
	sub_msg.text = "Sơn Tinh đã chuẩn bị xong sính lễ!"
	sub_msg.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	sub_msg.add_theme_font_size_override("font_size", 18)
	sub_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(sub_msg)

	# Animate bg và text fade-in + scale
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(bg, "color:a", 0.55, 0.5).set_ease(Tween.EASE_OUT)
	vbox.scale = Vector2(0.7, 0.7)
	vbox.modulate.a = 0.0
	tween.tween_property(vbox, "scale", Vector2.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(vbox, "modulate:a", 1.0, 0.35).set_ease(Tween.EASE_OUT)
