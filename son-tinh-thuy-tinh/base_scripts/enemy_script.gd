@tool
extends CharacterBody2D

@export var speed = 80.0
@export var health: float = 30.0
@export var shoot_cooldown = 2.0
@export var bullet_scene: PackedScene  # Chỉnh trong Inspector cho từng enemy
@export var bullet_speed: float = 300.0
@export var bullet_damage: float = 10.0
@export var bullet_pass_terrain: bool = true # Đạn có thể xuyên tường/đất không

@export_category("Patrol Settings")
@export var patrol_distance: float = 100.0 : # Khoảng cách đi tuần mỗi bên (để 0 nếu muốn đứng im)
	set(value):
		patrol_distance = value
		queue_redraw()
@export var patrol_speed: float = 40.0   # Tốc độ đi tuần (chậm hơn speed rượt đuổi)
@export var patrol_wait_time: float = 1.5 # Thời gian đứng ngó nghiêng ở mỗi đầu
@export var avoid_ledges: bool = true # Không cho phép té khỏi mép vực khi đi tuần / rượt đuổi

@export_category("Audio")
@export var shoot_sfx: AudioStream  # Tiếng bắn đạn - kéo thả file âm thanh vào đây
@export var die_sfx: AudioStream    # Tiếng chết - kéo thả file âm thanh vào đây
@export var explode_sfx: AudioStream  # Tiếng đạn trúng player - kéo thả file âm thanh vào đây

var player = null
var can_shoot = true
var is_attacking = false
var is_dead = false

var max_health: float = 1.0
var health_bar: ProgressBar = null

@export_category("Detection Areas")
@export var detect_radius: float = 500.0 :
	set(value):
		detect_radius = value
		_update_shape("DetectZone", value)
		queue_redraw()
		
@export var attack_radius: float = 300.0 :
	set(value):
		attack_radius = value
		_update_shape("AttackZone", value)
		queue_redraw()

func _update_shape(zone_name: String, radius_value: float):
	if Engine.is_editor_hint() and is_inside_tree() and has_node(zone_name + "/CollisionShape2D"):
		var shape = get_node(zone_name + "/CollisionShape2D").shape as CircleShape2D
		if shape:
			shape.set_deferred("radius", radius_value)

# Biến dùng cho đi tuần
var start_x: float = 0.0
var patrol_target_x: float = 0.0
var patrol_dir: int = 1
var is_patrol_waiting: bool = false

var floor_raycast: RayCast2D = null

@onready var anim = $AnimatedSprite2D
@onready var sfx_player = $SFXPlayer

const GRAVITY = 900

func _ready():
	if Engine.is_editor_hint(): return
	
	start_x = global_position.x
	patrol_target_x = start_x + patrol_distance * patrol_dir
	
	if detect_radius > 0 and has_node("DetectZone/CollisionShape2D"):
		var d_shape = $DetectZone/CollisionShape2D.shape as CircleShape2D
		if d_shape:
			var new_d_shape = d_shape.duplicate()
			new_d_shape.radius = detect_radius
			$DetectZone/CollisionShape2D.set_deferred("shape", new_d_shape)
			
	if attack_radius > 0 and has_node("AttackZone/CollisionShape2D"):
		var a_shape = $AttackZone/CollisionShape2D.shape as CircleShape2D
		if a_shape:
			var new_a_shape = a_shape.duplicate()
			new_a_shape.radius = attack_radius
			$AttackZone/CollisionShape2D.set_deferred("shape", new_a_shape)
			
	# Lưu max_health và Khởi tạo Thanh Máu (Health Bar)
	max_health = health
	_create_health_bar()
	
	if avoid_ledges:
		floor_raycast = RayCast2D.new()
		floor_raycast.target_position = Vector2(0, 50) # Bắn tia xuống dưới 50px
		# Lớp va chạm 1 (thường là môi trường/đất). Bạn có thể chỉnh lại mask cho phù hợp.
		floor_raycast.collision_mask = 1 
		add_child(floor_raycast)

	# Chờ 1 frame vật lý để Godot xử lý xong các vùng va chạm vừa được tạo
	await get_tree().physics_frame
	
	# Kiểm tra xem Player có đang đứng sẵn trong vùng không (do đẻ quái sát bên cạnh Player)
	if has_node("DetectZone"):
		for body in $DetectZone.get_overlapping_bodies():
			if body.is_in_group("player"):
				player = body
				break
				
	if has_node("AttackZone"):
		for body in $AttackZone.get_overlapping_bodies():
			if body.is_in_group("player"):
				is_attacking = true
				break

