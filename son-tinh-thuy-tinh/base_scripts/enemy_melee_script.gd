@tool
extends CharacterBody2D

# ---- Tốc độ gốc SpriteFrames (set trong editor) ----
const SPRITEFRAMES_SPEED = 60.0
const AUDIO_DURATION = 8.0  # Tất cả audio cắt từ video 8 giây

# Frame count PER ENEMY - đếm từ assets/sprites/{enemy}/
# Được dùng để tính speed_scale khớp audio 8 giây
# Key = tên scene file (con_ga, bach_tuot_tinh, ...), value = dict animation→frames
const ENEMY_FRAME_COUNTS = {
	"bach_tuot_tinh": {"attack": 172, "die": 144, "hurt": 135, "idle": 169, "run": 189},
	"bach-tuot-tinh": {"attack": 172, "die": 144, "hurt": 135, "idle": 169, "run": 189},
	"con_doi":        {"attack": 192, "die": 139, "fly": 192, "hurt": 192, "idle": 192, "move": 192},
	"con-doi":        {"attack": 192, "die": 139, "fly": 192, "hurt": 192, "idle": 192, "move": 192},
	"con_ga":         {"idle": 192},
	"con_ngua":       {"idle": 192},
	"con_voi":        {"idle": 192},
	"cua_tinh":       {"attack": 191, "die": 156, "hurt": 155, "idle": 184, "run": 192},
	"cua-tinh":       {"attack": 191, "die": 156, "hurt": 155, "idle": 184, "run": 192},
	"heo_rung":       {"attack": 192, "die": 121, "hurt": 192, "idle": 192, "run": 192},
	"heo-rung":       {"attack": 192, "die": 121, "hurt": 192, "idle": 192, "run": 192},
	"son_tinh":       {"attack": 192, "die": 156, "hurt": 185, "idle": 192, "run": 192},
	"son_tinh_con_my_nuong": {"die": 192, "idle": 192, "jump": 179, "run": 192},
	"son-tinh-con-my-nuong": {"die": 192, "idle": 192, "jump": 179, "run": 192},
	"thuy_tinh":      {"attack": 192, "die": 159, "hurt": 192, "idle": 192, "jump": 192, "run": 192},
	"tom_tinh":       {"attack": 192, "die": 160, "hurt": 127, "idle": 186, "run": 192},
	"tom-tinh":       {"attack": 192, "die": 160, "hurt": 127, "idle": 186, "run": 192},
}

@export var speed = 80.0
@export var health: float = 30.0
@export var attack_cooldown: float = 1.0
@export var melee_damage: float = 10.0
@export var attack_charge_speed: float = 0.0
@export var post_attack_rest_time: float = 0.0
@export var post_attack_lunge_distance: float = 0.0
@export var flip_sprite_default: bool = false
@export var attack_damage_on_last_frame: bool = false  ## Gây sát thương vào frame cuối của attack animation
@export var attack_damage_delay: float = 0.0  ## Delay (giây) từ lúc bắt đầu attack đến khi gây dame — chỉnh để khớp animation
@export var attack_hitbox_duration: float = 0.2  ## Thời gian hitbox mở (giây) — 0 = gây dame 1 lần rồi đóng

@export_category("Flying")
@export var can_fly: bool = false          ## Bật chế độ bay (vô hiệu hóa gravity)
@export var fly_speed: float = 80.0        ## Tốc độ bay đuổi player
@export var fly_preferred_distance: float = 0.0  ## Khoảng cách duy trì với player (0 = bay thẳng vào)
@export var fly_y_offset: float = 0.0      ## Dịch chỉnh độ cao bay (số dương = thấp xuống, âm = cao lên)
@export var fly_hover_amplitude: float = 30.0  ## Biên độ dao động (sóng sin)
@export var fly_hover_speed: float = 2.0   ## Tốc độ lượn (rad/s)
@export var fly_attack_rotation: float = 0.0   ## Góc xoay khi tấn công (degree, ví dụ -39.5)

@export_category("Patrol Settings")
@export var patrol_distance: float = 100.0 :
	set(value):
		patrol_distance = value
		queue_redraw()
@export var patrol_speed: float = 40.0
@export var patrol_wait_time: float = 1.5
@export var avoid_ledges: bool = true

