extends CharacterBody2D

const SPEED = 200
const JUMP_FORCE = -550
const GRAVITY = 900

# Tốc độ gốc của SpriteFrames (set trong editor)
const SPRITEFRAMES_SPEED = 60.0
# Audio của tất cả animation đều 8 giây (cắt từ video 8s)
const AUDIO_DURATION = 8.0
# Số frame thực tế (đếm từ folder assets\sprites\son-tinh)
const ANIM_FRAME_COUNTS = {
	"attack": 192, "crouch": 192, "die": 156,
	"hurt": 185, "idle": 192, "jump": 192,
	"run": 192, "skill_w": 191, "skill_e": 192, "skill_r": 192
}

@onready var anim = $AnimatedSprite2D
@onready var melee_hitbox: Area2D = $MeleeHitbox
@onready var melee_hitbox_high: Area2D = $MeleeHitboxHigh  ## Hitbox cho đòn đánh cao (attack_high)
@onready var skill_r_hitbox: Area2D = $SkillRHitbox         ## Hitbox kỹ năng R
var camera: Camera2D = null

## Loại đòn đang dùng: "normal" hoặc "high"
var _attack_type: String = "normal"
@onready var sfx_player = $SFXPlayer
@onready var sfx_loop = $SFXPlayerLoop

# ---- Combat Exports ----
@export_category("Combat")
@export var attack_damage: float = 20.0
@export var attack_hitbox_delay: float = 0.25       ## [Attack] Delay (giây) trước khi hitbox bật
@export var attack_high_hitbox_delay: float = 0.20  ## [AttackHigh] Delay trước khi hitbox bật
@export var skill_r_hitbox_delay: float = 0.30       ## [SkillR] Delay trước khi hitbox bật
@export var skill_r_damage: float = 50.0             ## Sát thương kỹ năng R

# ---- Audio Exports (gán trực tiếp qua Inspector hoặc .tscn) ----
@export_category("Audio")
@export var jump_sfx: AudioStream
@export var run_sfx: AudioStream
@export var idle_sfx: AudioStream
@export var hit_sfx: AudioStream
@export var die_sfx: AudioStream
@export var attack_sfx: AudioStream
@export var crouch_sfx: AudioStream
@export var skill_w_sfx: AudioStream
@export var skill_e_sfx: AudioStream

# Audio cache (auto-load fallback)
var _sfx_cache: Dictionary = {}
var _prev_anim: String = ""
# Track bodies already hit in current swing (reset mỗi khi swing)
var _attacked_bodies: Array = []

# Health & State
var max_health: float = 3000.0   ## Tạm thời tăng để test
var current_health: float = 3000.0
var is_dead: bool = false
var is_attacking: bool = false
var is_hurting: bool = false  ## Đang nhận damage, block _physics_process
var is_crouching: bool = false
var is_skill_active: bool = false
var _is_invincible: bool = false
var _is_super_armor: bool = false  ## Skill R: chịu đòn nhưng không bị gián đoạn

# Health + Lives HUD
var _player_hud: PlayerHUD = null
var _hud_scene: PackedScene = preload("res://scenes/player/player_hud.tscn")

# Camera bounds
var limit_left_x: float = -10000.0
var limit_right_x: float = 10000.0

# Collision standing values (saved from .tscn in _ready)
var _col_stand_y: float = -49.0   # giá trị từ editor
var _col_stand_h: float = 100.0   # giá trị từ editor

# ---- Lifecycle ----