func _create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -55) # Căn giữa trên đầu quái
	health_bar.value = 100.0
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2
	sb_bg.corner_radius_bottom_right = 2
	
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.9, 0.2, 0.2, 1.0) # Màu đỏ
	sb_fill.corner_radius_top_left = 2
	sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2
	sb_fill.corner_radius_bottom_right = 2
	
	health_bar.add_theme_stylebox_override("background", sb_bg)
	health_bar.add_theme_stylebox_override("fill", sb_fill)
	
	add_child(health_bar)

func _physics_process(delta):
	if Engine.is_editor_hint(): return
	
	if is_dead:
		velocity.y += GRAVITY * delta # Xác chết vẫn rơi xuống đất
		move_and_slide()
		return
		
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player == null:
		if patrol_distance <= 0:
			velocity.x = 0
			anim.play("idle")
		else:
			_patrol_update()
			
		move_and_slide()
		return

	# Reset trạng thái tuần tra khi thấy người chơi để lúc mất dấu nó không bị kẹt
	is_patrol_waiting = false

	var facing_dir = 1
	var spawn_point = get_node_or_null("BulletSpawnPoint")
	
	if is_attacking:
		# Trong tầm bắn → đứng yên và bắn
		velocity.x = 0
		facing_dir = -1 if player.global_position.x < global_position.x else 1
		anim.flip_h = facing_dir < 0
		if spawn_point:
			spawn_point.scale.x = -1 if anim.flip_h else 1
		anim.play("shoot")
		if can_shoot and bullet_scene != null:
			_shoot()
	else:
		# Thấy player nhưng chưa trong tầm bắn → đuổi theo
		facing_dir = sign(player.global_position.x - global_position.x)
		
		# Dò vực
		var at_ledge = false
		if avoid_ledges and floor_raycast != null and is_on_floor():
			floor_raycast.position.x = facing_dir * 30.0 # Dịch tia dò lên phía trước 30px
			floor_raycast.force_raycast_update()
			if not floor_raycast.is_colliding():
				at_ledge = true
				
		if at_ledge:
			velocity.x = 0 # Đầu hàng vực thẳm, đứng lại
			anim.play("idle")
		else:
			velocity.x = facing_dir * speed
			anim.flip_h = facing_dir < 0
			if spawn_point:
				spawn_point.scale.x = -1 if anim.flip_h else 1
			anim.play("run")

	move_and_slide()

# --- Logic Tuần Tra ---
func _patrol_update():
	if is_patrol_waiting:
		velocity.x = 0
		anim.play("idle")
		return
		
	# Di chuyển tới mục tiêu
	velocity.x = patrol_dir * patrol_speed
	anim.flip_h = patrol_dir < 0
	anim.play("run")
	
	# Kiểm tra xem đã đến đích chưa
	var reached_target = false
	if patrol_dir == 1 and global_position.x >= patrol_target_x:
		reached_target = true
	elif patrol_dir == -1 and global_position.x <= patrol_target_x:
		reached_target = true
		
	# Hoặc bị vướng tường
	if is_on_wall():
		reached_target = true
		
	# Hoặc gặp mép vực sâu
	if avoid_ledges and floor_raycast != null and is_on_floor():
		floor_raycast.position.x = patrol_dir * 30.0 # Dời tia xuống phía trước
		floor_raycast.force_raycast_update()
		if not floor_raycast.is_colliding():
			reached_target = true
		
	if reached_target:
		_start_patrol_wait()

