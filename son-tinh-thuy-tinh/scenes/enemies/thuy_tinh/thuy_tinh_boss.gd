## Boss AI - Thủy Tinh
## Finite State Machine với hành vi giống người chơi thật:
##   - Đọc vị trí player để quyết định hành động
##   - Dodge khi player đang attack
##   - Dùng skill ngẫu nhiên (jump + attack, dash attack)
##   - Phản ứng chậm như người thật (reaction delay)
##   - Phase 2 khi HP < 40%: nhanh hơn, hung hăng hơn

extends CharacterBody2D

# ── Animations ─────────────────────────────────────────────────────────────
const ANIM_ATTACK_FRAME_DEAL_DAMAGE := 55  ## Frame gây dame trong animation attack

# ── Constants ───────────────────────────────────────────────────────────────
const GRAVITY := 900.0

# ── Exports - Chỉnh trong Inspector ─────────────────────────────────────────
@export_category("Boss Stats")
@export var max_health: float = 500.0
@export var attack_damage: float = 15.0
@export var move_speed: float = 140.0
@export var jump_force: float = -500.0

@export_category("AI Behaviour")
@export var preferred_distance: float = 120.0    ## Khoảng cách lý tưởng với player
@export var attack_range: float = 150.0           ## Tầm đánh thường
@export var jump_attack_range: float = 280.0      ## Tầm nhảy vào đánh
@export var reaction_delay_min: float = 0.08      ## Giây delay phản ứng tối thiểu
@export var reaction_delay_max: float = 0.25      ## Giây delay phản ứng tối đa
@export var dodge_chance: float = 0.45            ## Xác suất dodge khi player attack (0-1)
@export var combo_chance: float = 0.35            ## Xác suất đánh combo ngay sau đòn 1

@export_category("Cooldowns")
@export var attack_cooldown: float = 1.2
@export var jump_attack_cooldown: float = 2.5
@export var dodge_cooldown: float = 1.8

@export_category("Phase 2 (HP < 40%)")
@export var phase2_speed_bonus: float = 40.0      ## Tốc độ thêm vào ở phase 2
@export var phase2_attack_cooldown: float = 0.7   ## Cooldown ngắn hơn ở phase 2
@export var phase2_dodge_chance: float = 0.65     ## Dodge nhiều hơn ở phase 2

# ── State Machine ───────────────────────────────────────────────────────────
enum State {
	IDLE,        ## Đứng yên / quan sát
	CHASE,       ## Đuổi theo player
	APPROACH,    ## Tiến gần đến preferred_distance
	RETREAT,     ## Lùi ra khi quá gần
	ATTACK,      ## Đòn đánh thường
	JUMP_ATTACK, ## Nhảy vào đánh
	DODGE,       ## Né tránh
	HURT,        ## Đang chịu đòn
	DEATH,       ## Chết
}

var _state: State = State.IDLE
var _prev_state: State = State.IDLE

# ── Runtime State ───────────────────────────────────────────────────────────
var current_health: float
var is_dead: bool = false
var player: Node = null

var _attack_cd_timer: float = 0.0
var _jump_attack_cd_timer: float = 0.0
var _dodge_cd_timer: float = 0.0
var _reaction_timer: float = 0.0        ## Đang chờ phản ứng
var _is_in_action: bool = false         ## Đang thực hiện attack/dodge (coroutine)
var _phase2_active: bool = false

# ── Hitbox ──────────────────────────────────────────────────────────────────
@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var sfx_player: AudioStreamPlayer = $SFXPlayer
@onready var melee_hitbox: Area2D = $MeleeHitbox

# Health Bar
var _health_bar: ProgressBar = null

# ── Audio cache ──────────────────────────────────────────────────────────────
var _sfx_cache: Dictionary = {}