@export_category("Chase & Retreat AI")
@export var always_chase: bool = false  ## Luôn đuổi player dù không có DetectZone
@export var retreat_after_attack: bool = false  ## Rút lùi sau khi tấn công
@export var retreat_time: float = 2.0  ## Thời gian rút lùi (giây)
@export var retreat_speed_multiplier: float = 1.2  ## Tốc độ rút lùi (×speed)

@export_category("Audio")
@export var override_audio_folder: String = ""  ## Để trống = tự tìm theo tên scene
@export var attack_sfx: AudioStream
@export var die_sfx: AudioStream
@export var hurt_sfx: AudioStream
@export var idle_sfx: AudioStream
@export var run_sfx: AudioStream
@export var fly_sfx: AudioStream
@export var move_sfx: AudioStream
@export var jump_sfx: AudioStream

@export_category("Detection Areas")
@export var detect_radius: float = 500.0 :
	set(value):
		detect_radius = value
		_update_shape("DetectZone", value)
		queue_redraw()

@export var attack_radius: float = 80.0 :
	set(value):
		attack_radius = value
		_update_shape("AttackZone", value)
		queue_redraw()

func _update_shape(zone_name: String, radius_value: float):
	if Engine.is_editor_hint() and is_inside_tree() and has_node(zone_name + "/CollisionShape2D"):
		# Tạo shape MỚI thay vì sửa trực tiếp resource gốc (tránh lỗi shared resource)
		var col_node = get_node(zone_name + "/CollisionShape2D")
		var new_shape = CircleShape2D.new()
		new_shape.radius = radius_value
		col_node.shape = new_shape

# State
var player = null
var can_attack = true
var is_attacking = false
var is_hurting = false  ## Đang chịu hurt, block _physics_process
var is_dead = false
var max_health: float = 1.0
var health_bar: ProgressBar = null
var _is_resting_after_attack: bool = false
var _is_attacking_damage: bool = false  ## Đang trong pha gây sát thương (sau windup)
var _is_retreating: bool = false         ## Đang rút lùi sau công kích

# Patrol
var start_x: float = 0.0
var patrol_target_x: float = 0.0
var patrol_dir: int = 1
var is_patrol_waiting: bool = false
var floor_raycast: RayCast2D = null

# Flying
var _fly_time: float = 0.0
var _fly_base_y: float = 0.0  # Y gốc khi spawn (dùng cho hover)

# Audio
var _sfx_cache: Dictionary = {}

# Cache enemy frame counts (resolved at _ready)
var _frame_counts: Dictionary = {}
var _enemy_key: String = ""

@onready var anim = $AnimatedSprite2D
@onready var sfx_player = $SFXPlayer

const GRAVITY = 900

# ---- Speed scale calculation ----

func _resolve_enemy_key() -> String:
	var base = scene_file_path.get_file().get_basename() if scene_file_path != "" else name.to_lower()
	if ENEMY_FRAME_COUNTS.has(base):
		return base
	# Thử đổi _ thành -
	var alt = base.replace("_", "-")
	if ENEMY_FRAME_COUNTS.has(alt):
		return alt
	return ""

func _calc_anim_speed_scale(anim_name: String) -> float:
	return 1.0

## Đặt hướng nhìn: facing_right=true → nhìn PHẢI, false → nhìn TRÁI
## Tự xử lý flip_sprite_default để không cần sửa từng chỗ
func _flip_toward(facing_right: bool) -> void:
	anim.flip_h = facing_right != flip_sprite_default


func _play_anim(anim_name: String, fast: bool = false):
	if not anim.sprite_frames.has_animation(anim_name):
		return
	# attack dùng speed_scale=3.0 (nhanh × 3)
	# tất cả animation khác dùng speed_scale=1.0 (60fps bình thường)
	if anim_name == "attack":
		anim.speed_scale = 3.0
	else:
		anim.speed_scale = 1.0
	if anim.animation != anim_name:
		anim.play(anim_name)

# ---- Lifecycle ----