func _ready():
	add_to_group("player")  # Đảm bảo luôn trong group "player" cho enemy always_chase
	# Lưu giá trị gốc từ editor, duplicate shape để tránh shared resource
	if $CollisionShape2D.shape:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		if $CollisionShape2D.shape is RectangleShape2D:
			_col_stand_y = $CollisionShape2D.position.y
			_col_stand_h = $CollisionShape2D.shape.size.y

	# ── Collision layer setup ──────────────────────────────────────────
	# Dùng additive: giữ nguyên mask gốc, chỉ điều chỉnh layer player
	set_collision_layer_value(3, true)   # player ở layer 3
	set_collision_layer_value(1, false)  # bỏ khỏi layer 1
	set_collision_mask_value(2, true)    # detect enemy (layer 2) → chặn nhau

	# Tạo Camera2D nếu chưa có trong scene
	if not has_node("Camera2D"):
		var cam = Camera2D.new()
		cam.name = "Camera2D"
		cam.position = Vector2(0, 0)
		cam.zoom = Vector2(1, 1)
		cam.position_smoothing_enabled = true
		cam.position_smoothing_speed = 5.0
		cam.drag_horizontal_enabled = true
		cam.drag_vertical_enabled = true
		cam.drag_left_margin = 0.2
		cam.drag_right_margin = 0.2
		cam.drag_top_margin = 0.2
		cam.drag_bottom_margin = 0.2
		cam.limit_smoothed = true
		# Giới hạn camera không scroll ra ngoài map theo chiều dọc
		cam.limit_top = 0
		cam.limit_bottom = 648  # chiều cao viewport (1152x648)
		add_child(cam)
		camera = cam
	else:
		camera = $Camera2D
		camera.limit_top = 0
		camera.limit_bottom = 648

	_load_player_audio()
	anim.animation_finished.connect(_on_animation_finished)
	if anim.animation_looped.get_connections().size() == 0:
		anim.animation_looped.connect(_on_animation_finished)

	# Kết nối MeleeHitbox signal (đòn ngang)
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.set_collision_mask_value(2, true)  # detect enemy layer 2
		if not melee_hitbox.body_entered.is_connected(_on_melee_hit):
			melee_hitbox.body_entered.connect(_on_melee_hit)

	# Kết nối MeleeHitboxHigh signal (đòn cao)
	if melee_hitbox_high:
		melee_hitbox_high.monitoring = false
		melee_hitbox_high.set_collision_mask_value(2, true)  # detect enemy layer 2
		if not melee_hitbox_high.body_entered.is_connected(_on_melee_hit):
			melee_hitbox_high.body_entered.connect(_on_melee_hit)

	# Kết nối SkillRHitbox signal
	if skill_r_hitbox:
		skill_r_hitbox.monitoring = false
		skill_r_hitbox.set_collision_mask_value(2, true)  # detect enemy layer 2
		if not skill_r_hitbox.body_entered.is_connected(_on_skill_r_hit):
			skill_r_hitbox.body_entered.connect(_on_skill_r_hit)

	# Tạo Health + Lives HUD (từ scene có thể chỉnh trong editor)
	_player_hud = _hud_scene.instantiate()
	add_child(_player_hud)
	_player_hud.set_max_health(max_health)
	_player_hud.update_health(current_health)
	_player_hud.update_lives(GameManager.lives)

	# Tìm và apply Level Boundaries sau khi cả scene đã load xong
	call_deferred("_find_level_bounds")

func _find_level_bounds():
	# Scan toàn bộ scene tree để tìm LevelBounds nodes
	var root = get_tree().current_scene
	if root == null:
		return
	var bounds_nodes = []
	_collect_level_bounds(root, bounds_nodes)

	for node in bounds_nodes:
		if not node.has_method("_is_right"):
			continue
		var gx = node.global_position.x
		if node._is_right():
			set_right_bound(gx)
		else:
			set_left_bound(gx)

func _collect_level_bounds(node: Node, result: Array):
	if node.get_script() != null:
		var script = node.get_script()
		# Kiểm tra class_name là LevelBounds
		if script.get_global_name() == "LevelBounds" or node.get_class() == "LevelBounds":
			result.append(node)
			return
		# Kiểm tra nếu node có is_right_bound property (duck typing)
		if node.has_method("_is_right"):
			result.append(node)
			return
	for child in node.get_children():
		_collect_level_bounds(child, result)