# ────────────────────────────────────────────────────────────────────────────
func _ready() -> void:
	current_health = max_health
	add_to_group("enemy")

	# Collision: enemy ở layer 2, detect player (layer 3)
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, false)  # không block enemy khác
	set_collision_mask_value(3, true)   # detect player

	# Kết nối hitbox
	if melee_hitbox:
		melee_hitbox.monitoring = false
		melee_hitbox.set_collision_mask_value(3, true)
		melee_hitbox.body_entered.connect(_on_melee_hit)

	# Health Bar
	_create_health_bar()

	# Load audio
	_load_audio()

	# Tìm player ngay khi spawn
	await get_tree().physics_frame
	_find_player()

# ── Find Player ──────────────────────────────────────────────────────────────
func _find_player() -> void:
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

# ── Physics Loop ─────────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if is_dead:
		velocity.y += GRAVITY * delta
		move_and_slide()
		return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Tìm player nếu chưa có
	if player == null:
		_find_player()
		velocity.x = 0
		move_and_slide()
		return

	# Giảm cooldown timers
	_attack_cd_timer  = max(0.0, _attack_cd_timer  - delta)
	_jump_attack_cd_timer = max(0.0, _jump_attack_cd_timer - delta)
	_dodge_cd_timer   = max(0.0, _dodge_cd_timer   - delta)

	# Nếu đang trong action (coroutine) → chỉ apply physics
	if _is_in_action:
		move_and_slide()
		return

	# Chạy FSM
	match _state:
		State.IDLE:        _tick_idle(delta)
		State.CHASE:       _tick_chase(delta)
		State.APPROACH:    _tick_approach(delta)
		State.RETREAT:     _tick_retreat(delta)
		State.ATTACK:      pass  # handled by coroutine
		State.JUMP_ATTACK: pass
		State.DODGE:       pass
		State.HURT:        _tick_hurt()
		State.DEATH:       pass

	move_and_slide()

# ────────────────────────────────────────────────────────────────────────────
# FSM Ticks
# ────────────────────────────────────────────────────────────────────────────

func _tick_idle(_delta: float) -> void:
	velocity.x = 0
	_play_anim("idle")
	# Chờ một chút rồi bắt đầu quyết định
	await get_tree().create_timer(randf_range(0.3, 0.7)).timeout
	if not is_dead and player != null:
		_decide_next_action()

func _tick_chase(delta: float) -> void:
	if player == null: return
	var dist = _dist_to_player()
	var dir  = _dir_to_player()

	# Đủ gần → chuyển sang attack hoặc approach
	if dist <= attack_range:
		_decide_next_action()
		return

	# Đang quá xa → chase
	velocity.x = dir * _current_speed()
	_flip_toward(dir > 0)
	_play_anim("run")

func _tick_approach(delta: float) -> void:
	if player == null: return
	var dist = _dist_to_player()
	var dir  = _dir_to_player()

	if abs(dist - preferred_distance) < 20.0:
		# Đã ở vị trí lý tưởng
		_decide_next_action()
		return

	if dist > preferred_distance:
		velocity.x = dir * _current_speed() * 0.7
		_play_anim("run")
	else:
		# Quá gần → lùi ra
		_change_state(State.RETREAT)

	_flip_toward(dir > 0)

func _tick_retreat(_delta: float) -> void:
	if player == null: return
	var dist  = _dist_to_player()
	var dir   = _dir_to_player()

	if dist >= preferred_distance:
		_decide_next_action()
		return

	# Chạy ngược chiều player
	velocity.x = -dir * _current_speed() * 0.85
	_flip_toward(dir > 0)  # Vẫn quay mặt nhìn player khi lùi
	_play_anim("run")

func _tick_hurt() -> void:
	velocity.x = 0
	_play_anim("hurt")

# ────────────────────────────────────────────────────────────────────────────
# Decision Making (AI Brain)
# ────────────────────────────────────────────────────────────────────────────