func _ready():
	if Engine.is_editor_hint(): return

	_enemy_key = _resolve_enemy_key()
	if _enemy_key != "":
		_frame_counts = ENEMY_FRAME_COUNTS[_enemy_key]

	_load_audio_for_enemy()

	start_x = global_position.x
	patrol_target_x = start_x + patrol_distance * patrol_dir
	# _fly_base_y sẽ được set SAU await (để spawner kịp đặt vị trí)

	# Flying mode: tắt collision đất để quan sát thấy enemy bóng bay
	if can_fly:
		var col = get_node_or_null("CollisionShape2D")
		if col:
			# Giữ collision để bị tấn công được, chỉ bô gravity
			pass

	if detect_radius > 0 and has_node("DetectZone/CollisionShape2D"):
		var new_d = CircleShape2D.new()
		new_d.radius = detect_radius
		$DetectZone/CollisionShape2D.set_deferred("shape", new_d)

	if attack_radius > 0 and has_node("AttackZone/CollisionShape2D"):
		var new_a = CircleShape2D.new()
		new_a.radius = attack_radius
		$AttackZone/CollisionShape2D.set_deferred("shape", new_a)

	max_health = health
	_create_health_bar()

	if avoid_ledges:
		floor_raycast = RayCast2D.new()
		floor_raycast.target_position = Vector2(0, 50)
		floor_raycast.collision_mask = 1
		add_child(floor_raycast)

	await get_tree().physics_frame

	# Capture vị trí spawn SAU khi spawner đã đặt enemy đúng chỗ
	_fly_base_y = global_position.y
	start_x = global_position.x
	patrol_target_x = start_x + patrol_distance * patrol_dir

	# ── Kết nối signal bằng code (dự phòng nếu editor connection bị mất) ──
	if has_node("DetectZone"):
		var dz = $DetectZone
		dz.set_collision_mask_value(3, true)  # detect player (layer 3)
		if not dz.body_entered.is_connected(_on_detect_zone_body_entered):
			dz.body_entered.connect(_on_detect_zone_body_entered)
		if not dz.body_exited.is_connected(_on_detect_zone_body_exited):
			dz.body_exited.connect(_on_detect_zone_body_exited)
		# Kiểm tra body đã overlap sẵn
		for body in dz.get_overlapping_bodies():
			if _is_player(body):
				player = body
				break

	if has_node("AttackZone"):
		var az = $AttackZone
		az.set_collision_mask_value(3, true)  # detect player (layer 3)
		if not az.body_entered.is_connected(_on_attack_zone_body_entered):
			az.body_entered.connect(_on_attack_zone_body_entered)
		if not az.body_exited.is_connected(_on_attack_zone_body_exited):
			az.body_exited.connect(_on_attack_zone_body_exited)
		for body in az.get_overlapping_bodies():
			if _is_player(body):
				is_attacking = true
				break

	# ── Cho phép xuyên qua enemy khác ─────────────────────────────────
	# Dùng additive: KHÔNG ghi đè toàn bộ mask (giữ nguyên ground layer)
	# Chỉ thêm enemy vào layer 2 và xóa layer 2 ra khỏi mask
	# → enemy không block nhau, vẫn đứng trên ground (dù ground ở layer nào)
	set_collision_layer_value(2, true)   # enemy xuất hiện trên layer 2
	set_collision_layer_value(1, false)  # không phải layer 1
	set_collision_mask_value(2, false)   # không detect layer 2 (enemy khác)
	set_collision_mask_value(3, true)    # detect player (layer 3) → chặn nhau

## Kiểm tra body có phải player không (group hoặc script name)
func _is_player(body: Node) -> bool:
	if body.is_in_group("player"):
		return true
	# Dự phòng: kiểm tra tên script
	if body.get_script() != null:
		var sname = body.get_script().get_global_name()
		if sname in ["player", "player_map_3", "Player", "PlayerMap3"]:
			return true
	return false


# ---- Audio ----

