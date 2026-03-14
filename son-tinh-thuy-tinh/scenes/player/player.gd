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
	"run": 192, "skill_w": 191, "skill_e": 192
}

@onready var anim = $AnimatedSprite2D
var camera: Camera2D = null
@onready var sfx_player = $SFXPlayer
@onready var sfx_loop = $SFXPlayerLoop

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

# Health & State
var is_dead: bool = false
var is_attacking: bool = false
var is_crouching: bool = false
var is_skill_active: bool = false

# Camera bounds
var limit_left_x: float = -10000.0
var limit_right_x: float = 10000.0

# Collision standing values (saved from .tscn in _ready)
var _col_stand_y: float = -49.0   # giá trị từ editor
var _col_stand_h: float = 100.0   # giá trị từ editor

# ---- Lifecycle ----

func _ready():
	# Lưu giá trị gốc từ editor, duplicate shape để tránh shared resource
	if $CollisionShape2D.shape:
		$CollisionShape2D.shape = $CollisionShape2D.shape.duplicate()
		if $CollisionShape2D.shape is RectangleShape2D:
			_col_stand_y = $CollisionShape2D.position.y
			_col_stand_h = $CollisionShape2D.shape.size.y

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

	# Đang attack hoặc skill → không nhận input di chuyển hay kỹ năng mới
	if is_attacking or is_skill_active:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		move_and_slide()
		_update_animations(0.0)
		return

	# Attack: chuột trái (chỉ khi trên sàn)
	if is_on_floor() and Input.is_action_just_pressed("attack"):
		_play_attack()
		return

	# Kỹ năng W (chỉ khi trên sàn và không cúi)
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
		elif Input.is_action_just_pressed("skill_r"):
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

func _play_attack():
	var frames = anim.sprite_frames
	if frames == null or not frames.has_animation("attack"):
		return
	is_attacking = true
	anim.speed_scale = 3.0  # attack chạy 3x (60fps ×3 = 180fps, 192f/180 ≈ 1.07s)
	anim.play("attack")
	_play_sfx("attack")  # pitch tự tính: 8s / 1.07s ≈ 7.5x (clamp →4.0)

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
	if is_skill_active:
		is_skill_active = false

func _update_animations(direction: float):
	# Thứ tự ưu tiên: die > attack > skill > jump > crouch > run > idle
	var new_anim = ""
	if is_dead:
		new_anim = "die"
	elif is_attacking:
		new_anim = "attack"
	elif is_skill_active:
		pass  # skill đang phát, giữ nguyên
	elif not is_on_floor():
		new_anim = "jump"
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