func _decide_next_action() -> void:
	if is_dead or player == null: return

	# Reaction delay: giống người thật, không phản ứng ngay tức thì
	_reaction_timer = randf_range(reaction_delay_min, reaction_delay_max)
	await get_tree().create_timer(_reaction_timer).timeout
	if is_dead or player == null: return

	var dist = _dist_to_player()
	var is_phase2 = _phase2_active

	# ── Dodge nếu player đang attack và dodge có thể dùng ─────────────────
	var player_is_attacking := _is_player_attacking()
	var dodge_prob = phase2_dodge_chance if is_phase2 else dodge_chance
	if player_is_attacking and _dodge_cd_timer <= 0.0 and randf() < dodge_prob:
		_do_dodge()
		return

	# ── Tấn công trong tầm ────────────────────────────────────────────────
	if dist <= attack_range and _attack_cd_timer <= 0.0:
		_do_attack()
		return

	# ── Jump attack từ xa ─────────────────────────────────────────────────
	if dist <= jump_attack_range and dist > attack_range and _jump_attack_cd_timer <= 0.0 and is_on_floor():
		if randf() < 0.55:  # 55% xác suất dùng jump attack khi ở tầm xa
			_do_jump_attack()
			return

	# ── Di chuyển chiến thuật ─────────────────────────────────────────────
	if dist > jump_attack_range:
		_change_state(State.CHASE)
	elif dist > attack_range:
		_change_state(State.APPROACH)
	elif dist < preferred_distance * 0.6:
		_change_state(State.RETREAT)
	else:
		_change_state(State.IDLE)

# ────────────────────────────────────────────────────────────────────────────
# Actions (Coroutines)
# ────────────────────────────────────────────────────────────────────────────

## Đòn đánh thường
func _do_attack() -> void:
	_is_in_action = true
	_change_state(State.ATTACK)
	velocity.x = 0

	# Flip hướng player
	_flip_toward(_dir_to_player() > 0)
	_update_hitbox_dir()

	# Đảm bảo animation KHÔNG loop (nếu loop thì animation_finished không bao giờ fire)
	if anim.sprite_frames and anim.sprite_frames.has_animation("attack"):
		anim.sprite_frames.set_animation_loop("attack", false)

	anim.speed_scale = 3.0
	anim.frame = 0
	anim.play("attack")
	_play_sfx("attack")

	# ── Tính thời gian đến frame gây dame bằng timer (đáng tin cậy hơn frame check) ──
	# attack có 192 frames, chạy ở speed_scale=3.0 × 60fps = 180fps thực tế
	# frame 55 tương đương: 55 / 180 ≈ 0.305 giây
	const ATTACK_FPS_EFFECTIVE := 60.0 * 3.0
	var time_to_hit := ANIM_ATTACK_FRAME_DEAL_DAMAGE / ATTACK_FPS_EFFECTIVE
	await get_tree().create_timer(time_to_hit).timeout

	# ── Gây dame trực tiếp cho player nếu còn trong tầm ──────────────────────
	# (Cách này đáng tin cậy hơn get_overlapping_bodies())
	if not is_dead and player != null and _dist_to_player() <= attack_range * 1.5:
		if player.has_method("take_damage"):
			player.take_damage(attack_damage)

	# ── Chờ phần còn lại của animation bằng timer ──────────────────────────
	# Tổng animation: 192 frames / 180fps = 1.067s. Còn lại: 1.067 - time_to_hit
	var total_duration := 192.0 / ATTACK_FPS_EFFECTIVE
	var remaining := maxf(0.0, total_duration - time_to_hit)
	await get_tree().create_timer(remaining).timeout

	# Cooldown
	var cd := phase2_attack_cooldown if _phase2_active else attack_cooldown
	_attack_cd_timer = cd

	_is_in_action = false
	anim.speed_scale = 1.0

	# Combo: 35% xác suất đánh thêm nếu player vẫn trong tầm
	if not is_dead and randf() < combo_chance and _dist_to_player() <= attack_range and _attack_cd_timer <= 0.0:
		await get_tree().create_timer(0.1).timeout
		_do_attack()
	else:
		_decide_next_action()

