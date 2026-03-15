extends CharacterBody2D

## Script riêng cho player ở màn 3 (Son Tinh Bé Mì Nướng)
## Chỉ có: idle, run, jump, fail
## fail = khi nước dâng lên 2/3 chiều cao collision của player

# ─── Constants ──────────────────────────────────────────────────────────────
const GRAVITY       : float = 1200.0
const JUMP_VELOCITY : float = -700.0
const MOVE_SPEED    : float = 300.0

# ─── State ──────────────────────────────────────────────────────────────────
var _is_failed  : bool = false
var _face_right : bool = true

# ─── Nodes ──────────────────────────────────────────────────────────────────
@onready var _anim   : AnimatedSprite2D    = $AnimatedSprite2D
@onready var _col    : CollisionShape2D    = $CollisionShape2D
@onready var _sfx    : AudioStreamPlayer   = $SFXPlayer

# ─── Exports (SFX) ──────────────────────────────────────────────────────────
@export var jump_sfx  : AudioStream
@export var run_sfx   : AudioStream
@export var idle_sfx  : AudioStream

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	add_to_group("player")
	_play_anim("idle")


func _physics_process(delta: float) -> void:
	if _is_failed:
		return

	_apply_gravity(delta)
	_handle_movement()
	_handle_jump()
	move_and_slide()
	_update_animation()


# ─── Gravity ────────────────────────────────────────────────────────────────
func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += GRAVITY * delta


# ─── Movement ───────────────────────────────────────────────────────────────
func _handle_movement() -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * MOVE_SPEED

	if dir > 0 and not _face_right:
		_face_right = true
		_anim.flip_h = false
	elif dir < 0 and _face_right:
		_face_right = false
		_anim.flip_h = true


# ─── Jump ───────────────────────────────────────────────────────────────────
func _handle_jump() -> void:
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		_play_sfx(jump_sfx)


# ─── Animation ──────────────────────────────────────────────────────────────
func _update_animation() -> void:
	if not is_on_floor():
		_play_anim("jump")
	elif velocity.x != 0:
		_play_anim("run")
	else:
		_play_anim("idle")


# ─── Fail (gọi từ RisingWater) ──────────────────────────────────────────────
## Được gọi khi mực nước dâng lên 2/3 collision của player
func die_from_water() -> void:
	if _is_failed:
		return
	_is_failed = true
	velocity = Vector2.ZERO
	_play_anim("fail")


## Tương thích với interface cũ nếu rising_water gọi take_damage
func take_damage(_amount: float) -> void:
	die_from_water()


# ─── Helper: kiểm tra nước dâng ─────────────────────────────────────────────
## Gọi từ RisingWater hoặc từ _process để tự kiểm tra.
## water_surface_y: global Y của mặt nước (càng nhỏ → nước càng cao).
func check_water_level(water_surface_y: float) -> void:
	if _is_failed:
		return

	# Lấy kích thước collision shape
	var shape := _col.shape as RectangleShape2D
	if shape == null:
		return

	var half_h       : float = shape.size.y * 0.5
	var offset_y     : float = _col.position.y   # offset cục bộ so với player root

	# Vị trí toàn cầu của đáy collision
	var col_bottom_y : float = global_position.y + offset_y + half_h
	var col_height   : float = shape.size.y

	# Mực nước phải dâng lên ≥ 2/3 chiều cao collision (tính từ đáy lên)
	# => mặt nước phải ≤ đỉnh của 1/3 dưới cùng
	var threshold_y  : float = col_bottom_y - col_height * (2.0 / 3.0)

	if water_surface_y <= threshold_y:
		die_from_water()


# ─── Internal ────────────────────────────────────────────────────────────────
func _play_anim(anim_name: StringName) -> void:
	if _anim.animation != anim_name:
		_anim.play(anim_name)


func _play_sfx(stream: AudioStream) -> void:
	if stream == null or _sfx == null:
		return
	_sfx.stream = stream
	_sfx.play()
