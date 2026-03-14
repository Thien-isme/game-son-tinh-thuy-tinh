extends Camera2D

@export var lookahead_distance: float = 150.0  # Khoảng cách nhìn rướn về phía trước
@export var lookahead_speed: float = 2.0       # Tốc độ liếc camera mượt mà

@onready var player = get_parent()
@onready var anim = player.get_node("AnimatedSprite2D") if player.has_node("AnimatedSprite2D") else null

func _ready():
	# Không cần lưu initial_y nữa - Camera2D.limit_top/bottom sẽ handle Y
	# Đảm bảo limit mặc định rộng (player.gd sẽ set left/right)
	limit_top = -10000
	limit_bottom = 10000

func _process(delta):
	# Lookahead X mượt - dùng offset thay vì position để không bypass limit
	if anim:
		var target_offset_x = -lookahead_distance if anim.flip_h else lookahead_distance
		offset.x = lerp(offset.x, target_offset_x, lookahead_speed * delta)