## Nhảy vào đánh (jump attack)
func _do_jump_attack() -> void:
	_is_in_action = true
	_change_state(State.JUMP_ATTACK)
	_jump_attack_cd_timer = jump_attack_cooldown

	_flip_toward(_dir_to_player() > 0)
	_play_sfx("jump")

	# Nhảy về phía player
	var dir = _dir_to_player()
	velocity.y = jump_force
	velocity.x = dir * _current_speed() * 1.4
	_play_anim("jump")

	# Chờ đến khi chạm đất
	await get_tree().create_timer(0.12).timeout  # buffer nhỏ trước khi check
	while not is_on_floor():
		await get_tree().physics_frame

	# Đánh ngay khi đáp xuống
	_is_in_action = false
	if not is_dead and _dist_to_player() <= attack_range * 1.3:
		_do_attack()
	else:
		_decide_next_action()

## Dodge (lùi hoặc nhảy né)
func _do_dodge() -> void:
	_is_in_action = true
	_change_state(State.DODGE)
	_dodge_cd_timer = dodge_cooldown

	var dir = _dir_to_player()
	_flip_toward(dir > 0)

	# 50% nhảy lên né, 50% lùi ngang
	if randf() < 0.5 and is_on_floor():
		# Nhảy né
		velocity.y = jump_force * 0.75
		velocity.x = -dir * _current_speed() * 0.8
		_play_anim("jump")
		await get_tree().create_timer(0.5).timeout
	else:
		# Lùi ngang nhanh
		velocity.x = -dir * _current_speed() * 1.5
		_play_anim("run")
		await get_tree().create_timer(0.3).timeout
		velocity.x = 0

	_is_in_action = false
	_decide_next_action()

# ────────────────────────────────────────────────────────────────────────────
# Damage System
# ────────────────────────────────────────────────────────────────────────────

func take_damage(amount: float) -> void:
	if is_dead: return

	current_health = max(0.0, current_health - amount)
	_update_health_bar()

	# Kích hoạt Phase 2
	if not _phase2_active and current_health / max_health <= 0.4:
		_activate_phase2()

	if current_health <= 0.0:
		_die()
		return

	# Hurt stagger (ngắt action hiện tại)
	if _is_in_action:
		_is_in_action = false
		if melee_hitbox:
			melee_hitbox.monitoring = false

	_change_state(State.HURT)
	anim.speed_scale = 1.0
	_play_anim("hurt")
	_play_sfx("hurt")
	_flash_hurt()

	await get_tree().create_timer(0.4).timeout
	if not is_dead:
		_decide_next_action()

func apply_knockback(direction: Vector2, force: float) -> void:
	if is_dead: return
	velocity += direction.normalized() * force

func apply_knockback_distance(direction: Vector2, distance_px: float, duration: float = 0.35) -> void:
	if is_dead: return
	var target_pos = global_position + direction.normalized() * distance_px
	var tw = create_tween()
	tw.tween_property(self, "global_position", target_pos, duration)\
		.set_ease(Tween.EASE_OUT)\
		.set_trans(Tween.TRANS_QUAD)

func _on_melee_hit(body: Node) -> void:
	if body == self: return
	if body.has_method("take_damage"):
		body.take_damage(attack_damage)

func _die() -> void:
	if is_dead: return
	is_dead = true
	_is_in_action = false
	_change_state(State.DEATH)

	if melee_hitbox:
		melee_hitbox.monitoring = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if _health_bar:
		_health_bar.visible = false

	anim.speed_scale = 1.0
	_play_sfx("die")
	if anim.sprite_frames.has_animation("die"):
		anim.sprite_frames.set_animation_loop("die", false)
		_play_anim("die")
		await anim.animation_finished

	queue_free()