func _start_patrol_wait():
	is_patrol_waiting = true
	velocity.x = 0
	anim.play("idle")
	
	# Tính trước điểm đến tiếp theo
	patrol_dir *= -1
	patrol_target_x = start_x + patrol_distance * patrol_dir
	
	await get_tree().create_timer(patrol_wait_time).timeout
	is_patrol_waiting = false

func _shoot():
	can_shoot = false
	
	# Phát tiếng bắn
	_play_sfx(shoot_sfx)
	
	var bullet = bullet_scene.instantiate()
	get_parent().add_child(bullet)
	
	var spawn_point = get_node_or_null("BulletSpawnPoint")
	if spawn_point:
		bullet.global_position = spawn_point.global_position
	else:
		bullet.global_position = global_position
		
	bullet.direction = (player.global_position - global_position).normalized()
	
	# Xoay viên đạn theo hướng bay. 
	bullet.rotation = bullet.direction.angle()
	
	# Truyền bản thân enemy vào viên đạn để đạn có thể mượn loa phát tiếng nổ
	if "shooter" in bullet:
		bullet.shooter = self
	
	if "damage" in bullet:
		bullet.damage = bullet_damage
		
	if "speed" in bullet:
		bullet.speed = bullet_speed
		
	if "pass_terrain" in bullet:
		bullet.pass_terrain = bullet_pass_terrain
	await get_tree().create_timer(shoot_cooldown).timeout
	can_shoot = true

func take_damage(amount: float):
	if is_dead: return
	health -= amount
	
	if health_bar and max_health > 0:
		health_bar.value = (health / max_health) * 100.0
		
	if health <= 0:
		_die()

func _die():
	if is_dead: return
	is_dead = true
	
	# Phát tiếng chết
	_play_sfx(die_sfx)
	
	# Ẩn thanh máu
	if health_bar:
		health_bar.visible = false
		
	# Tắt hết va chạm để không cản đường đạn hay player nữa
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("DetectZone/CollisionShape2D"):
		$DetectZone/CollisionShape2D.set_deferred("disabled", true)
	if has_node("AttackZone/CollisionShape2D"):
		$AttackZone/CollisionShape2D.set_deferred("disabled", true)
		
	# Đổi animation sang chết
	if anim and anim.sprite_frames.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
		
	queue_free()

func play_explode_sfx():
	# Gọi hàm này từ bullet khi nó trúng player để phát tiếng nổ
	_play_sfx(explode_sfx)

func _play_sfx(stream: AudioStream):
	if stream and sfx_player:
		sfx_player.stream = stream
		sfx_player.play()

# --- Signals từ DetectZone ---
func _on_detect_zone_body_entered(body):
	if body.is_in_group("player"):
		player = body

func _on_detect_zone_body_exited(body):
	if body.is_in_group("player"):
		player = null

# --- Signals từ AttackZone ---
func _on_attack_zone_body_entered(body):
	if body.is_in_group("player"):
		is_attacking = true

func _on_attack_zone_body_exited(body):
	if body.is_in_group("player"):
		is_attacking = false

func _draw():
	if Engine.is_editor_hint():
		# Vòng Phát Hiện (Màu xanh ngọc trong suốt)
		if detect_radius > 0:
			draw_circle(Vector2.ZERO, detect_radius, Color(0.1, 0.8, 0.8, 0.2))
			
		# Vòng Tấn Công (Màu đỏ trong suốt)
		if attack_radius > 0:
			draw_circle(Vector2.ZERO, attack_radius, Color(0.9, 0.1, 0.3, 0.3))
			
		# Đường báo hiệu khoảng cách tuần tra (Patrol Distance)
		if patrol_distance > 0:
			var p_dist = patrol_distance
			# Vẽ 1 đường ngang mảnh
			draw_line(Vector2(-p_dist, 0), Vector2(p_dist, 0), Color.YELLOW, 1.0)
			# Vẽ 2 vạch chặn đứng ở 2 đầu
			draw_line(Vector2(-p_dist, -10), Vector2(-p_dist, 10), Color.YELLOW, 2.0)
			draw_line(Vector2(p_dist, -10), Vector2(p_dist, 10), Color.YELLOW, 2.0)
