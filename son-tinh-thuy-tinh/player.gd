extends CharacterBody2D

const SPEED = 200
const JUMP_FORCE = -550
const GRAVITY = 900
const MAX_HEALTH = 500.0

@onready var anim = $AnimatedSprite2D
@onready var spawn_points_parent = $BulletSpawnPoints
@onready var spawn_point = $BulletSpawnPoints/BulletSpawnPoint
@onready var spawn_high = $BulletSpawnPoints/SpawnHigh
@onready var spawn_high_medium = $BulletSpawnPoints/SpawnHighMedium
@onready var spawn_normal = $BulletSpawnPoints/SpawnNormal
@onready var spawn_low = $BulletSpawnPoints/SpawnLow
@onready var hud = $HUD
@onready var sfx_player = $SFXPlayer        # Dùng cho âm thanh ngắn (bắn, nhảy, chết, bị đánh)
@onready var sfx_loop = $SFXPlayerLoop      # Dùng cho âm thanh lặp (chạy, đứng yên, cúi)

@export_category("Audio")
@export var shoot_sfx: AudioStream   # Tiếng bắn súng
@export var shoot_rapid_sfx: AudioStream # Tiếng bắn liên thanh (lặp)
@export var jump_sfx: AudioStream    # Tiếng nhảy lên
@export var run_sfx: AudioStream     # Tiếng chạy (lặp)
@export var idle_sfx: AudioStream    # Tiếng đứng yên thở (lặp)
@export var crouch_sfx: AudioStream  # Tiếng cúi xuống (lặp)
@export var hit_sfx: AudioStream     # Tiếng bị trúng đạn
@export var die_sfx: AudioStream     # Tiếng chết

@export_subgroup("Skill Audio")
@export var skill_volume_boost: float = 6.0   # Tăng âm lượng cho kỹ năng (dB)
@export var skill_q_sfx: AudioStream   # Âm thanh khi dùng Q
@export var skill_w_sfx: AudioStream   # Âm thanh khi dùng W
@export var skill_e_sfx: AudioStream   # Âm thanh khi dùng E
@export var skill_r_sfx: AudioStream   # Âm thanh khi dùng R

@export_category("Gun Settings")
@export var bullet_damage: float = 10.0        # Lực sát thương của đạn
@export var bullet_count: int = 1         # Số lượng đạn bắn ra mỗi lần click
@export var bullet_speed: float = 800.0     # Tốc độ đạn
@export var bullet_spread: float = 15.0   # Độ tỏa (chùm) của đạn nếu bắn nhiều viên (độ)

@export_category("Dash Settings")
@export var dash_speed: float = 800.0     # Tốc độ lướt
@export var dash_duration: float = 0.2    # Thời gian lướt

var is_dashing = false
var dash_timer = 0.0
var dash_direction = 0
var dash_velocity_2d = Vector2.ZERO

@export_category("Skills")
# Gắn cứng kỹ năng vào Player, không cho phép Level đè bẹp qua Inspector
var skill_q_scene: PackedScene = preload("res://scenes/player/skills/skill_q_effect.tscn")
var skill_e_scene: PackedScene = preload("res://scenes/player/skills/skill_e_effect.tscn")
var skill_r_scene: PackedScene = preload("res://scenes/player/skills/skill_r_effect.tscn")

# Cooldown gốc
@export var skill_q_cooldown: float = 3.0
@export var skill_w_cooldown: float = 5.0
@export var skill_e_cooldown: float = 8.0
@export var skill_r_cooldown: float = 15.0

@export_subgroup("Skill Damage")
@export var skill_q_damage: float = 20.0
@export var skill_r_damage: float = 100.0

# Timer đếm ngược (cooldown - đếm từ max về 0)
var skill_q_timer: float = 0.0
var skill_w_timer: float = 0.0
var skill_e_timer: float = 0.0
var skill_r_timer: float = 0.0

# Timer kỹ năng W đang hoạt động (active duration)
var skill_w_active_timer: float = 0.0
var skill_w_active: bool = false  # true khi W đang cường hóa tốc độ bắn

var is_casting_skill = false
var cast_timer: float = 0.0