# ────────────────────────────────────────────────────────────────────────────
# Phase 2
# ────────────────────────────────────────────────────────────────────────────

func _activate_phase2() -> void:
	_phase2_active = true
	# Flash đỏ để báo hiệu phase 2
	var tw = create_tween().set_loops(4)
	tw.tween_property(anim, "modulate", Color(1.0, 0.2, 0.2, 1.0), 0.1)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.1)
	print("[ThuỷTinh Boss] PHASE 2 ACTIVATED!")

# ────────────────────────────────────────────────────────────────────────────
# Helpers
# ────────────────────────────────────────────────────────────────────────────

func _dist_to_player() -> float:
	if player == null: return 9999.0
	return abs(player.global_position.x - global_position.x)

func _dir_to_player() -> float:
	if player == null: return 1.0
	return sign(player.global_position.x - global_position.x)

func _current_speed() -> float:
	return move_speed + (phase2_speed_bonus if _phase2_active else 0.0)

## Kiểm tra player có đang trong trạng thái tấn công không
func _is_player_attacking() -> bool:
	if player == null: return false
	if player.has_method("get") and "is_attacking" in player:
		return player.is_attacking
	if player.has_method("get") and "is_skill_active" in player:
		return player.is_skill_active
	return false

func _change_state(new_state: State) -> void:
	_prev_state = _state
	_state = new_state

func _flip_toward(facing_right: bool) -> void:
	anim.flip_h = not facing_right  # Sprite mặc định nhìn trái → flip khi nhìn phải

func _update_hitbox_dir() -> void:
	if melee_hitbox and melee_hitbox.has_node("CollisionShape2D"):
		var col = melee_hitbox.get_node("CollisionShape2D")
		var dir = _dir_to_player()
		col.position.x = abs(col.position.x) * dir

func _play_anim(anim_name: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(anim_name):
		if anim.animation != anim_name:
			anim.play(anim_name)

func _flash_hurt() -> void:
	var tw = create_tween().set_loops(2)
	tw.tween_property(anim, "modulate", Color(1.0, 0.35, 0.35, 1.0), 0.07)
	tw.tween_property(anim, "modulate", Color.WHITE, 0.07)

# ── Audio ────────────────────────────────────────────────────────────────────

func _load_audio() -> void:
	var folder = "thuy_tinh"
	var anims = ["attack", "die", "hurt", "idle", "run", "jump"]
	for a in anims:
		var path = "res://assets/audio/character/%s/%s.mp3" % [folder, a]
		if ResourceLoader.exists(path):
			_sfx_cache[a] = load(path)

func _play_sfx(anim_name: String) -> void:
	if not _sfx_cache.has(anim_name) or not sfx_player: return
	sfx_player.stop()
	sfx_player.stream = _sfx_cache[anim_name]
	sfx_player.play()

# ── Health Bar ───────────────────────────────────────────────────────────────

func _create_health_bar() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.size = Vector2(80, 10)
	_health_bar.position = Vector2(-40, -80)
	_health_bar.value = 100.0

	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.15, 0.15, 0.15, 0.9)
	sb_bg.corner_radius_top_left = 3; sb_bg.corner_radius_top_right = 3
	sb_bg.corner_radius_bottom_left = 3; sb_bg.corner_radius_bottom_right = 3

	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.0, 0.5, 1.0, 1.0)  # Xanh nước - Thủy Tinh
	sb_fill.corner_radius_top_left = 3; sb_fill.corner_radius_top_right = 3
	sb_fill.corner_radius_bottom_left = 3; sb_fill.corner_radius_bottom_right = 3

	_health_bar.add_theme_stylebox_override("background", sb_bg)
	_health_bar.add_theme_stylebox_override("fill", sb_fill)
	add_child(_health_bar)

func _update_health_bar() -> void:
	if _health_bar and max_health > 0:
		_health_bar.value = (current_health / max_health) * 100.0
