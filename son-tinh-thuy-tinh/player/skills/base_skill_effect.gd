extends Area2D
class_name BaseSkillEffect

# Các thông số có thể tinh chỉnh cho từng skill
@export var damage: float = 20.0
@export var is_player_facing_right: bool = true

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

func _ready():
	# Gắn tín hiệu khi có người/quái đi vào vùng sát thương
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)
	
	print(">>> Skill Spawned! Z-Index set to 100.")
	z_index = 100 # Đảm bảo hỉện thị đè lên mọi background/tilemap
	
	if anim:
		# Gắn tín hiệu chạy xong animation thì tự hủy
		anim.animation_finished.connect(_on_animation_finished)
		anim.play() # Tự động chạy animation mặc định
		
		# Lật toàn bộ kỹ năng (VFX + Vùng sát thương) dựa theo hướng đứng của Player
		if not is_player_facing_right:
			scale.x = -1
		else:
			scale.x = 1

func _on_body_entered(body: Node2D):
	# Nếu đối tượng chạm vào thuộc nhóm "enemy" và có hàm take_damage
	if body.is_in_group("enemy") and body.has_method("take_damage"):
		body.take_damage(damage)

func _on_area_entered(area: Area2D):
	# Phá hủy đạn của kẻ địch nếu đạn bay vào kĩ năng
	# Hầu hết đạn đích đều có hàm `_explode`
	if area.has_method("_explode") and not area.is_in_group("player_bullet"):
		area._explode()

func _on_animation_finished():
	# Hoạt ảnh hiệu ứng kết thúc -> tự xóa
	queue_free()
