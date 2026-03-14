extends ParallaxBackground

# Script này tự động set motion_mirroring cho mỗi ParallaxLayer
# bằng cách đọc chiều rộng thực của texture trong Sprite2D con

func _ready():
	for layer in get_children():
		if layer is ParallaxLayer:
			var sprite = layer.get_node_or_null("Sprite2D")
			if sprite and sprite.texture:
				var tex_width = sprite.texture.get_width() * abs(sprite.scale.x)
				layer.motion_mirroring = Vector2(tex_width, 0)