var shoot_timer: float = 0.0
var is_shooting = false
var is_aiming_q = false
var is_jump = false
var is_hit = false
var is_crouching = false
var health: float = 500.0
var is_dead = false
var pause_menu_ref: Node = null
var score = 0
var bullet_scene = preload("res://scenes/player/player_bullet.tscn")

# Giới hạn map
var limit_left_x: float = 0.0
var limit_right_x: float = 9999999.0

func heal(amount: float):
	health = min(health + amount, MAX_HEALTH)
	if hud:
		hud.update_health(health)

func _ready():
	if hud:
		hud.set_max_health(500)
		hud.update_health(health)
		hud.update_score(score)

func add_score(amount: int):
	score += amount
	if hud:
		hud.update_score(score)


func _input(event):
	if is_dead:
		return
		
	if event.is_action_pressed("ui_cancel"):
		_show_pause_menu()

func _show_pause_menu():
	# Kiểm tra nếu menu đã tồn tại thì không tạo thêm
	if pause_menu_ref and is_instance_valid(pause_menu_ref):
		return
		
	var pause_menu_scene = preload("res://ui/menus/pause_menu.tscn")
	pause_menu_ref = pause_menu_scene.instantiate()
	get_tree().root.add_child(pause_menu_ref)
	get_tree().paused = true

