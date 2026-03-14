@tool
extends Marker2D

@export_category("Enemy Settings")
## Kéo thả scene quái vào đây (để trống thì dùng quái mặc định của Spawner Controller)
@export var enemy_scene: PackedScene

## Số quái tối đa từ điểm này
@export var max_enemies: int = 1

## Thời gian nghỉ (giây) giữa 2 lần spawn (để 0 xài của Spawner Controller)
@export var spawn_interval: float = 0.0

@export_category("Enemy Stats Overrides")
## Máu riêng (để 0 xài mặc định)
@export var override_health: float = 0.0
## Sát thương cận chiến riêng (để 0 xài mặc định)
@export var override_melee_damage: float = 0.0
## Thời gian giữa 2 đòn đánh (để 0 xài mặc định)
@export var override_attack_cooldown: float = 0.0
## Khoảng cách tuần tra (để 0 xài mặc định)
@export var override_patrol_distance: float = 0.0:
	set(value):
		override_patrol_distance = value
		queue_redraw()

@export_group("Preview Areas (Editor Only)")
## Bán kính detect preview (Xanh ngọc)
@export var override_detect_radius: float = 0.0:
	set(value):
		override_detect_radius = value
		queue_redraw()

## Bán kính attack preview (Đỏ)
@export var override_attack_radius: float = 0.0:
	set(value):
		override_attack_radius = value
		queue_redraw()

func _draw():
	if Engine.is_editor_hint():
		# Dấu chữ thập xanh để dễ nhìn
		draw_line(Vector2(-15, 0), Vector2(15, 0), Color.GREEN, 2.0)
		draw_line(Vector2(0, -15), Vector2(0, 15), Color.GREEN, 2.0)

		if override_detect_radius > 0:
			draw_circle(Vector2.ZERO, override_detect_radius, Color(0.1, 0.8, 0.8, 0.2))
		if override_attack_radius > 0:
			draw_circle(Vector2.ZERO, override_attack_radius, Color(0.9, 0.1, 0.3, 0.3))
		if override_patrol_distance > 0:
			var p = override_patrol_distance
			draw_line(Vector2(-p, 0), Vector2(p, 0), Color.YELLOW, 1.0)
			draw_line(Vector2(-p, -10), Vector2(-p, 10), Color.YELLOW, 2.0)
			draw_line(Vector2(p, -10), Vector2(p, 10), Color.YELLOW, 2.0)