func _load_player_audio():
	# Đưa @export vars vào cache trước
	var export_map = {
		"jump": jump_sfx, "run": run_sfx, "idle": idle_sfx,
		"hurt": hit_sfx, "die": die_sfx, "attack": attack_sfx,
		"crouch": crouch_sfx, "skill_w": skill_w_sfx, "skill_e": skill_e_sfx
	}
	for key in export_map:
		if export_map[key] != null:
			_sfx_cache[key] = export_map[key]

	# Auto-load fallback từ folder player/ cho các key chưa có
	var audio_folder = "res://assets/audio/character/player"
	var fallback_anims = ["idle", "run", "jump", "attack", "crouch", "die", "hurt", "skill_w", "skill_e"]
	for anim_name in fallback_anims:
		if not _sfx_cache.has(anim_name):
			var path = "%s/%s.mp3" % [audio_folder, anim_name]
			if ResourceLoader.exists(path):
				_sfx_cache[anim_name] = load(path)
				print("[PlayerSFX] Auto-loaded: ", path)

func _play_sfx(anim_name: String):
	if not _sfx_cache.has(anim_name): return
	if not sfx_player: return
	# Dừng audio cũ ngay lập tức, không đợi nó kết thúc
	sfx_player.stop()
	var key = anim_name.replace("-", "_")
	var pitch = 1.0
	if ANIM_FRAME_COUNTS.has(key):
		var effective_fps = SPRITEFRAMES_SPEED * anim.speed_scale
		var anim_duration = ANIM_FRAME_COUNTS[key] / effective_fps
		pitch = clampf(AUDIO_DURATION / anim_duration, 0.1, 4.0)
	sfx_player.pitch_scale = pitch
	sfx_player.stream = _sfx_cache[anim_name]
	sfx_player.play()

func _play_loop_sfx(anim_name: String):
	if not _sfx_cache.has(anim_name): return
	if sfx_loop:
		# Dừng audio cũ rồi play mới ngị lp
		if sfx_loop.stream != _sfx_cache[anim_name]:
			sfx_loop.stop()
			sfx_loop.stream = _sfx_cache[anim_name]
			sfx_loop.play()
		elif not sfx_loop.playing:
			sfx_loop.play()

func _stop_loop_sfx():
	if sfx_loop and sfx_loop.playing:
		sfx_loop.stop()

# ---- Level Bounds ----

func set_left_bound(x: float):
	limit_left_x = x
	if camera:
		camera.limit_left = int(x)

func set_right_bound(x: float):
	limit_right_x = x
	if camera:
		camera.limit_right = int(x)

# ---- Physics ----

