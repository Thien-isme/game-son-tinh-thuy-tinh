extends Camera2D

var initial_y: float
@export var lookahead_distance: float = 150.0  # Khoảng cách nhìn rướn về phía trước
@export var lookahead_speed: float = 2.0       # Tốc độ liếc camera mượt mà

@onready var player = get_parent()
@onready var anim = player.get_node("AnimatedSprite2D") if player.has_node("AnimatedSprite2D") else null

func _ready():
	# Lưu lại tọa độ Y thực tế trên Level lúc vừa bắt đầu game
	initial_y = global_position.y

func _process(delta):
	# Ép Camera luôn nằm ở tọa độ Y ban đầu, kệ xác Player nhảy đi đâu
	global_position.y = initial_y
	
	# Tính toán nhìn rướn về phía trước (trục X)
	if anim:
		# Nếu lật trái (flip_h = true) thì nhìn sang trái (âm), ngược lại nhìn sang phải (dương)
		var target_offset_x = -lookahead_distance if anim.flip_h else lookahead_distance
		
		# Dùng lerp để camera rê đi mượt mà chứ không giật cục
		position.x = lerp(position.x, target_offset_x, lookahead_speed * delta)
