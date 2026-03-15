@tool
extends Node2D

## Nước dâng dần lên — gây chết khi player bị ngập quá 1/2 collision
@export var rise_speed: float = 60.0       ## Pixel/giây dâng lên
@export var start_delay: float = 2.0       ## Giây trước khi bắt đầu dâng
@export var water_width: float = 8000.0
@export var water_height: float = 5000.0

var _active: bool = false
var _player: Node = null
var _time: float = 0.0

@onready var _rect: ColorRect = $ColorRect


func _ready() -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return

	# Đặt kích thước rect
	_rect.size = Vector2(water_width, water_height)
	_rect.position = Vector2(-water_width / 2.0, 0)

	# Delay rồi bắt đầu dâng
	await get_tree().create_timer(start_delay).timeout
	_active = true

	# Tìm player
	await get_tree().process_frame
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		_player = players[0]


func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		_update_editor_preview()
		return
	if not _active:
		return

	# Cập nhật time cho shader sóng
	_time += delta
	if _rect.material is ShaderMaterial:
		(_rect.material as ShaderMaterial).set_shader_parameter("time_offset", _time)

	# Dâng lên
	position.y -= rise_speed * delta

	# Kiểm tra player chết
	_check_player_submerged()


func _check_player_submerged() -> void:
	if _player == null or not is_instance_valid(_player):
		var players = get_tree().get_nodes_in_group("player")
		if players.size() > 0:
			_player = players[0]
		return

	var water_surface_y: float = global_position.y
	var player_center_y: float = _player.global_position.y - 50.0

	if water_surface_y <= player_center_y:
		_kill_player()


func _kill_player() -> void:
	if not is_instance_valid(_player):
		return
	if _player.has_method("die_from_water"):
		_player.die_from_water()
	elif _player.has_method("take_damage"):
		_player.take_damage(9999.0)


func _update_editor_preview() -> void:
	if has_node("ColorRect"):
		$ColorRect.size = Vector2(water_width, water_height)
		$ColorRect.position = Vector2(-water_width / 2.0, 0)