func _physics_process(delta):
	# Nếu đã chết → đứng im, không nhận input
	if is_dead:
		velocity.x = 0
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Đang attack hoặc skill → cho phép nhảy, nhưng không override animation di chuyển
	if is_attacking or is_skill_active:
		# Vẫn cho phép nhảy trong khi đánh
		if Input.is_action_just_pressed("jump") and is_on_floor():
			velocity.y = JUMP_FORCE
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, SPEED)
		else:
			velocity.y += GRAVITY * get_physics_process_delta_time()
			velocity.x = move_toward(velocity.x, 0, SPEED * 0.3)
		move_and_slide()
		return

	# Attack: chuột trái (cả khi trên sàn lẫn trên không)
	if Input.is_action_just_pressed("attack"):
		_play_attack()
		return

	# Skill R — dùng được mọi lúc (cả khi nhảy), block toàn bộ hành động khác
	if Input.is_action_just_pressed("skill_r"):
		_play_skill_r()
		return

	# Kỹ năng W/Q/E (chỉ khi trên sàn và không cúi)
	if is_on_floor() and not is_crouching:
		if Input.is_action_just_pressed("skill_w"):
			_play_skill("skill_w")
			return
		elif Input.is_action_just_pressed("skill_q"):
			_play_skill("attack")
			return
		elif Input.is_action_just_pressed("skill_e"):
			_play_skill("attack")
			return

	var direction = Input.get_axis("move_left", "move_right")

	# Flip hướng
	if direction != 0:
		anim.flip_h = direction < 0

	# Nhảy
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_FORCE

	# Cúi (Left Ctrl)
	var was_crouching = is_crouching
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	if is_crouching:
		velocity.x = 0
		if not was_crouching:
			if $CollisionShape2D.shape is RectangleShape2D:
				var crouch_h = _col_stand_h * 0.62  # thu nhỏ xuống 62%
				var bottom = _col_stand_y + _col_stand_h * 0.5  # đáy cố định
				$CollisionShape2D.shape.size.y = crouch_h
				$CollisionShape2D.position.y = bottom - crouch_h * 0.5
	else:
		if was_crouching:
			if $CollisionShape2D.shape is RectangleShape2D:
				# Khôi phục về giá trị gốc từ editor
				$CollisionShape2D.shape.size.y = _col_stand_h
				$CollisionShape2D.position.y = _col_stand_y
		# Block nếu đang ở biên và nhấn phím đi ra ngoài
		if global_position.x <= limit_left_x and direction < 0:
			velocity.x = 0
		elif global_position.x >= limit_right_x and direction > 0:
			velocity.x = 0
		else:
			velocity.x = direction * SPEED

	move_and_slide()

	# Clamp thêm 1 lần nữa để chắc chắn (trường hợp bị đẩy bởi physics)
	global_position.x = clampf(global_position.x, limit_left_x, limit_right_x)

	# Animation trạng thái thường
	_update_animations(direction)

# ---- Animation ----

func _calc_anim_speed_scale(anim_name: String) -> float:
	# Animation chạy full 60fps (speed_scale = 1.0)
	# Audio sẽ tự speed up để khớp với animation ngắn hơn
	return 1.0

## Tính góc từ player đến con trỏ chuột (âm = lên trên, dương = xuống dưới)
func _get_mouse_angle_deg() -> float:
	var mouse_global = get_global_mouse_position()
	var to_mouse = mouse_global - global_position
	return rad_to_deg(to_mouse.angle())  # 0° = phải, -90° = lên, 90° = xuống

func _play_attack():
	var frames = anim.sprite_frames
	if frames == null or not frames.has_animation("attack"):
		return

	# ── Xác định loại đòn theo góc chuột ──────────────────────────
	# angle() trả về -90° khi chuột thẳng lên, 90° khi thẳng xuống
	# Góc < -45° nghĩa là chuột ở phía trên quá 45° → đòn cao
	var angle_deg = _get_mouse_angle_deg()
	var use_high = (angle_deg < -45.0) and frames.has_animation("attack_high")
	_attack_type = "high" if use_high else "normal"
	var anim_name = "attack_high" if use_high else "attack"

	is_attacking = true
	_attacked_bodies.clear()
	anim.speed_scale = 3.0
	anim.play(anim_name)
	_play_sfx("attack")

	# ── Chọn hitbox tương ứng ──────────────────────────────────────
	var active_hitbox: Area2D = melee_hitbox_high if use_high else melee_hitbox
	var inactive_hitbox: Area2D = melee_hitbox if use_high else melee_hitbox_high

	# Tắt hitbox không dùng
	if inactive_hitbox:
		inactive_hitbox.monitoring = false

	if active_hitbox:
		# Cập nhật hướng hitbox theo flip player
		var dir = -1 if anim.flip_h else 1
		if active_hitbox.has_node("CollisionShape2D"):
			var col = active_hitbox.get_node("CollisionShape2D")
			col.position.x = abs(col.position.x) * dir
		active_hitbox.monitoring = false
		# Delay trước khi hitbox bật — chọn đúng biến theo loại đòn
		var delay = attack_high_hitbox_delay if use_high else attack_hitbox_delay
		await get_tree().create_timer(delay).timeout
		if not is_attacking:
			return
		active_hitbox.monitoring = true
		await get_tree().physics_frame
		if active_hitbox and active_hitbox.monitoring:
			for body in active_hitbox.get_overlapping_bodies():
				_on_melee_hit(body)