func _load_audio_for_enemy():
	# Ưu tiên @export vars gán trực tiếp qua Inspector
	var export_map = {
		"attack": attack_sfx, "die": die_sfx, "hurt": hurt_sfx,
		"idle": idle_sfx, "run": run_sfx, "fly": fly_sfx,
		"move": move_sfx, "jump": jump_sfx
	}
	for key in export_map:
		if export_map[key] != null:
			_sfx_cache[key] = export_map[key]

	# Auto-load fallback từ folder cho các key chưa được gán
	var folder = override_audio_folder
	if folder == "":
		var base = scene_file_path.get_file().get_basename() if scene_file_path != "" else ""
		var candidates = [base, base.replace("_", "-"), base.replace("-", "_")]
		for candidate in candidates:
			var test_path = "res://assets/audio/character/%s" % candidate
			if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(test_path)):
				folder = candidate
				break

	if folder == "": return

	var anims = ["attack", "die", "hurt", "idle", "run", "fly", "move", "jump"]
	for anim_name in anims:
		if not _sfx_cache.has(anim_name):  # Chỉ load nếu chưa có từ export
			var path = "res://assets/audio/character/%s/%s.mp3" % [folder, anim_name]
			if ResourceLoader.exists(path):
				_sfx_cache[anim_name] = load(path)

func _play_sfx(anim_name: String):
	if not _sfx_cache.has(anim_name) or not sfx_player:
		return
	var stream = _sfx_cache[anim_name]
	var pitch = 1.0
	if _frame_counts.has(anim_name):
		var effective_fps = SPRITEFRAMES_SPEED * anim.speed_scale
		var anim_duration = _frame_counts[anim_name] / effective_fps
		pitch = clampf(AUDIO_DURATION / anim_duration, 0.1, 4.0)
	sfx_player.pitch_scale = pitch
	if sfx_player.stream == stream:
		# Cùng stream đang phát → restart ngay từ đầu, không stop() để tránh gap
		sfx_player.play()
	else:
		# Khác stream → dừng rồi đổi
		sfx_player.stop()
		sfx_player.stream = stream
		sfx_player.play()

# ---- Health bar ----

func _create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -55)
	health_bar.value = 100.0
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	sb_bg.corner_radius_top_left = 2; sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2; sb_bg.corner_radius_bottom_right = 2
	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.9, 0.2, 0.2, 1.0)
	sb_fill.corner_radius_top_left = 2; sb_fill.corner_radius_top_right = 2
	sb_fill.corner_radius_bottom_left = 2; sb_fill.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("background", sb_bg)
	health_bar.add_theme_stylebox_override("fill", sb_fill)
	add_child(health_bar)

# ---- Physics ----

func _physics_process(delta):
	if Engine.is_editor_hint(): return

	if is_dead:
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Đang chịu damage → không di chuyển hay override animation
	if is_hurting:
		velocity.x = 0
		move_and_slide()
		return

	# ---- CHẾ ĐỘ BAY ----
	if can_fly:
		_fly_time += delta
		_physics_flying(delta)
		return

	# ---- CHẾ ĐỘ BÌNH THƯỜNG (ground) ----
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	is_patrol_waiting = false

	# ── LUÔN CHASE: tìm player nếu chưa có ─────────────────────────
	if always_chase and player == null:
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			player = players[0]

	if player == null:
		if patrol_distance <= 0:
			velocity.x = 0
			_play_anim("idle", true)
		else:
			_patrol_update()
		move_and_slide()
		return

	# ── RÚT LÙI sau khi tấn công ────────────────────────────────────
	if _is_retreating:
		var retreat_dir = sign(global_position.x - player.global_position.x)  # ngược chiều player
		velocity.x = retreat_dir * speed * retreat_speed_multiplier
		_flip_toward(retreat_dir > 0)  # quay mặt theo hướng chạy lùi
		if anim.sprite_frames.has_animation("run"):
			_play_anim("run", true)
		else:
			_play_anim("idle", true)
		move_and_slide()
		return

	# Đứng chờ sau khi ủi xong (chỉ khi retreat_after_attack = false)
	if _is_resting_after_attack and not retreat_after_attack:
		velocity.x = 0
		_play_anim("idle", true)
		move_and_slide()
		return

	if is_attacking:
		# Lao về phía player nếu attack_charge_speed > 0 (ví dụ: heo ủi)
		if attack_charge_speed > 0 and player != null:
			var charge_dir = sign(player.global_position.x - global_position.x)
			velocity.x = charge_dir * attack_charge_speed
		else:
			velocity.x = 0
		var facing_dir = -1 if player.global_position.x < global_position.x else 1
		_flip_toward(facing_dir > 0)
		# Dịch hitbox về phía player: flip CollisionShape2D (con của MeleeHitbox)
		if has_node("MeleeHitbox/CollisionShape2D"):
			var col = $"MeleeHitbox/CollisionShape2D"
			col.position.x = abs(col.position.x) * facing_dir
		if _is_attacking_damage:
			# Pha gây sát thương: play attack animation
			if anim.sprite_frames.has_animation("attack"):
				_play_anim("attack")
			else:
				_play_anim("idle", true)
		elif can_attack:
			# Pha windup (chuẩn bị ủi): đứng yên với idle
			_play_anim("idle", true)
			_do_melee_attack()
		else:
			# Đang chờ cooldown → chỉ chuyển idle khi attack animation đã kết thúc
			if anim.animation != "attack":
				_play_anim("idle", true)
	else:
		var facing_dir = sign(player.global_position.x - global_position.x)
		var at_ledge = false
		if avoid_ledges and floor_raycast != null and is_on_floor():
			floor_raycast.position.x = facing_dir * 30.0
			floor_raycast.force_raycast_update()
			if not floor_raycast.is_colliding():
				at_ledge = true

		if at_ledge:
			velocity.x = 0
			_play_anim("idle", true)
		else:
			velocity.x = facing_dir * speed
			_flip_toward(facing_dir > 0)
			if anim.sprite_frames.has_animation("run"):
				_play_anim("run", true)
			elif anim.sprite_frames.has_animation("move"):
				_play_anim("move", true)
			elif anim.sprite_frames.has_animation("fly"):
				_play_anim("fly", true)
			else:
				_play_anim("idle", true)

	move_and_slide()

