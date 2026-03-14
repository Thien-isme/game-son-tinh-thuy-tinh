extends CharacterBody2D

const SPEED = 200
const JUMP_FORCE = -550
const GRAVITY = 900
#const MAX_HEALTH = 500.0

@onready var anim = $AnimatedSprite2D
#@onready var hud = $HUD
#@onready var sfx_player = $SFXPlayer        # Dùng cho âm thanh ngắn (nhảy, chết, bị đánh)
#@onready var sfx_loop = $SFXPlayerLoop      # Dùng cho âm thanh lặp (chạy, đứng yên, cúi)

# Health & State
#var health: float = 500.0
var is_dead: bool = false
var is_attacking: bool = false   # Đang attack (chuột trái)
var is_crouching: bool = false
var is_skill_active: bool = false  # Đang phát animation skill (W/Q/E/R)

# ---- Lifecycle ----

func _ready():
	anim.animation_finished.connect(_on_animation_finished)
	# animation_looped: fire khi animation loop - cần thiết vì animation_finished
	# KHÔNG emit cho animation đang loop (idle/run/attack loop)
	if anim.animation_looped.get_connections().size() == 0:
		anim.animation_looped.connect(_on_animation_finished)

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
			if $CollisionShape2D.shape is CapsuleShape2D:
				$CollisionShape2D.shape.height = 52.0
			$CollisionShape2D.position.y = 6.0
	else:
		if was_crouching:
			if $CollisionShape2D.shape is CapsuleShape2D:
				$CollisionShape2D.shape.height = 70.0
			$CollisionShape2D.position.y = -3.0
		velocity.x = direction * SPEED

	move_and_slide()

	# Giới hạn map
	#	if global_position.x < limit_left_x:
	#		global_position.x = limit_left_x
	#	elif global_position.x > limit_right_x:
	#		global_position.x = limit_right_x

	# Animation trạng thái thường
	_update_animations(direction)

# ---- Animation ----

func _play_attack():
	# Chỉ attack nếu animation 'attack' tồn tại trong SpriteFrames
	var frames = anim.sprite_frames
	if frames == null or not frames.has_animation("attack"):
		return  # Không có animation attack → bỏ qua
	is_attacking = true
	anim.speed_scale = 20.0
	anim.play("attack")

func _play_skill(anim_name: String):
	# Nếu animation tên đó không tồn tại thì fallback về "attack"
	var frames = anim.sprite_frames
	if frames and frames.has_animation(anim_name):
		is_skill_active = true
		anim.speed_scale = 20.0
		anim.play(anim_name)
	else:
		is_skill_active = true
		anim.speed_scale = 20.0
		anim.play("attack")

func _on_animation_finished():
	if is_attacking:
		is_attacking = false
	if is_skill_active:
		is_skill_active = false

func _update_animations(direction: float):
	# Thứ tự ưu tiên: die > attack > skill > jump > crouch > run > idle
	if is_dead:
		if anim.animation != "die":
			anim.speed_scale = 20.0
			anim.play("die")
	elif is_attacking:
		pass  # attack đang phát, giữ nguyên
	elif is_skill_active:
		pass  # skill đang phát, giữ nguyên
	elif not is_on_floor():
		if anim.animation != "jump":
			anim.speed_scale = 20.0
			anim.play("jump")
	elif is_crouching:
		if anim.animation != "crouch":
			anim.speed_scale = 20.0
			anim.play("crouch")
	elif direction != 0:
		if anim.animation != "run":
			anim.speed_scale = 20.0
			anim.play("run")
	else:
		if anim.animation != "idle":
			anim.speed_scale = 20.0
			anim.play("idle")

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
