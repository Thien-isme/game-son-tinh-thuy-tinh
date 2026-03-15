extends CanvasLayer
class_name SinhLeHud

## HUD hiển thị 3 sính lễ cần thu thập ở Map 1.
## Gọi collect(item_name) từ Map1Controller (hoặc sự kiện nhặt) khi player thu được vật phẩm.

signal all_collected

@onready var icon_ga = %IconConGa
@onready var icon_voi = %IconConVoi
@onready var icon_ngua = %IconConNgua

@onready var check_ga = %CheckConGa
@onready var check_voi = %CheckConVoi
@onready var check_ngua = %CheckConNgua

@onready var bg_ga = %BgConGa
@onready var bg_voi = %BgConVoi
@onready var bg_ngua = %BgConNgua

var _collected: Dictionary = {"con_ga": false, "con_voi": false, "con_ngua": false}
var _nodes: Dictionary = {}

func _ready() -> void:
	# Lưu các node vào dictionary để truy cập cho nhanh
	_nodes["con_ga"] = {"icon": icon_ga, "check": check_ga, "bg": bg_ga}
	_nodes["con_voi"] = {"icon": icon_voi, "check": check_voi, "bg": bg_voi}
	_nodes["con_ngua"] = {"icon": icon_ngua, "check": check_ngua, "bg": bg_ngua}

func collect(item_name: String) -> void:
	if _collected.has(item_name) and not _collected[item_name]:
		_collected[item_name] = true
		_animate_collect(item_name)
		
		# Kiểm tra đã thu đủ chưa (all giá trị dictionary đều true)
		if _collected.values().all(func(v): return v):
			emit_signal("all_collected")

func _animate_collect(item_name: String) -> void:
	if not _nodes.has(item_name):
		return
		
	var dict = _nodes[item_name]
	var tex_rect: TextureRect = dict["icon"]
	var check: Label = dict["check"]
	var bg_panel: Panel = dict["bg"]

	if tex_rect:
		# Sáng rực + scale bounce
		var tween = create_tween()
		tween.set_parallel(true)
		# Màu rực rỡ (modulate > 1 = sáng hơn bình thường), từ xám đen thành màu thật
		tween.tween_property(tex_rect, "modulate", Color(1.4, 1.4, 1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(tex_rect, "scale", Vector2(1.4, 1.4), 0.18).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(tex_rect, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

	if bg_panel and bg_panel.get_theme_stylebox("panel") is StyleBoxFlat:
		var style: StyleBoxFlat = bg_panel.get_theme_stylebox("panel")
		# Để không thay đổi chung cho cả 3 (nếu chúng dùng chung StyleBox), ta phải duplicate
		var new_style = style.duplicate()
		bg_panel.add_theme_stylebox_override("panel", new_style)
		
		var border_tween = create_tween()
		border_tween.tween_method(func(v: float):
			new_style.border_color = Color(1.0, 0.85 + v * 0.15, 0.0, 1.0)
			new_style.border_width_left = int(2 + v * 3)
			new_style.border_width_right = int(2 + v * 3)
			new_style.border_width_top = int(2 + v * 3)
			new_style.border_width_bottom = int(2 + v * 3)
			new_style.bg_color = Color(0.15 + v * 0.1, 0.12 + v * 0.08, 0.0, 0.9)
		, 0.0, 1.0, 0.3)

	if check:
		check.visible = true
		check.modulate.a = 0.0
		check.scale = Vector2(2.0, 2.0)
		var check_tween = create_tween()
		check_tween.set_parallel(true)
		check_tween.tween_property(check, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		check_tween.tween_property(check, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