## Xử lý vật lý khi ở chế độ bay
func _physics_flying(delta: float) -> void:
	if player == null:
		# Lượn qua lại quanh vị trí spawn (patrol)
		if patrol_distance > 0:
			_patrol_fly_update()
		else:
			velocity.x = move_toward(velocity.x, 0, fly_speed)
			_play_anim("idle", true)
		# Dao động Y dạng sóng sin + offset độ cao
		var target_y = _fly_base_y + fly_y_offset + sin(_fly_time * fly_hover_speed) * fly_hover_amplitude
		velocity.y = (target_y - global_position.y) * 5.0
		move_and_slide()
		return

	is_patrol_waiting = false
	var h_dist = abs(player.global_position.x - global_position.x)  # Khoảng cách ngang

	if is_attacking:
		velocity = Vector2.ZERO
		var facing_dir = -1 if player.global_position.x < global_position.x else 1
		_flip_toward(facing_dir > 0)
		if has_node("MeleeHitbox/CollisionShape2D"):
			var col = $"MeleeHitbox/CollisionShape2D"
			col.position.x = abs(col.position.x) * facing_dir
		# Xoay về góc tấn công theo hướng: facing_dir làm cho dơi luôn cắm mũi vào player
		_set_fly_rotation(fly_attack_rotation * facing_dir)
		if anim.sprite_frames.has_animation("attack"):
			_play_anim("attack")
		else:
			_play_anim("idle", true)
		if can_attack:
			_do_melee_attack()
	else:
		# Reset góc về 0 khi không tấn công
		_set_fly_rotation(0.0)
		# ---- Trục X: giữ khoảng cách ngang preferred ----
		var vel_x: float = 0.0
		if fly_preferred_distance > 0:
			var diff = h_dist - fly_preferred_distance
			if abs(diff) < 20.0:
				vel_x = 0.0  # Trong vùng chấp nhận → đứng yên ngang
			elif diff > 0:
				# Xa hơn → tiến vào
				vel_x = sign(player.global_position.x - global_position.x) * fly_speed * min(diff / fly_preferred_distance, 1.0)
			else:
				# Gần hơn → lùi ra
				vel_x = -sign(player.global_position.x - global_position.x) * fly_speed * min(-diff / fly_preferred_distance, 1.0)
		else:
			# fly_preferred_distance = 0: bay thẳng vào player (chỉ X)
			vel_x = sign(player.global_position.x - global_position.x) * fly_speed
		velocity.x = vel_x
		_flip_toward(player.global_position.x > global_position.x)
		# Ưu tiên animation bay
		if anim.sprite_frames.has_animation("fly"):
			_play_anim("fly", true)
		elif anim.sprite_frames.has_animation("move"):
			_play_anim("move", true)
		else:
			_play_anim("idle", true)

	# ---- Trục Y: luôn hover sin quanh _fly_base_y (độc lập, không theo player) ----
	var target_y = _fly_base_y + fly_y_offset + sin(_fly_time * fly_hover_speed) * fly_hover_amplitude
	velocity.y = (target_y - global_position.y) * 5.0

	move_and_slide()

