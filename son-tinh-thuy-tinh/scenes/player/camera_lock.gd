extends Camera2D

@export var lookahead_distance: float = 150.0
@export var lookahead_speed: float = 2.0
# Offset Y cố định (camera nhìn lên trên so với player)
@export var camera_y_offset: float = -1.0

@onready var player = get_parent()
@onready var anim = player.get_node("AnimatedSprite2D") if player.has_node("AnimatedSprite2D") else null

func _ready():
	# Mặc định limit rộng, sẽ được chỉnh lại khi scene sẵn sàng
	limit_top = -10000
	limit_bottom = 10000
	call_deferred("_init_camera_limits")

func _init_camera_limits():
	# Đợi 2 frame để toàn bộ scene tree + vật lý sẵn sàng
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Khoá Y: set limit_top = limit_bottom = vị trí Y camera hiện tại
	# → camera không scroll dọc khi player nhảy
	var locked_y = int(global_position.y + camera_y_offset)
	limit_top    = locked_y - 1
	limit_bottom = locked_y + 1
	print("Camera: Y locked at ", locked_y)

	# Quét LevelBounds để set limit X
	var bounds_nodes = []
	_find_level_bounds(get_tree().current_scene, bounds_nodes)
	for node in bounds_nodes:
		var x = node.global_position.x
		if node.name.to_lower().contains("right"):
			limit_right = int(x)
			if player.has_method("set_right_bound"):
				player.set_right_bound(x)
			print("Camera: limit_right = ", x)
		else:
			limit_left = int(x)
			if player.has_method("set_left_bound"):
				player.set_left_bound(x)
			print("Camera: limit_left = ", x)

func _find_level_bounds(node: Node, result: Array):
	if node is LevelBounds:
		result.append(node)
	for child in node.get_children():
		_find_level_bounds(child, result)

func _process(delta):
	# Lookahead X mượt dùng offset
	if anim:
		var target_x = -lookahead_distance if anim.flip_h else lookahead_distance
		offset.x = lerp(offset.x, target_x, lookahead_speed * delta)
	# Giữ offset Y cố định (camera nhìn lên trên)
	offset.y = camera_y_offset