func _physics_process(delta):
	if is_dead:
		velocity.x = 0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Trừ thời gian hồi chiêu
	if skill_q_timer > 0: skill_q_timer -= delta
	if skill_w_timer > 0: skill_w_timer -= delta
	if skill_e_timer > 0: skill_e_timer -= delta
	if skill_r_timer > 0: skill_r_timer -= delta
	
	# Đếm ngược thời gian W đang active (5s aura)
	if skill_w_active_timer > 0:
		skill_w_active_timer -= delta
		if hud:
			hud.update_skill_active("w", skill_w_active_timer, 5.0)
		if skill_w_active_timer <= 0:
			_deactivate_w_effect()
	
	if is_casting_skill:
		cast_timer -= delta
		velocity.x = 0 # Đứng lại khi cast skill
		velocity.y += GRAVITY * delta
		move_and_slide()
		if cast_timer <= 0:
			is_casting_skill = false
		return # Bỏ qua tất cả logic di chuyển/bắn súng khác khi đang cast skill
		
	# Xử lý thời gian lướt
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0:
			is_dashing = false
			dash_velocity_2d = Vector2.ZERO
			# Khôi phục tốc độ animation về bình thường
			anim.speed_scale = 1.0
	if is_shooting:
		shoot_timer -= delta
		if shoot_timer <= 0:
			is_shooting = false
			# Ẩn tia lửa súng khi ngừng bắn
			var rapid_fire_flash = get_node_or_null("ShootRapidFireEffect")
			if rapid_fire_flash:
				rapid_fire_flash.visible = false
			# Dừng âm thanh bắn liên thanh
			_stop_loop_sfx()

	if not is_on_floor() and not is_dashing:
		velocity.y += GRAVITY * delta

	# KHÓA HÀNH ĐỘNG NẾU ĐANG GỒNG CHIÊU
	if is_casting_skill:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		return
		
	var direction = Input.get_axis("ui_left", "ui_right")
	var is_pressing_shoot = Input.is_action_pressed("click")
	var is_just_pressing_shoot = Input.is_action_just_pressed("click")
	
	# --- Kỹ năng W (Có thể dùng trong bất kỳ trường hợp nào) ---
	if Input.is_action_just_pressed("skill_w") and skill_w_timer <= 0 and not skill_w_active:
		# Cast W internally (Aura directly on Player, lasts 5s)
		# Không set is_casting_skill = true để không bị ngắt các hành động khác
		var w_effect = $SkillWEffect
		var w_anim = w_effect.get_node("AnimatedSprite2D")
		w_anim.visible = true
		w_anim.play("default")
		
		if anim.flip_h:
			w_anim.flip_h = true
		else:
			w_anim.flip_h = false
		
		# Bắt đầu active duration 5s, đặt cooldown sau khi hết
		skill_w_active_timer = 5.0  # Cố định 5s active theo yêu cầu
		skill_w_timer = 0.0          # Chưa tính cooldown vội
		skill_w_active = true  # Kích hoạt tăng tốc bắn
		_play_sfx(skill_w_sfx, skill_volume_boost)
		if hud:
			hud.set_skill_active("w")
	
	if is_pressing_shoot or is_shooting:
		velocity.x = 0
	elif is_dashing:
		if dash_velocity_2d != Vector2.ZERO: # Lướt tự do (Skill E)
			velocity = dash_velocity_2d
		else: # Lướt ngang (Dash thường)
			velocity.x = dash_direction * dash_speed
			velocity.y = 0 # Khi lướt giữ nguyên độ cao
	else:
		velocity.x = direction * SPEED

	if direction != 0 and not is_pressing_shoot and not is_shooting and not is_dashing:
		anim.flip_h = direction < 0
		if anim.flip_h:
			spawn_points_parent.scale.x = -1
		else:
			spawn_points_parent.scale.x = 1

	# Nhảy
	# Mới: Chỉ cho phép nhảy nếu không đè nút bắn (trên mặt đất) và không đang lướt
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_pressing_shoot and not is_dashing:
		velocity.y = JUMP_FORCE
		_play_sfx(jump_sfx)

	# Bắn súng thường
	if is_pressing_shoot and not is_shooting and not is_dashing and not is_aiming_q:
		is_shooting = true

		var mouse_pos = get_global_mouse_position()
		var direction_bullet = (mouse_pos - global_position).normalized()

		anim.flip_h = mouse_pos.x < global_position.x
		if anim.flip_h:
			spawn_points_parent.scale.x = -1
		else:
			spawn_points_parent.scale.x = 1
		
		# Tính góc từ player đến chuột (theo trục X ngang), đơn vị degrees
		# Chú ý: Y tăng xuống, nên góc âm = bắn lên cao
		var delta_x = abs(mouse_pos.x - global_position.x)
		var delta_y = mouse_pos.y - global_position.y # ām = lên cao
		var angle_deg = 0.0
		if delta_x > 0 or delta_y != 0:
			# độ nghịng so với mặt phẳng ngang. âm = hướng lên
			angle_deg = rad_to_deg(atan2(-delta_y, delta_x))
		
		var target_anim: String
		var active_spawn: Marker2D
		
		# Không cho bắn nếu góc nằm ngoài khoảng cho phép (> 60° hoặc < -60°)
		if angle_deg > 60 or angle_deg < -60:
			is_shooting = false  # Hủy trạng thái bắn
		elif angle_deg > 30:
			# Bắn lên chéo cao (30° - 60°)
			target_anim = "shoot_high"
			active_spawn = spawn_high
		elif angle_deg > 20:
			# Bắn lên chéo trung bình (20° - 45°)
			target_anim = "shoot_high_medium"
			active_spawn = spawn_high_medium
		elif angle_deg >= -15:
			# Bắn ngang hoặc hơi chéo (-15° - 20°)
			if (Input.is_action_pressed("click") and not Input.is_action_just_pressed("click")) or skill_w_active:
				target_anim = "shoot_rapid_fire"
			else:
				target_anim = "shoot"
			active_spawn = spawn_normal
		else:
			# Bắn chéo xuống (-60° đến -15°)
			target_anim = "shoot_low"
			active_spawn = spawn_low
		
		if is_shooting and anim.animation != target_anim:
			anim.play(target_anim)
			anim.speed_scale = 2.5  # Tăng tốc độ animation khi bắn
			
		# Chỉ bắt đầu bắn nếu góc hợp lệ
		if is_shooting:
			# Bật/Tắt Tia Lửa Đầu Súng (Muzzle Flash)
			var rapid_fire_flash = get_node_or_null("ShootRapidFireEffect")
			if rapid_fire_flash:
				# Chỉ hiện tia lửa và chơi âm thanh liên thanh nếu ĐÈ chuột (không phải vừa mới CLICK phát đầu)
				# Hoặc nếu đang trong trạng thái Skill W (mặc định là liên thanh)
				if (Input.is_action_pressed("click") and not Input.is_action_just_pressed("click")) or skill_w_active:
					rapid_fire_flash.visible = true
					rapid_fire_flash.global_position = active_spawn.global_position
					rapid_fire_flash.rotation = direction_bullet.angle()
					
					var flash_anim = rapid_fire_flash.get_node_or_null("AnimatedSprite2D")
					if flash_anim:
						flash_anim.flip_v = anim.flip_h
						flash_anim.play("default")
					
					_play_loop_sfx(shoot_rapid_sfx)
				else:
					# Phát tiếng đơn cho phát súng đầu tiên hoặc khi nhắp chuột lẻ
					rapid_fire_flash.visible = false
					_play_sfx(shoot_sfx)
					_stop_loop_sfx()

			# --- Xử lý thông số đạn khi có Skill W ---
			var current_damage = 15.0 if skill_w_active else bullet_damage
			var current_count = 3 if skill_w_active else bullet_count
			var current_spread = 60.0 if skill_w_active else bullet_spread
			
			# Tính toán góc bắn chùm (Spread)
			var base_angle = direction_bullet.angle()
			var spread_rad = deg_to_rad(current_spread)
			
			var start_angle = base_angle
			if current_count > 1:
				start_angle = base_angle - (spread_rad / 2.0)
				
			var angle_step = 0.0
			if current_count > 1:
				angle_step = spread_rad / (current_count - 1)

			for i in range(current_count):
				var final_angle = start_angle + (angle_step * i)
				var final_dir = Vector2.RIGHT.rotated(final_angle)
				
				var bullet = bullet_scene.instantiate()
				get_parent().add_child(bullet)
				
				bullet.global_position = active_spawn.global_position
				bullet.direction = final_dir
				bullet.rotation = final_angle
				bullet.speed = bullet_speed
				bullet.damage = current_damage
				
				# Gán player làm shooter để bullet có thể gọi hàm heal() khi trúng quái
				if "shooter" in bullet:
					bullet.shooter = self

			# Tốc độ bắn tăng x2 khi W đang active
			shoot_timer = 0.15 if skill_w_active else 0.3

	# Cúi
	var was_crouching = is_crouching
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor() and not is_dashing
	if is_crouching:
		velocity.x = 0
		if not was_crouching:
			if $CollisionShape2D.shape is CapsuleShape2D:
				$CollisionShape2D.shape.height = 52.0
			$CollisionShape2D.position.y = 6.0
	else:
		if was_crouching:
			if $CollisionShape2D.shape is CapsuleShape2D:
				$CollisionShape2D.shape.height = 70.0
			$CollisionShape2D.position.y = -3.0

	if Input.is_action_just_pressed("skill_r"):
		print(">>> Phat hien ban phim go nut R! (is_shooting: ", is_shooting, ", is_on_floor: ", is_on_floor(), ", is_dashing: ", is_dashing, ")")

	# Ngắm Q: Kích hoạt chế độ ngắm
	if is_on_floor() and not is_dashing and not is_shooting and not is_crouching and not is_aiming_q:
		if Input.is_action_just_pressed("skill_q") and skill_q_timer <= 0:
			is_aiming_q = true
			# Trả về luôn để tránh kích nổ Q trong cùng 1 frame nếu lỡ tay bấm chuột
			return

	# Bắn Q nếu đang trong chế độ ngắm và click chuột trái
	if is_aiming_q:
		if is_just_pressing_shoot:
			is_aiming_q = false
			var mouse_pos = get_global_mouse_position()
			anim.flip_h = mouse_pos.x < global_position.x
			if anim.flip_h:
				spawn_points_parent.scale.x = -1
			else:
				spawn_points_parent.scale.x = 1
				
			var delta_x = abs(mouse_pos.x - global_position.x)
			var delta_y = mouse_pos.y - global_position.y
			var angle_deg = 0.0
			if delta_x > 0 or delta_y != 0:
				angle_deg = rad_to_deg(atan2(-delta_y, delta_x))
				
			var target_anim: String
			var active_spawn: Marker2D
			
			if angle_deg > 60 or angle_deg < -60:
				pass # Out of range, do nothing
			else:
				if angle_deg > 30:
					target_anim = "shoot_high"
					active_spawn = spawn_high
				elif angle_deg > 20:
					target_anim = "shoot_high_medium"
					active_spawn = spawn_high_medium
				elif angle_deg >= -15:
					target_anim = "shoot"
					active_spawn = spawn_normal
				else:
					target_anim = "shoot_low"
					active_spawn = spawn_low
				
				_cast_skill(skill_q_scene, skill_q_cooldown, target_anim, active_spawn, 0.0, 0.5, skill_q_damage, mouse_pos, skill_q_sfx)
				skill_q_timer = skill_q_cooldown
				if hud:
					hud.start_skill_cooldown("q", skill_q_cooldown)
				return # Tránh kích hoạt đạn thường
		elif Input.is_action_just_pressed("ui_cancel") or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_action_just_pressed("dash"):
			# Hủy ngắm Q
			is_aiming_q = false

	# Nhận nút Kỹ năng (Q, E, R)
	if is_on_floor() and not is_dashing and not is_shooting and not is_crouching and not is_aiming_q:
		if Input.is_action_just_pressed("skill_e") and skill_e_timer <= 0:
			# Kỹ năng E: Lướt NGANG theo phía chuột trên trục X
			is_dashing = true
			dash_timer = dash_duration
			var mouse_pos = get_global_mouse_position()
			var h_dir = sign(mouse_pos.x - global_position.x) # Chỉ lấy hướng ngang
			if h_dir == 0:
				h_dir = -1 if anim.flip_h else 1 # Fallback nếu trỏ ngay giữa người
				
			dash_velocity_2d = Vector2(h_dir * dash_speed, 0)
			
			# Lật mặt nhân vật theo hướng lướt
			anim.flip_h = (h_dir < 0)
			if anim.flip_h:
				spawn_points_parent.scale.x = -1
			else:
				spawn_points_parent.scale.x = 1
				
			anim.speed_scale = 2.0
			anim.play("dash")
			_stop_loop_sfx()
			_play_sfx(skill_e_sfx, skill_volume_boost)
			skill_e_timer = skill_e_cooldown
			if hud:
				hud.start_skill_cooldown("e", skill_e_cooldown)
		elif Input.is_action_just_pressed("skill_r") and skill_r_timer <= 0:
			var mouse_pos = get_global_mouse_position()
			anim.flip_h = mouse_pos.x < global_position.x
			if anim.flip_h:
				spawn_points_parent.scale.x = -1
			else:
				spawn_points_parent.scale.x = 1
				
			var delta_x = abs(mouse_pos.x - global_position.x)
			var delta_y = mouse_pos.y - global_position.y
			var angle_deg = 0.0
			if delta_x > 0 or delta_y != 0:
				angle_deg = rad_to_deg(atan2(-delta_y, delta_x))
				
			var target_anim: String
			var active_spawn: Marker2D
			
			if angle_deg > 60 or angle_deg < -60:
				pass # Out of range, do nothing
			else:
				if angle_deg > 30:
					target_anim = "shoot_high"
					active_spawn = spawn_high
				elif angle_deg > 20:
					target_anim = "shoot_high_medium"
					active_spawn = spawn_high_medium
				elif angle_deg >= -15:
					target_anim = "shoot"
					active_spawn = spawn_normal
				else:
					target_anim = "shoot_low"
					active_spawn = spawn_low
				
				var direction_bullet = (mouse_pos - global_position).normalized()
				var final_angle = direction_bullet.angle()
				if anim.flip_h:
					# Khi lật x = -1, góc quay sẽ bị ngược so với màn hình, cần phải bù PI vào góc
					final_angle -= PI
					
				_cast_skill(skill_r_scene, skill_r_cooldown, target_anim, active_spawn, final_angle, 0.6, skill_r_damage, Vector2.INF, skill_r_sfx)
				skill_r_timer = skill_r_cooldown
				if hud:
					hud.start_skill_cooldown("r", skill_r_cooldown)

	# Nhận nút Lướt (Dash)
	if Input.is_action_just_pressed("dash") and skill_e_timer <= 0 and not is_dashing and not is_shooting and not is_crouching:
		is_dashing = true
		dash_timer = dash_duration
		dash_velocity_2d = Vector2.ZERO
		# Lướt theo hướng con trỏ chuột nếu không bấm hướng, nếu không thì theo trục X (hướng mặt)
		dash_direction = -1 if anim.flip_h else 1
		# Nếu người chơi bấm hướng thì lướt theo hướng đang bấm
		if direction != 0:
			dash_direction = sign(direction)

		anim.speed_scale = 2.0 # Tốc độ animation x2
		anim.play("dash")
		_stop_loop_sfx()
		_play_sfx(skill_e_sfx, skill_volume_boost)
		
		# Tính cooldown cho dash thường bằng cooldown của E
		skill_e_timer = skill_e_cooldown
		if hud:
			hud.start_skill_cooldown("e", skill_e_cooldown)

	# Animation + âm thanh trạng thái (looping)
	if not is_shooting and not is_hit and not is_dashing and not is_casting_skill:
		if is_crouching:
			if anim.animation != "crouch":
				anim.play("crouch")
				anim.speed_scale = 4.0
				_play_loop_sfx(crouch_sfx)
		elif not is_on_floor():
			if anim.animation != "jump":
				anim.play("jump")
				anim.speed_scale = 1.0
				_stop_loop_sfx()
		elif direction != 0:
			if anim.animation != "run":
				anim.play("run")
				anim.speed_scale = 1.0
				_play_loop_sfx(run_sfx)
		else:
			if anim.animation != "idle":
				anim.play("idle")
				anim.speed_scale = 1.0
				_play_loop_sfx(idle_sfx)

	move_and_slide()
	
	# Ngăn không cho nhân vật chạy ra khỏi ranh giới màn hình
	if global_position.x < limit_left_x:
		global_position.x = limit_left_x
	elif global_position.x > limit_right_x:
		global_position.x = limit_right_x