## Kỹ năng R: 50 sát thương + hất văng lên, block mọi hành động khác
func _play_skill_r() -> void:
	var frames = anim.sprite_frames
	if frames == null or not frames.has_animation("skill_r"):
		# Fallback nếu chưa có animation
		_play_skill("attack")
		return

	is_skill_active = true
	_is_super_armor = true   ## Bật super armor — chịu đòn không bị ngắt
	_attacked_bodies.clear()
	anim.speed_scale = 1.0
	anim.play("skill_r")
	_play_sfx("skill_r")

	if skill_r_hitbox:
		skill_r_hitbox.monitoring = false
		# ── Flip hitbox sang đúng hướng player nhìn ──────────────────
		if skill_r_hitbox.has_node("CollisionShape2D"):
			var col = skill_r_hitbox.get_node("CollisionShape2D")
			var dir = -1 if anim.flip_h else 1
			col.position.x = abs(col.position.x) * dir
		# Bật hitbox sau delay — chỉnh trong Inspector để khớp với animation
		await get_tree().create_timer(skill_r_hitbox_delay).timeout
		if not is_skill_active:
			return
		skill_r_hitbox.monitoring = true
		await get_tree().physics_frame
		if skill_r_hitbox and skill_r_hitbox.monitoring:
			for body in skill_r_hitbox.get_overlapping_bodies():
				_on_skill_r_hit(body)
	_is_super_armor = false  ## Tắt super armor khi skill kết thúc

## Xử lý khi Skill R chạm enemy — gây 50 dame + hất văng lên
func _on_skill_r_hit(body: Node) -> void:
	if body == self: return
	if body in _attacked_bodies: return
	_attacked_bodies.append(body)
	if body.has_method("take_damage"):
		body.take_damage(skill_r_damage)
	# Hất văng đúng 400px theo hướng player nhìn (~14° lên)
	var facing = -1.0 if anim.flip_h else 1.0
	var knock_dir = Vector2(facing * 2.0, -0.5).normalized()
	if body.has_method("apply_knockback_distance"):
		body.apply_knockback_distance(knock_dir, 400.0, 0.35)
	elif body.has_method("apply_knockback"):
		body.apply_knockback(knock_dir, 1000.0)

func _play_skill(anim_name: String):
	var frames = anim.sprite_frames
	var target = anim_name if (frames and frames.has_animation(anim_name)) else "attack"
	is_skill_active = true
	anim.speed_scale = 1.0  # skill chạy 60fps (bình thường)
	anim.play(target)
	_play_sfx(target)  # pitch: 8/3.2 = 2.5x

func _on_animation_finished():
	if is_attacking:
		is_attacking = false
		# Tắt cả hitbox
		if melee_hitbox:
			melee_hitbox.monitoring = false
		if melee_hitbox_high:
			melee_hitbox_high.monitoring = false
	if is_skill_active:
		is_skill_active = false
		if skill_r_hitbox:
			skill_r_hitbox.monitoring = false

# ---- Combat ----

func _on_melee_hit(body: Node):
	if body == self: return
	if body in _attacked_bodies: return  # Đã đánh body này rồi, bỏ qua
	if body.has_method("take_damage"):
		_attacked_bodies.append(body)
		body.take_damage(attack_damage)