## Patrol khi bay (di chuyển ngang, sóng sin theo Y)
func _patrol_fly_update() -> void:
	var dir_x = sign(patrol_target_x - global_position.x)
	velocity.x = dir_x * (patrol_speed if patrol_speed > 0 else fly_speed * 0.5)
	_flip_toward(dir_x > 0)
	if anim.sprite_frames.has_animation("fly"):
		_play_anim("fly", true)
	elif anim.sprite_frames.has_animation("move"):
		_play_anim("move", true)
	# Y dao động sin
	var target_y = _fly_base_y + sin(_fly_time * fly_hover_speed) * fly_hover_amplitude
	velocity.y = (target_y - global_position.y) * 5.0
	# Đều hường patrol tương tự ground
	var reached = false
	if patrol_dir == 1 and global_position.x >= patrol_target_x: reached = true
	elif patrol_dir == -1 and global_position.x <= patrol_target_x: reached = true
	if reached:
		is_patrol_waiting = true
		velocity.x = 0
		patrol_dir *= -1
		patrol_target_x = start_x + patrol_distance * patrol_dir
		get_tree().create_timer(patrol_wait_time).timeout.connect(func(): is_patrol_waiting = false)

func _do_melee_attack():
	can_attack = false
	_is_attacking_damage = true
	_play_sfx("attack")

	# ── Chọn cơ chế căn thời gian dame ─────────────────────────
	if attack_damage_on_last_frame and anim.sprite_frames.has_animation("attack"):
		# Chờ hết animation rồi mới gây dame
		var frame_count = anim.sprite_frames.get_frame_count("attack")
		var anim_fps   = anim.sprite_frames.get_animation_speed("attack")
		var anim_duration = frame_count / (anim_fps * 3.0)
		await get_tree().create_timer(anim_duration).timeout
	elif attack_damage_delay > 0.0:
		# Chờ đúng số giây do người dùng cài (căn theo animation)
		await get_tree().create_timer(attack_damage_delay).timeout

	# Gây dame cho player
	if player and player.has_method("take_damage"):
		player.take_damage(melee_damage)

	# Reset pha dame NGAY SAU KHI dame xong — không chờ cooldown
	_is_attacking_damage = false

	# ── Sau khi tấn công: rút lùi NGAY (không đứng idle 3 giây) ───────
	if retreat_after_attack and retreat_time > 0.0:
		_is_retreating = true
		await get_tree().create_timer(retreat_time).timeout
		_is_retreating = false
	elif post_attack_rest_time > 0.0:
		_is_resting_after_attack = true
		await get_tree().create_timer(post_attack_rest_time).timeout
		_is_resting_after_attack = false

	# Chờ cooldown trước khi có thể tấn công lại
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	# Dịch chuyển chính xác n px về phía player sau khi damage xong
	if post_attack_lunge_distance > 0.0 and player != null:
		var lunge_dir = sign(player.global_position.x - global_position.x)
		var target_pos = global_position + Vector2(lunge_dir * post_attack_lunge_distance, 0)
		var tw = create_tween()
		tw.tween_property(self, "global_position", target_pos, 0.18).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
		# Đẩy player theo nếu đang gần (trong tầm ủi)
		var h_dist = abs(player.global_position.x - global_position.x)
		if h_dist < post_attack_lunge_distance * 1.2 and player.has_method("apply_knockback"):
			player.apply_knockback(Vector2(lunge_dir, -0.15).normalized(), 350.0)
		await tw.finished

## Tween g\u00f3c xoay m\u01b0\u1ee3t khi chuy\u1ec3n tr\u1ea1ng th\u00e1i bay
var _last_fly_rotation_target: float = 0.0
func _set_fly_rotation(target_deg: float) -> void:
	if abs(target_deg - _last_fly_rotation_target) < 0.5:
		return  # Kh\u00f4ng t\u1ea1o tween th\u1eeba
	_last_fly_rotation_target = target_deg
	var tw = create_tween()
	tw.tween_property(self, "rotation_degrees", target_deg, 0.25).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)

