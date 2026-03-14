extends Area2D

var direction = Vector2.RIGHT
var speed = 400.0
var damage: float = 10.0
var shooter: Node2D = null # Tham chiếu tới Player bắn ra đạn này

@export var hit_sfx: AudioStream

@onready var anim = $AnimatedSprite2D
@onready var hit_audio = $HitAudio

func _ready():
	anim.play("fly")  # Bắt đầu với animation bay
	if hit_sfx:
		hit_audio.stream = hit_sfx

func _physics_process(delta):
	position += direction * speed * delta

func hit_enemy(enemy):
	# Tắt di chuyển và collision
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	
	# Chơi animation explode
	anim.play("explode")
	
	# Phát âm thanh trúng đạn
	if hit_audio and hit_audio.stream:
		hit_audio.play()
	
	# Gây damage cho enemy
	if enemy.has_method("take_damage"):
		enemy.take_damage(damage)
		
	# Hồi máu cho Player khi trúng quái
	if shooter and shooter.has_method("heal"):
		shooter.heal(0.5)
	
	# Chờ animation xong rồi xóa đạn
	# Lưu ý: Nếu âm thanh dài hơn animation, đạn vẫn sẽ tồn tại cho đến khi anim xong.
	# Nếu muốn chờ cả âm thanh, có thể dùng await hit_audio.finished
	await anim.animation_finished
	queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemy"):
		hit_enemy(body)


func _on_visible_on_screen_notifier_2d_screen_exited() -> void:
	queue_free()
