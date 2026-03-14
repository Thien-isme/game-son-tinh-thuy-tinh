@tool
extends CharacterBody2D

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
@export var attack_sfx: AudioStream
@export var die_sfx: AudioStream
@export var hurt_sfx: AudioStream

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

func _create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.show_percentage = false
	health_bar.size = Vector2(40, 6)
	health_bar.position = Vector2(-20, -55)
	health_bar.value = 100.0

	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.2, 0.2, 0.2, 0.8)
	sb_bg.corner_radius_top_left = 2
	sb_bg.corner_radius_top_right = 2
	sb_bg.corner_radius_bottom_left = 2
	sb_bg.corner_radius_bottom_right = 2

	var sb_fill = StyleBoxFlat.new()
	sb_fill.bg_color = Color(0.9, 0.2, 0.2, 1.0)
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
		velocity.y += GRAVITY * delta
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

	is_patrol_waiting = false

	if is_attacking:
		# Trong tầm tấn công → đứng yên và đánh
		velocity.x = 0
		var facing_dir = -1 if player.global_position.x < global_position.x else 1
		anim.flip_h = facing_dir < 0
		# Kích hoạt MeleeHitbox theo hướng
		if has_node("MeleeHitbox"):
			$MeleeHitbox.position.x = abs($MeleeHitbox.position.x) * facing_dir
		# Phát animation attack nếu có, nếu không thì idle
		if anim.sprite_frames.has_animation("attack"):
			if anim.animation != "attack":
				anim.play("attack")
		else:
			anim.play("idle")
		if can_attack:
			_do_melee_attack()
	else:
		# Đuổi theo player
		var facing_dir = sign(player.global_position.x - global_position.x)
		var at_ledge = false
		if avoid_ledges and floor_raycast != null and is_on_floor():
			floor_raycast.position.x = facing_dir * 30.0
			floor_raycast.force_raycast_update()
			if not floor_raycast.is_colliding():
				at_ledge = true

		if at_ledge:
			velocity.x = 0
			anim.play("idle")
		else:
			velocity.x = facing_dir * speed
			anim.flip_h = facing_dir < 0
			if anim.sprite_frames.has_animation("run"):
				anim.play("run")
			else:
				anim.play("idle")

	move_and_slide()

func _do_melee_attack():
	can_attack = false
	_play_sfx(attack_sfx)
	# Gây damage trực tiếp cho player nếu player có hàm take_damage
	if player and player.has_method("take_damage"):
		player.take_damage(melee_damage)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true

# --- Logic Tuần Tra ---
func _patrol_update():
	if is_patrol_waiting:
		velocity.x = 0
		anim.play("idle")
		return

	velocity.x = patrol_dir * patrol_speed
	anim.flip_h = patrol_dir < 0
	if anim.sprite_frames.has_animation("run"):
		anim.play("run")
	else:
		anim.play("idle")

	var reached_target = false
	if patrol_dir == 1 and global_position.x >= patrol_target_x:
		reached_target = true
	elif patrol_dir == -1 and global_position.x <= patrol_target_x:
		reached_target = true
	if is_on_wall():
		reached_target = true
	if avoid_ledges and floor_raycast != null and is_on_floor():
		floor_raycast.position.x = patrol_dir * 30.0
		floor_raycast.force_raycast_update()
		if not floor_raycast.is_colliding():
			reached_target = true

	if reached_target:
		_start_patrol_wait()

func _start_patrol_wait():
	is_patrol_waiting = true
	velocity.x = 0
	anim.play("idle")
	patrol_dir *= -1
	patrol_target_x = start_x + patrol_distance * patrol_dir
	await get_tree().create_timer(patrol_wait_time).timeout
	is_patrol_waiting = false

func take_damage(amount: float):
	if is_dead: return
	health -= amount
	if health_bar and max_health > 0:
		health_bar.value = (health / max_health) * 100.0
	if has_node("AnimatedSprite2D") and anim.sprite_frames.has_animation("hurt"):
		anim.play("hurt")
	if health <= 0:
		_die()

func _die():
	if is_dead: return
	is_dead = true
	_play_sfx(die_sfx)
	if health_bar:
		health_bar.visible = false
	if has_node("CollisionShape2D"):
		$CollisionShape2D.set_deferred("disabled", true)
	if has_node("DetectZone/CollisionShape2D"):
		$DetectZone/CollisionShape2D.set_deferred("disabled", true)
	if has_node("AttackZone/CollisionShape2D"):
		$AttackZone/CollisionShape2D.set_deferred("disabled", true)
	if has_node("MeleeHitbox/CollisionShape2D"):
		$MeleeHitbox/CollisionShape2D.set_deferred("disabled", true)
	if anim and anim.sprite_frames.has_animation("die"):
		anim.play("die")
		await anim.animation_finished
	queue_free()

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
		# Vòng Phát Hiện
		if detect_radius > 0:
			draw_circle(Vector2.ZERO, detect_radius, Color(0.1, 0.8, 0.8, 0.2))
		# Vòng Tấn Công Cận Chiến
		if attack_radius > 0:
			draw_circle(Vector2.ZERO, attack_radius, Color(0.9, 0.1, 0.3, 0.3))
		# Khoảng tuần tra
		if patrol_distance > 0:
			draw_line(Vector2(-patrol_distance, 0), Vector2(patrol_distance, 0), Color.YELLOW, 1.0)
			draw_line(Vector2(-patrol_distance, -10), Vector2(-patrol_distance, 10), Color.YELLOW, 2.0)
			draw_line(Vector2(patrol_distance, -10), Vector2(patrol_distance, 10), Color.YELLOW, 2.0)
