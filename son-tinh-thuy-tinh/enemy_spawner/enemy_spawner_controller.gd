@tool
extends Node2D

@export var enemy_scene: PackedScene
@export var max_enemies: int = 1
@export var spawn_interval: float = 2.0

@export_category("Spawner Area Settings")
## Kích thước vùng nhận diện người chơi
@export var detect_size: Vector2 = Vector2(920, 645):
	set(value):
		detect_size = value
		_update_detect_shape()

@export_category("Enemy Stats Overrides")
## Chỉnh Máu (Health) riêng cho bầy quái này (để 0 thì xài mặc định của quái)
@export var override_health: float = 0.0
## Chỉnh tốc độ bắn riệng cho bầy quái này (để 0 thì xài mặc định của quái)
@export var override_shoot_cooldown: float = 0.0
## Chỉnh tốc độ đạn riêng cho bầy quái này (để 0 thì xài mặc định của đạn)
@export var override_bullet_speed: float = 0.0
## Cho phép viên đạn bắn xuyên qua tường và đất nấp (Rất hữu ích cho quái đứng trên cao xả đạn xuống)
@export var override_bullet_pass_terrain: bool = true
## Chỉnh khoảng cách đi tuần tra (để 0 thì xài mặc định của quái)
@export var override_patrol_distance: float = 0.0

@export_group("Enemy Area Previews (Editor Only)")
## Chỉnh vùng Detect của bầy quái (để 0 thì xài vùng mặc định của quái - chỉ hiển thị để làm chuẩn)
@export var override_detect_radius: float = 0.0 :
	set(value):
		override_detect_radius = value
		queue_redraw()
## Chỉnh vùng Attack của bầy quái (để 0 thì xài vùng mặc định của quái - chỉ hiển thị để làm chuẩn)
@export var override_attack_radius: float = 0.0 :
	set(value):
		override_attack_radius = value
		queue_redraw()



var is_player_near: bool = false
var spawn_points_data: Array[Dictionary] = []

@onready var detect_shape = $DetectArea/CollisionShape2D

func _ready():
	_update_detect_shape()
	
	if Engine.is_editor_hint():
		return # Không chạy logic game trong editor

	# Quét qua tất cả Marker2D con và thiết lập bộ định thời (Timer) đẻ quái độc lập cho từng điểm
	for child in get_children():
		if child is Marker2D:
			var point_data = {
				"node": child,
				"timer": Timer.new(),
				"spawned_count": 0,
				"max_enemies": max_enemies, # Fallback mặc định
				"enemy_scene": enemy_scene, # Fallback mặc định
			}
			
			# Lấy dữ liệu riêng của điểm này (ghi đè)
			if "max_enemies" in child and child.max_enemies > 0:
				point_data["max_enemies"] = child.max_enemies
				
			# Cực kỳ quan trọng: Phải kiểm tra thuộc tính enemy_scene của child
			if "enemy_scene" in child and child.enemy_scene != null:
				point_data["enemy_scene"] = child.enemy_scene
			
			print("Spawner [%s] -> Child [%s] is spawning: %s" % [
				name, 
				child.name, 
				point_data["enemy_scene"].resource_path if point_data["enemy_scene"] else "NULL! (Quên ko gắn quái?)"
			])
				
			var interval = spawn_interval
			if "spawn_interval" in child and child.spawn_interval > 0:
				interval = child.spawn_interval
				
			# Setup Timer
			var t = point_data["timer"]
			t.wait_time = interval
			t.one_shot = false
			# Kết nối tín hiệu truyền kèm data của marker này vào hàm đẻ
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
		var markers = []
		for child in get_children():
			if child is Marker2D:
				markers.append(child)
				
		for m in markers:
			var d_radius = override_detect_radius
			var a_radius = override_attack_radius
			if "override_detect_radius" in m and m.override_detect_radius > 0: d_radius = m.override_detect_radius
			if "override_attack_radius" in m and m.override_attack_radius > 0: a_radius = m.override_attack_radius
				
			if d_radius > 0:
				draw_circle(m.position, d_radius, Color(0.1, 0.8, 0.8, 0.2))
			if a_radius > 0:
				draw_circle(m.position, a_radius, Color(0.9, 0.1, 0.3, 0.3))

func _on_detect_area_body_entered(body):
	if Engine.is_editor_hint(): return
	if body.is_in_group("player"):
		is_player_near = true
		
		# Bật tất cả các bộ đếm giờ của các SpawnPoint chưa đẻ xong
		for data in spawn_points_data:
			if data["spawned_count"] < data["max_enemies"]:
				if data["timer"].is_stopped():
					_on_point_timer_timeout(data) # Đẻ ngay 1 con
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
		
	if is_player_near and data["enemy_scene"]:
		var enemy = data["enemy_scene"].instantiate()
		var marker = data["node"]
		
		# Tính toán thông số nào sẽ áp dụng (ưu tiên Marker > Spawner gốc)
		var h_hp = override_health
		var shoot_cd = override_shoot_cooldown
		var bullet_spd = override_bullet_speed
		var d_rad = override_detect_radius
		var a_rad = override_attack_radius
		var p_dist = override_patrol_distance
		var pass_terrain = override_bullet_pass_terrain
		
		if "override_health" in marker and marker.override_health > 0: h_hp = marker.override_health
		if "override_shoot_cooldown" in marker and marker.override_shoot_cooldown > 0: shoot_cd = marker.override_shoot_cooldown
		if "override_bullet_speed" in marker and marker.override_bullet_speed > 0: bullet_spd = marker.override_bullet_speed
		if "override_detect_radius" in marker and marker.override_detect_radius > 0: d_rad = marker.override_detect_radius
		if "override_attack_radius" in marker and marker.override_attack_radius > 0: a_rad = marker.override_attack_radius
		if "override_patrol_distance" in marker and marker.override_patrol_distance > 0: p_dist = marker.override_patrol_distance
		if "override_bullet_pass_terrain" in marker and marker.override_bullet_pass_terrain: pass_terrain = true
		
		# Áp dụng các thông số
		if h_hp > 0 and "health" in enemy:
			enemy.health = h_hp
		if shoot_cd > 0.0 and "shoot_cooldown" in enemy:
			enemy.shoot_cooldown = shoot_cd
		if bullet_spd > 0.0 and "bullet_speed" in enemy:
			enemy.bullet_speed = bullet_spd
		if d_rad > 0.0 and "detect_radius" in enemy:
			enemy.detect_radius = d_rad
		if a_rad > 0.0 and "attack_radius" in enemy:
			enemy.attack_radius = a_rad
		if p_dist > 0.0 and "patrol_distance" in enemy:
			enemy.patrol_distance = p_dist
		if pass_terrain and "bullet_pass_terrain" in enemy:
			enemy.bullet_pass_terrain = pass_terrain
			
		# Add child MỚI vào hệ thống (lúc này _ready() của enemy mới bắt đầu chạy)
		var parent_node = get_tree().current_scene.find_child("Enemies", true, false)
		if parent_node:
			parent_node.add_child(enemy)
		else:
			get_tree().current_scene.add_child(enemy)
			
		enemy.global_position = marker.global_position
			
		data["spawned_count"] += 1
