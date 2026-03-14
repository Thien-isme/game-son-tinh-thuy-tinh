@tool
extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 300.0
var damage: float = 10.0
var pass_terrain: bool = true

@onready var anim = $AnimatedSprite2D
var is_exploding = false
var shooter: Node2D = null # Lưu reference của quái bắn ra viên đạn này

func _ready():
	if anim:
		anim.play("fly")
	
	# Kết nối tín hiệu body_entered bằng code để không phải vào từng Scene cài đặt
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _physics_process(delta):
	if is_exploding:
		return
	
	# Di chuyển đạn theo hướng đã quay
	position += direction * speed * delta

func _on_body_entered(body):
	if is_exploding:
		return
		
	if body.is_in_group("player"):
		body.take_damage(damage)
		_explode()
	elif not pass_terrain and (body.name == "TileMap" or body.is_in_group("wall")): # Hoặc các group chứa tường/đất
		# Nổ khi trúng tường
		_explode()

func _explode():
	is_exploding = true
	
	if shooter != null and is_instance_valid(shooter):
		if shooter.has_method("play_explode_sfx"):
			shooter.play_explode_sfx()
	
	if anim and anim.sprite_frames.has_animation("explode"):
		anim.play("explode", 2.5) # Phát hoạt ảnh nổ nhanh gấp 2.5 lần
		await anim.animation_finished
	
	queue_free()
