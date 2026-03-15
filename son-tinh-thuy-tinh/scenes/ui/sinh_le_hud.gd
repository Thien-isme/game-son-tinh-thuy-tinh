class_name SinhLeHud
extends CanvasLayer

## HUD hiển thị 3 sính lễ cần thu thập ở Map 1.
## Gọi collect(item_name) từ Map1Controller khi player thu được vật phẩm.

signal all_collected

# Danh sách 3 sính lễ theo thứ tự hiển thị
const ITEM_ORDER: Array = ["con_ga", "con_voi", "con_ngua"]
const ITEM_LABELS: Dictionary = {
	"con_ga": "Con Gà",
	"con_voi": "Con Voi",
	"con_ngua": "Con Ngựa"
}
const ITEM_SPRITES: Dictionary = {
	"con_ga":   "res://assets/sprites/con_ga/idle/0001.png",
	"con_voi":  "res://assets/sprites/con_voi/idle/0001.png",
	"con_ngua": "res://assets/sprites/con_ngua/idle/0001.png",
}

var _collected: Dictionary = {"con_ga": false, "con_voi": false, "con_ngua": false}
var _icon_rects: Dictionary = {}
var _check_labels: Dictionary = {}

func _ready() -> void:
	_build_hud()

func _build_hud() -> void:
	# Root panel ở góc trên phải
	var panel = PanelContainer.new()
	panel.name = "SinhLePanel"
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2(16, 16)

	# Style bán trong suốt
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.55)
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_left = 12
	style.corner_radius_bottom_right = 12
	style.border_width_left = 2
	style.border_width_right = 2
	style.border_width_top = 2
	style.border_width_bottom = 2
	style.border_color = Color(1, 0.85, 0.3, 0.8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	# Tiêu đề
	var title = Label.new()
	title.text = "🎁 Sính Lễ"
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.4))
	title.add_theme_font_size_override("font_size", 14)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# Separator
	var sep = HSeparator.new()
	vbox.add_child(sep)

	# 3 item slots
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER

	for item_name in ITEM_ORDER:
		var slot = VBoxContainer.new()
		slot.add_theme_constant_override("separation", 2)

		# Icon container với background circle
		var icon_container = Panel.new()
		icon_container.custom_minimum_size = Vector2(64, 64)
		var icon_style = StyleBoxFlat.new()
		icon_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
		icon_style.corner_radius_top_left = 32
		icon_style.corner_radius_top_right = 32
		icon_style.corner_radius_bottom_left = 32
		icon_style.corner_radius_bottom_right = 32
		icon_style.border_width_left = 2
		icon_style.border_width_right = 2
		icon_style.border_width_top = 2
		icon_style.border_width_bottom = 2
		icon_style.border_color = Color(0.5, 0.5, 0.5, 0.7)
		icon_container.add_theme_stylebox_override("panel", icon_style)
		_icon_rects["style_" + item_name] = icon_style

		# TextureRect hiển thị ảnh con vật
		var tex_rect = TextureRect.new()
		tex_rect.name = "Icon_" + item_name
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE)
		tex_rect.offset_left = 4
		tex_rect.offset_top = 4
		tex_rect.offset_right = -4
		tex_rect.offset_bottom = -4
		# Greyed-out cho đến khi thu thập
		tex_rect.modulate = Color(0.35, 0.35, 0.35, 1.0)
		# Load texture
		if ResourceLoader.exists(ITEM_SPRITES[item_name]):
			tex_rect.texture = load(ITEM_SPRITES[item_name])
		icon_container.add_child(tex_rect)
		_icon_rects[item_name] = tex_rect

		# Dấu check (ẩn mặc định)
		var check = Label.new()
		check.text = "✓"
		check.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
		check.add_theme_font_size_override("font_size", 22)
		check.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		check.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		check.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		check.visible = false
		icon_container.add_child(check)
		_check_labels[item_name] = check

		slot.add_child(icon_container)

		# Tên item
		var lbl = Label.new()
		lbl.text = ITEM_LABELS[item_name]
		lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		slot.add_child(lbl)

		hbox.add_child(slot)

	vbox.add_child(hbox)
	panel.add_child(vbox)
	add_child(panel)

func collect(item_name: String) -> void:
	if _collected.has(item_name) and not _collected[item_name]:
		_collected[item_name] = true
		_animate_collect(item_name)
		# Kiểm tra đã thu đủ chưa
		if _collected.values().all(func(v): return v):
			emit_signal("all_collected")

func _animate_collect(item_name: String) -> void:
	var tex_rect: TextureRect = _icon_rects.get(item_name)
	var check: Label = _check_labels.get(item_name)
	var icon_style: StyleBoxFlat = _icon_rects.get("style_" + item_name)

	if tex_rect:
		# Sáng rực + scale bounce
		var tween = create_tween()
		tween.set_parallel(true)
		# Màu rực rỡ (modulate > 1 = sáng hơn bình thường)
		tween.tween_property(tex_rect, "modulate", Color(1.4, 1.4, 1.0, 1.0), 0.25).set_ease(Tween.EASE_OUT)
		tween.tween_property(tex_rect, "scale", Vector2(1.4, 1.4), 0.18).set_ease(Tween.EASE_OUT)
		tween.chain().tween_property(tex_rect, "scale", Vector2(1.0, 1.0), 0.2).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_ELASTIC)

	if icon_style:
		# Viền vàng sáng rực khi đã thu thập
		var border_tween = create_tween()
		border_tween.tween_method(func(v: float):
			icon_style.border_color = Color(1.0, 0.85 + v * 0.15, 0.0, 1.0)
			icon_style.border_width_left = int(2 + v * 3)
			icon_style.border_width_right = int(2 + v * 3)
			icon_style.border_width_top = int(2 + v * 3)
			icon_style.border_width_bottom = int(2 + v * 3)
			icon_style.bg_color = Color(0.15 + v * 0.1, 0.12 + v * 0.08, 0.0, 0.9)
		, 0.0, 1.0, 0.3)

	if check:
		check.visible = true
		check.modulate.a = 0.0
		check.scale = Vector2(2.0, 2.0)
		var check_tween = create_tween()
		check_tween.set_parallel(true)
		check_tween.tween_property(check, "modulate:a", 1.0, 0.3).set_ease(Tween.EASE_OUT)
		check_tween.tween_property(check, "scale", Vector2(1.0, 1.0), 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
