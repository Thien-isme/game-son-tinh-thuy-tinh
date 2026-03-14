extends Area2D

# Sát thương mỗi giây
@export var damage_per_second: float = 10.0
# Thời gian tồn tại của vòng lửa
@export var duration: float = 3.0

var active_enemies: Array = []
var life_timer: float = 0.0
@onready var anim = $AnimatedSprite2D

var target_pos: Vector2 = Vector2.INF
var velocity: Vector2 = Vector2.ZERO
var custom_gravity: float = 1500.0  # Trọng lực giả để ném xiên
var is_exploded: bool = false
var flight_duration: float = 0.5
var current_flight_time: float = 0.0

func _ready():
	# Mask 1 = Enemy group
	collision_mask = 1
	z_index = 100
	
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	if target_pos != Vector2.INF:
		# Tính toán vận tốc ném xiên để đến target_pos trong khoảng flight_duration
		var displacement = target_pos - global_position
		velocity.x = displacement.x / flight_duration
		velocity.y = (displacement.y - 0.5 * custom_gravity * flight_duration * flight_duration) / flight_duration
		
		if anim:
			anim.play("fly")
	else:
		_explode()
		
func _physics_process(delta):
	if not is_exploded:
		current_flight_time += delta
		velocity.y += custom_gravity * delta
		global_position += velocity * delta
		
		# Nhìn theo hướng ném
		rotation = velocity.angle()
		
		if current_flight_time >= flight_duration:
			global_position = target_pos
			_explode()
	else:
		life_timer -= delta
		if life_timer <= 0:
			queue_free()
			return
			
		var i = active_enemies.size() - 1
		while i >= 0:
			var enemy = active_enemies[i]
			if enemy != null and is_instance_valid(enemy):
				if enemy.has_method("take_damage"):
					enemy.take_damage(damage_per_second * delta)
			else:
				active_enemies.remove_at(i)
			i -= 1

func _explode():
	if is_exploded: return
	is_exploded = true
	life_timer = duration
	rotation = 0 # Trả vòng lửa về góc thẳng đứng dưới đất
	
	if anim:
		anim.play("explode")
	
	# Khi nổ, kiểm tra ngay xem có quái nào đang nằm trong vùng này không
	var bodies = get_overlapping_bodies()
	for body in bodies:
		if body.is_in_group("enemy") and not active_enemies.has(body):
			active_enemies.append(body)

func _on_body_entered(body: Node2D):
	# Chỉ bắt đầu theo dõi kẻ địch nếu đã nổ. 
	# Không cho nổ sớm khi đang bay (bỏ qua lệnh _explode() ở đây)
	if is_exploded and body.is_in_group("enemy"):
		if not active_enemies.has(body):
			active_enemies.append(body)

func _on_body_exited(body: Node2D):
	if active_enemies.has(body):
		active_enemies.erase(body)
