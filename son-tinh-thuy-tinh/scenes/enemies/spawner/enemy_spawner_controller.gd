@tool
extends Node2D

@export var enemy_scene: PackedScene
@export var max_enemies: int = 1
@export var spawn_interval: float = 3.0

@export_category("Spawner Area Settings")
## Kích thước vùng phát hiện player để bắt đầu spawn
@export var detect_size: Vector2 = Vector2(1200, 645):
	set(value):
		detect_size = value
		_update_detect_shape()

@export_category("Enemy Stats Overrides")
## Máu riêng cho bầy quái này (để 0 xài mặc định)
@export var override_health: float = 0.0
## Sát thương cận chiến riêng (để 0 xài mặc định)
@export var override_melee_damage: float = 0.0
## Thời gian giữa 2 đòn đánh (để 0 xài mặc định)
@export var override_attack_cooldown: float = 0.0
## Khoảng cách đi tuần tra (để 0 xài mặc định)
@export var override_patrol_distance: float = 0.0

@export_group("Enemy Area Previews (Editor Only)")
## Bán kính vùng phát hiện enemy (Xanh ngọc) - chỉ preview
@export var override_detect_radius: float = 0.0:
	set(value):
		override_detect_radius = value
		queue_redraw()
## Bán kính vùng tấn công enemy (Đỏ) - chỉ preview
@export var override_attack_radius: float = 0.0:
	set(value):
		override_attack_radius = value
		queue_redraw()

var is_player_near: bool = false
var spawn_points_data: Array[Dictionary] = []

@onready var detect_shape = $DetectArea/CollisionShape2D

func _ready():
	_update_detect_shape()
	if Engine.is_editor_hint():
		return

	# Quét tất cả Marker2D con → mỗi cái là 1 spawn point
	for child in get_children():
		if child is Marker2D:
			var point_data = {
				"node": child,
				"timer": Timer.new(),
				"spawned_count": 0,
				"max_enemies": max_enemies,
				"enemy_scene": enemy_scene,
			}

			# Lấy override riêng của từng Marker nếu có
			if "max_enemies" in child and child.max_enemies > 0:
				point_data["max_enemies"] = child.max_enemies
			if "enemy_scene" in child and child.enemy_scene != null:
				point_data["enemy_scene"] = child.enemy_scene



			var interval = spawn_interval
			if "spawn_interval" in child and child.spawn_interval > 0:
				interval = child.spawn_interval

			var t = point_data["timer"]
			t.wait_time = interval
			t.one_shot = false
			t.timeout.connect(_on_point_timer_timeout.bind(point_data))
			add_child(t)

			spawn_points_data.append(point_data)

func _update_detect_shape():
	if not is_node_ready():
		return
	if detect_shape and detect_shape.shape is RectangleShape2D:
		detect_shape.shape.size = detect_size

func _draw():
	if Engine.is_editor_hint():
		for child in get_children():
			if child is Marker2D:
				var d_rad = override_detect_radius
				var a_rad = override_attack_radius
				if "override_detect_radius" in child and child.override_detect_radius > 0:
					d_rad = child.override_detect_radius
				if "override_attack_radius" in child and child.override_attack_radius > 0:
					a_rad = child.override_attack_radius

				if d_rad > 0:
					draw_circle(child.position, d_rad, Color(0.1, 0.8, 0.8, 0.2))
				if a_rad > 0:
					draw_circle(child.position, a_rad, Color(0.9, 0.1, 0.3, 0.3))

func _on_detect_area_body_entered(body):
	if Engine.is_editor_hint(): return
	if body.is_in_group("player"):
		is_player_near = true
		# Spawn ngay 1 con rồi bật timer cho các điểm chưa đủ quái
		for data in spawn_points_data:
			if data["spawned_count"] < data["max_enemies"]:
				if data["timer"].is_stopped():
					_on_point_timer_timeout(data)
					if data["spawned_count"] < data["max_enemies"]:
						data["timer"].start()

func _on_detect_area_body_exited(body):
	if Engine.is_editor_hint(): return
	if body.is_in_group("player"):
		is_player_near = false
		for data in spawn_points_data:
			data["timer"].stop()

func _on_point_timer_timeout(data: Dictionary):
	if Engine.is_editor_hint(): return

	if data["spawned_count"] >= data["max_enemies"]:
		data["timer"].stop()
		return

	if not is_player_near or not data["enemy_scene"]:
		return

	var enemy = data["enemy_scene"].instantiate()
	var marker = data["node"]

	# Áp dụng overrides (ưu tiên Marker > Spawner)
	var h = override_health
	var dmg = override_melee_damage
	var atk_cd = override_attack_cooldown
	var d_rad = override_detect_radius
	var a_rad = override_attack_radius
	var p_dist = override_patrol_distance

	if "override_health"          in marker and marker.override_health > 0:          h = marker.override_health
	if "override_melee_damage"    in marker and marker.override_melee_damage > 0:    dmg = marker.override_melee_damage
	if "override_attack_cooldown" in marker and marker.override_attack_cooldown > 0: atk_cd = marker.override_attack_cooldown
	if "override_detect_radius"   in marker and marker.override_detect_radius > 0:   d_rad = marker.override_detect_radius
	if "override_attack_radius"   in marker and marker.override_attack_radius > 0:   a_rad = marker.override_attack_radius
	if "override_patrol_distance" in marker and marker.override_patrol_distance > 0: p_dist = marker.override_patrol_distance

	if h > 0       and "health"          in enemy: enemy.health = h
	if dmg > 0     and "melee_damage"    in enemy: enemy.melee_damage = dmg
	if atk_cd > 0  and "attack_cooldown" in enemy: enemy.attack_cooldown = atk_cd
	if d_rad > 0   and "detect_radius"   in enemy: enemy.detect_radius = d_rad
	if a_rad > 0   and "attack_radius"   in enemy: enemy.attack_radius = a_rad
	if p_dist > 0  and "patrol_distance" in enemy: enemy.patrol_distance = p_dist

	# Thêm vào node Enemies trong scene hoặc scene root
	var enemies_node = get_tree().current_scene.find_child("Enemies", true, false)
	if enemies_node:
		enemies_node.add_child(enemy)
	else:
		get_tree().current_scene.add_child(enemy)

	enemy.global_position = marker.global_position
	data["spawned_count"] += 1