# --- Hàm Cast Skill Chung ---
func _cast_skill(skill_scene: PackedScene, cooldown: float, cast_anim: String, spawn_marker: Marker2D = null, base_angle: float = 0.0, custom_cast_time: float = 0.5, skill_damage: float = 0.0, custom_spawn_pos: Vector2 = Vector2.INF, skill_sfx: AudioStream = null):
	is_casting_skill = true
	# Cộng thêm 0.38s giữ dáng (post-cast delay) sau khi gồng chiêu xong
	cast_timer = custom_cast_time + 0.38
	
	# Phát âm thanh Kỹ năng ngay lập tức khi bắt đầu gồng chiêu
	if skill_sfx:
		_play_sfx(skill_sfx, skill_volume_boost)
		
	anim.play(cast_anim)
	
	if skill_scene:
		# Đợi khoảng thời gian custom_cast_time trước khi thực sự bắn skill ra
		if custom_cast_time > 0:
			await get_tree().create_timer(custom_cast_time).timeout
			
		# Khởi tạo lại các giá trị vị trí phòng trường hợp nhân vật di chuyển (nếu bị đẩy, v.v.)
		# Hoặc nếu người chơi bấm lật mặt trong lúc niệm
		
		print(">>> Dang ban Skill: ", skill_scene.resource_path)
		var skill_instance = skill_scene.instantiate()
		
		# Khởi tạo target_pos cho kỹ năng (như Skill Q) nếu có điểm custom_spawn_pos (nhập từ chuột)
		if "target_pos" in skill_instance and custom_spawn_pos != Vector2.INF:
			skill_instance.target_pos = custom_spawn_pos
			
		if spawn_marker:
			skill_instance.global_position = spawn_marker.global_position
			skill_instance.rotation = base_angle
		else:
			# Vị trí spawn trước mặt player (fallback)
			var offset_x = 80 if not anim.flip_h else -80
			skill_instance.global_position = global_position + Vector2(offset_x, -10)
		
		print(">>> Da them Skill vao Scene, Toa do: ", skill_instance.global_position)
		
		# Truyền hướng mặt vào Skill (nếu skill có hỗ trợ lật hình)
		if "is_player_facing_right" in skill_instance:
			skill_instance.is_player_facing_right = not anim.flip_h
			
		# Truyền sát thương vào Skill (nếu có thiết lập trên Player)
		if skill_damage > 0:
			if "damage_per_second" in skill_instance:
				skill_instance.damage_per_second = skill_damage
			elif "damage" in skill_instance:
				skill_instance.damage = skill_damage
				
		# Thêm vào scene sau khi đã cài đặt xong các thông số để hàm _ready() bên kia nhận được
		get_parent().add_child(skill_instance)