# ---- Patrol ----

func _patrol_update():
	if is_patrol_waiting:
		velocity.x = 0
		_play_anim("idle", true)
		return

	velocity.x = patrol_dir * patrol_speed
	# Sprite mặc định nhìn TRÁI → flip khi đi phải
	anim.flip_h = patrol_dir > 0
	if anim.sprite_frames.has_animation("run"):
		_play_anim("run", true)
	else:
		_play_anim("idle", true)

	var reached_target = false
	if patrol_dir == 1 and global_position.x >= patrol_target_x: reached_target = true
	elif patrol_dir == -1 and global_position.x <= patrol_target_x: reached_target = true
	if is_on_wall(): reached_target = true
	if avoid_ledges and floor_raycast != null and is_on_floor():
		floor_raycast.position.x = patrol_dir * 30.0
		floor_raycast.force_raycast_update()
		if not floor_raycast.is_colliding(): reached_target = true

	if reached_target:
		_start_patrol_wait()

func _start_patrol_wait():
	is_patrol_waiting = true
	velocity.x = 0
	_play_anim("idle", true)
	patrol_dir *= -1
	patrol_target_x = start_x + patrol_distance * patrol_dir
	await get_tree().create_timer(patrol_wait_time).timeout
	is_patrol_waiting = false

# ---- Damage ----

func take_damage(amount: float):
	if is_dead: return
	health -= amount
	if health_bar and max_health > 0:
		health_bar.value = (health / max_health) * 100.0
	if health <= 0:
		_die()
		return
	# Play hurt animation và block physics trong 0.4s
	if anim.sprite_frames.has_animation("hurt"):
		is_hurting = true
		_play_anim("hurt")
		_play_sfx("hurt")
		await get_tree().create_timer(0.4).timeout
		is_hurting = false

## Áp lực hất enemy theo hướng bất kỳ (dùng khi player kỹ năng)
func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead:
		return
	velocity += direction.normalized() * force

## Hất enemy đúng N pixel bằng Tween — không bị triệt tiêu bởi is_hurting
func apply_knockback_distance(direction: Vector2, distance_px: float, duration: float = 0.35) -> void:
	if is_dead:
		return
	var target_pos = global_position + direction.normalized() * distance_px
	var tw = create_tween()
	tw.tween_property(self, "global_position", target_pos, duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)


func _die():
	if is_dead: return
	is_dead = true
	_play_sfx("die")
	if health_bar: health_bar.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("DetectZone/CollisionShape2D"):
		$DetectZone/CollisionShape2D.set_deferred("disabled", true)
	if has_node("AttackZone/CollisionShape2D"):
		$AttackZone/CollisionShape2D.set_deferred("disabled", true)
	if has_node("MeleeHitbox/CollisionShape2D"):
		$MeleeHitbox/CollisionShape2D.set_deferred("disabled", true)
	if anim.sprite_frames.has_animation("die"):
		# Đảm bảo die animation không loop → animation_finished sẽ fire đúng
		anim.sprite_frames.set_animation_loop("die", false)
		_play_anim("die")
		await anim.animation_finished
	queue_free()


# ---- Signals ----

func _on_detect_zone_body_entered(body):
	if _is_player(body): player = body

func _on_detect_zone_body_exited(body):
	if _is_player(body): player = null

func _on_attack_zone_body_entered(body):
	if _is_player(body): is_attacking = true

func _on_attack_zone_body_exited(body):
	if _is_player(body): is_attacking = false

# ---- Editor draw ----

func _draw():
	if not Engine.is_editor_hint(): return
	if detect_radius > 0:
		draw_circle(Vector2.ZERO, detect_radius, Color(0.1, 0.8, 0.8, 0.2))
	if attack_radius > 0:
		draw_circle(Vector2.ZERO, attack_radius, Color(0.9, 0.1, 0.3, 0.3))
	if patrol_distance > 0:
		draw_line(Vector2(-patrol_distance, 0), Vector2(patrol_distance, 0), Color.YELLOW, 1.0)
		draw_line(Vector2(-patrol_distance, -10), Vector2(-patrol_distance, 10), Color.YELLOW, 2.0)
		draw_line(Vector2(patrol_distance, -10), Vector2(patrol_distance, 10), Color.YELLOW, 2.0)