func _update_animations(direction: float):
	# Thứ tự ưu tiên: die > attack > skill > jump > crouch > run > idle
	var new_anim = ""
	if is_dead:
		new_anim = "die"
	elif is_attacking:
		new_anim = "attack_high" if _attack_type == "high" else "attack"
	elif is_skill_active:
		pass  # skill đang phát, giữ nguyên
	elif not is_on_floor():
		if velocity.y < 0:
			# Đang bay lên → play animation nhảy lên
			new_anim = "jump"
		else:
			# Đang rơi xuống → play "fall" nếu có, không thì giữ "jump" ở frame cuối
			if anim.sprite_frames and anim.sprite_frames.has_animation("fall"):
				new_anim = "fall"
			else:
				# Không có "fall" → seek đến frame cuối của jump (pha đáp xuống)
				if anim.animation == "jump":
					var last_frame = anim.sprite_frames.get_frame_count("jump") - 1
					if anim.frame != last_frame:
						anim.pause()
						anim.frame = last_frame
				new_anim = ""  # Không restart animation
	elif is_crouching:
		new_anim = "crouch"
	elif direction != 0:
		new_anim = "run"
	else:
		new_anim = "idle"

	if new_anim != "" and anim.animation != new_anim:
		# Tất cả animation đều speed_scale = 1.0 (60fps)
		# Chỉ attack được set riêng trong _play_attack() với speed_scale=3.0
		anim.speed_scale = 1.0
		anim.play(new_anim)
		# Play sfx khi animation thay đổi
		if new_anim in ["run", "idle", "crouch"]:
			_play_loop_sfx(new_anim)
		else:
			_stop_loop_sfx()
			if new_anim not in ["attack", "skill_w", "skill_e"]:  # Skill/attack đã play trong hàm riêng
				_play_sfx(new_anim)

# ---- Health & Death ----

#func heal(amount: float):
#	health = min(health + amount, MAX_HEALTH)
#	if hud:
#		hud.update_health(health)

#func take_damage(amount: float):
#	if is_dead:
#		return
#	health -= amount
#	if hud:
#		hud.update_health(health)
#	if health <= 0:
#		die()

func die():
	if is_dead:
		return
	is_dead = true
	is_attacking = false
	is_skill_active = false
	anim.speed_scale = 20.0
	anim.play("die")

# ---- Audio (reserved) ----

#func _play_sfx(stream: AudioStream, volume_db: float = 0.0):
#	pass
#
#func _play_loop_sfx(stream: AudioStream, volume_db: float = 0.0):
#	pass
#
#func _stop_loop_sfx():
#	pass

# ---- Health System ----

## Nhận sát thương từ enemy (gọi từ enemy_melee_script)
func take_damage(amount: float) -> void:
	if is_dead or is_hurting:
		return

	# Giảm máu
	current_health = max(0.0, current_health - amount)
	_update_health_bar()

	if current_health <= 0.0:
		_die()
		return

	# ── Super Armor (đang dùng Skill R) ──────────────────────────────
	# Vẫn mất máu + flash đỏ, nhưng KHÔNG bị stagger hay ngắt skill
	if _is_super_armor:
		_flash_hurt()
		return

	# Trạng thái hurt bình thường (block physics 0.5s)
	is_hurting = true
	is_attacking = false
	is_skill_active = false

	# Play hurt animation + flash
	if anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")
	_flash_hurt()

	# Sau 0.5s: kết thúc hurt, trở về idle
	await get_tree().create_timer(0.5).timeout
	if not is_dead:
		is_hurting = false
		if anim.animation == "hurt":
			anim.play("idle")

## Flash đỏ nhắc nhở bị đánh (không block gì cả)
func _flash_hurt() -> void:
	var tw = create_tween().set_loops(2)
	tw.tween_property(anim, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.07)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.07)

## Bị đẩy bởi enemy (ví dụ: heo ủi) — áp dụng lực để player văng về phía trước
func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead:
		return
	velocity += direction.normalized() * force

func _die() -> void:
	if is_dead:
		return
	is_dead = true
	_is_invincible = true
	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO
	if anim.sprite_frames.has_animation("die"):
		anim.play("die")

func _update_health_bar() -> void:
	if _player_hud:
		_player_hud.update_health(current_health)