# --- Hàm thiết lập Ranh Giới (Nhận từ LevelBounds) ---
func set_left_bound(x_pos: float):
	limit_left_x = x_pos
	var cam = $Camera2D
	if cam:
		cam.limit_left = int(x_pos)

func set_right_bound(x_pos: float):
	limit_right_x = x_pos
	var cam = $Camera2D
	if cam:
		cam.limit_right = int(x_pos)

# --- Hàm phát âm thanh ---
func _play_sfx(stream: AudioStream, volume_db: float = 0.0):
	if stream and sfx_player:
		if sfx_player.playing:
			var temp_player = AudioStreamPlayer.new()
			temp_player.stream = stream
			temp_player.bus = "SFX"
			temp_player.volume_db = volume_db
			add_child(temp_player)
			temp_player.play()
			temp_player.finished.connect(temp_player.queue_free)
		else:
			sfx_player.stream = stream
			sfx_player.volume_db = volume_db
			sfx_player.play()

func _play_loop_sfx(stream: AudioStream, volume_db: float = 0.0):
	if stream and sfx_loop:
		if sfx_loop.stream == stream and sfx_loop.playing:
			return  # Đang phát rồi, không bật lại
		sfx_loop.stream = stream
		sfx_loop.volume_db = volume_db
		sfx_loop.play()

