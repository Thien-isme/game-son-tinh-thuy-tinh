class_name SinhLeWrapper
extends Node2D

## Wrapper bao ngoài enemy scene (con_ga, con_voi, con_ngua) để làm sính lễ collectible.
## - Vô hiệu hóa AI của enemy bên trong
## - Thêm Area2D detect player
## - Emit signal collected khi player đến gần

@export var item_name: String = "con_ga"  ## "con_ga" | "con_voi" | "con_ngua"
@export var collect_radius: float = 60.0  ## Bán kính thu thập (pixel)
@export var float_height: float = 6.0     ## Biên độ lắc lư nhẹ
@export var float_speed: float = 2.0

signal collected(item_name: String)

var _collected: bool = false
var _time: float = 0.0
var _base_y: float = 0.0
var _collector: Area2D = null
var _enemy_node = null   # node root của enemy scene (CharacterBody2D)

func _ready() -> void:
	_base_y = position.y

	# Tìm child CharacterBody2D (enemy scene)
	for child in get_children():
		if child is CharacterBody2D:
			_enemy_node = child
			break

	if _enemy_node:
		_disable_enemy_ai(_enemy_node)

	# Tạo Area2D thu thập động
	_collector = Area2D.new()
	_collector.name = "Collector"
	_collector.collision_layer = 4
	_collector.collision_mask = 0xFFFFFFFF

	var shape_node = CollisionShape2D.new()
	var circle = CircleShape2D.new()
	circle.radius = collect_radius
	shape_node.shape = circle
	_collector.add_child(shape_node)
	add_child(_collector)
	_collector.body_entered.connect(_on_body_entered)

	# Hiệu ứng scale-in khi spawn
	scale = Vector2.ZERO
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.35).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)

	# Floating label phía trên
	_add_float_label()

func _disable_enemy_ai(enemy: CharacterBody2D) -> void:
	# Vô hiệu hóa patrol và detection để enemy chỉ đứng idle
	if enemy.has_method("set_physics_process"):
		enemy.set_physics_process(false)
	if enemy.has_method("set_process"):
		enemy.set_process(false)

	# Đặt patrol_distance = 0 để không đi lại
	if "patrol_distance" in enemy:
		enemy.patrol_distance = 0.0
	# Đặt detect_radius = 0 để không phát hiện player
	if "detect_radius" in enemy:
		enemy.detect_radius = 0.0
	if "attack_radius" in enemy:
		enemy.attack_radius = 0.0

	# Tắt các collision zone
	for zone_name in ["DetectZone", "AttackZone", "MeleeHitbox"]:
		if enemy.has_node(zone_name + "/CollisionShape2D"):
			enemy.get_node(zone_name + "/CollisionShape2D").set_deferred("disabled", true)

	# Play animation idle để đứng yên
	await get_tree().physics_frame
	if enemy.has_node("AnimatedSprite2D"):
		var spr = enemy.get_node("AnimatedSprite2D")
		if spr.sprite_frames and spr.sprite_frames.has_animation("idle"):
			spr.speed_scale = 0.3  # Chậm lại một chút cho đẹp
			spr.play("idle")

func _add_float_label() -> void:
	var label = Label.new()
	label.name = "HintLabel"
	label.text = "★ Sính Lễ ★"
	label.add_theme_color_override("font_color", Color(1.0, 0.95, 0.2, 0.9))
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_constant_override("outline_size", 3)
	label.add_theme_color_override("font_outline_color", Color(0.4, 0.2, 0.0))
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.position = Vector2(-50, -80)
	label.z_index = 10
	add_child(label)

	# Nhấp nháy nhẹ
	var tween = create_tween().set_loops()
	tween.tween_property(label, "modulate:a", 0.5, 0.7).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(label, "modulate:a", 1.0, 0.7).set_ease(Tween.EASE_IN_OUT)

func _process(delta: float) -> void:
	if _collected:
		return
	# Lắc lư lên xuống nhẹ
	_time += delta
	position.y = _base_y + sin(_time * float_speed) * float_height

func _on_body_entered(body: Node) -> void:
	if _collected:
		return
	if not body.is_in_group("player"):
		return
	_collected = true
	emit_signal("collected", item_name)
	_play_collect_effect()

func _play_collect_effect() -> void:
	# Tắt collector
	if _collector:
		_collector.set_deferred("monitoring", false)

	# Tween: bay lên + fade out
	var tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 50, 0.45).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2(1.4, 1.4), 0.2).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(queue_free)
