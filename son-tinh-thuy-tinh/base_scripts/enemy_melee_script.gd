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

@export_category("Patrol Settings")
@export var patrol_distance: float = 100.0 :
	set(value):
		patrol_distance = value
		queue_redraw()
@export var patrol_speed: float = 40.0
@export var patrol_wait_time: float = 1.5
@export var avoid_ledges: bool = true

@export_category("Audio")
@export var override_audio_folder: String = ""

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
		var shape = get_node(zone_name + "/CollisionShape2D").shape as CircleShape2D
		if shape:
			shape.set_deferred("radius", radius_value)

# State
var player = null
var can_attack = true
var is_attacking = false
var is_dead = false
var max_health: float = 1.0
var health_bar: ProgressBar = null

# Patrol
var start_x: float = 0.0
var patrol_target_x: float = 0.0
var patrol_dir: int = 1
var is_patrol_waiting: bool = false
var floor_raycast: RayCast2D = null

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
	# Tất cả animation chạy full 60fps, audio sẽ speed up để khớp
	return 1.0

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

	if detect_radius > 0 and has_node("DetectZone/CollisionShape2D"):
		var d_shape = $DetectZone/CollisionShape2D.shape as CircleShape2D
		if d_shape:
			var new_d = d_shape.duplicate()
			new_d.radius = detect_radius
			$DetectZone/CollisionShape2D.set_deferred("shape", new_d)

	if attack_radius > 0 and has_node("AttackZone/CollisionShape2D"):
		var a_shape = $AttackZone/CollisionShape2D.shape as CircleShape2D
		if a_shape:
			var new_a = a_shape.duplicate()
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

# ---- Audio ----

func _load_audio_for_enemy():
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
		var path = "res://assets/audio/character/%s/%s.mp3" % [folder, anim_name]
		if ResourceLoader.exists(path):
			_sfx_cache[anim_name] = load(path)

func _play_sfx(anim_name: String):
	if _sfx_cache.has(anim_name) and sfx_player:
		# Dừng audio cũ ngay, không chờ kết thúc
		sfx_player.stop()
		var pitch = 1.0
		if _frame_counts.has(anim_name):
			var effective_fps = SPRITEFRAMES_SPEED * anim.speed_scale
			var anim_duration = _frame_counts[anim_name] / effective_fps
			pitch = clampf(AUDIO_DURATION / anim_duration, 0.1, 4.0)
		sfx_player.pitch_scale = pitch
		sfx_player.stream = _sfx_cache[anim_name]
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

	if not is_on_floor():
		velocity.y += GRAVITY * delta

	if player == null:
		if patrol_distance <= 0:
			velocity.x = 0
			_play_anim("idle", true)
		else:
			_patrol_update()
		move_and_slide()
		return

	is_patrol_waiting = false

	if is_attacking:
		velocity.x = 0
		var facing_dir = -1 if player.global_position.x < global_position.x else 1
		anim.flip_h = facing_dir < 0
		if has_node("MeleeHitbox"):
			$MeleeHitbox.position.x = abs($MeleeHitbox.position.x) * facing_dir
		if anim.sprite_frames.has_animation("attack"):
			_play_anim("attack")  # speed_scale = khớp audio 8s
		else:
			_play_anim("idle", true)
		if can_attack:
			_do_melee_attack()
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
			anim.flip_h = facing_dir < 0
			if anim.sprite_frames.has_animation("run"):
				_play_anim("run", true)
			elif anim.sprite_frames.has_animation("move"):
				_play_anim("move", true)
			elif anim.sprite_frames.has_animation("fly"):
				_play_anim("fly", true)
			else:
				_play_anim("idle", true)

	move_and_slide()

func _do_melee_attack():
	can_attack = false
	_play_sfx("attack")
	if player and player.has_method("take_damage"):
		player.take_damage(melee_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# ---- Patrol ----

func _patrol_update():
	if is_patrol_waiting:
		velocity.x = 0
		_play_anim("idle", true)
		return

	velocity.x = patrol_dir * patrol_speed
	anim.flip_h = patrol_dir < 0
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
	if anim.sprite_frames.has_animation("hurt"):
		_play_anim("hurt")
		_play_sfx("hurt")
	if health <= 0:
		_die()

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
		_play_anim("die")  # speed_scale = khớp audio 8s
		await anim.animation_finished
	queue_free()

# ---- Signals ----

func _on_detect_zone_body_entered(body):
	if body.is_in_group("player"): player = body

func _on_detect_zone_body_exited(body):
	if body.is_in_group("player"): player = null

func _on_attack_zone_body_entered(body):
	if body.is_in_group("player"): is_attacking = true

func _on_attack_zone_body_exited(body):
	if body.is_in_group("player"): is_attacking = false

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