func _stop_loop_sfx():
	if sfx_loop and sfx_loop.playing:
		sfx_loop.stop()

# --- Nhận sát thương ---
func take_damage(amount):
	if is_hit:
		return
	health -= amount
	if hud:
		hud.update_health(health)

	# Bỏ qua hoạt ảnh bị đánh (hit) nếu đang gồng chiêu thức
	if not is_casting_skill:
		is_hit = true
		anim.play("hit")
		_play_sfx(hit_sfx)
		await get_tree().create_timer(0.4).timeout
		is_hit = false
	else:
		# Chỉ phát âm thanh trúng đòn mà không đổi hoạt ảnh
		_play_sfx(hit_sfx)
		
	if health <= 0:
		die()

func die():
	if is_dead:
		return
	is_dead = true
	_play_sfx(die_sfx)
	_stop_loop_sfx() # Dừng các âm thanh lặp như chạy/thở
	
	# Chơi animation chết
	anim.play("die")
	
	# Tạm dừng toàn bộ game (kẻ địch và đạn sẽ đứng yên)
	get_tree().paused = true
	# Cho phép Player tiếp tục hoạt động để hoàn thành animation
	self.process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Đợi animation chết kết thúc
	await anim.animation_finished
	
	# Hiện UI Game Over
	var game_over_scene = preload("res://ui/menus/game_over.tscn")
	var game_over_instance = game_over_scene.instantiate()
	get_tree().root.add_child(game_over_instance)
	
	print("Player died. Showing Game Over UI.")

# --- Skill W Signals ---

func _on_skill_w_anim_finished():
	# Khi animation kết thúc 1 lần, tự play lại nếu còn trong active duration
	var w_effect = $SkillWEffect
	if w_effect and skill_w_active_timer > 0:
		var w_anim = w_effect.get_node_or_null("AnimatedSprite2D")
		if w_anim:
			w_anim.play("default")

# Tắt hiệu ứng W khi hết 5 giây
func _deactivate_w_effect():
	skill_w_active = false  # Tắt tăng tốc bắn
	var w_effect = $SkillWEffect
	if w_effect:
		var w_anim = w_effect.get_node_or_null("AnimatedSprite2D")
		if w_anim:
			w_anim.visible = false
			w_anim.stop()
	
	# Sau 5s active mới bắt đầu tính cooldown
	skill_w_timer = skill_w_cooldown
	if hud:
		hud.start_skill_cooldown("w", skill_w_cooldown)
