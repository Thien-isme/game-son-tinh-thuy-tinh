extends Camera2D

@export var lookahead_distance: float = 150.0
@export var lookahead_speed: float = 2.0
@export var camera_y_offset: float = -135.0  # Camera nhìn lên trên so với player

@onready var player = get_parent()
@onready var anim = player.get_node("AnimatedSprite2D") if player.has_node("AnimatedSprite2D") else null

var _locked_local_y: float = 0.0  # local Y cố định so với player
var _y_locked: bool = false

func _ready():
	limit_top = -10000
	limit_bottom = 10000
	call_deferred("_init_camera_limits")

func _init_camera_limits():
	await get_tree().physics_frame
	await get_tree().physics_frame

	# Chờ player đứng trên ground (is_on_floor) rồi mới lock Y
	var attempts = 0
	while not player.is_on_floor() and attempts < 60:
		await get_tree().physics_frame
		attempts += 1

	# Lock local Y (vị trí của Camera2D so với player khi đứng ổn định)
	_locked_local_y = camera_y_offset
	position.y = _locked_local_y
	_y_locked = true

	# Tắt drag dọc để camera không theo player khi nhảy
	drag_vertical_enabled = false
	# Giữ limit_top/bottom ở world Y hiện tại
	var world_y = int(global_position.y)
	limit_top    = world_y - 2
	limit_bottom = world_y + 2
	print("Camera: Y locked at world_y=", world_y, " local_y=", _locked_local_y)

	# Quét LevelBounds để set limit X
	var bounds_nodes = []
	_find_level_bounds(get_tree().current_scene, bounds_nodes)
	for node in bounds_nodes:
		var x = node.global_position.x
		if node.name.to_lower().contains("right"):
			limit_right = int(x)
			if player.has_method("set_right_bound"):
				player.set_right_bound(x)
		else:
			limit_left = int(x)
			if player.has_method("set_left_bound"):
				player.set_left_bound(x)

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

	# Fix cứng camera local Y sau khi đã lock
	# Bất kể player nhảy hay không, camera Y local luôn ở đã định
	if _y_locked:
		position.y = _locked_local_y
