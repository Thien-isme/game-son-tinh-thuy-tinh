# Scene Management - Son Tinh Thuy Tinh

## Cấu trúc thư mục

```
scenes/
├── background/
│   ├── level_1.tscn          ← Background 3 layer level 1 (đã có assets)
│   ├── level_2.tscn          ← Placeholder (chưa có assets)
│   ├── level_3.tscn          ← Placeholder (chưa có assets)
│   ├── level_4.tscn          ← Placeholder (chưa có assets)
│   └── parallax_auto_mirror.gd ← Script tự set motion_mirroring
├── map/
│   ├── map_1.tscn            ← Level 1 (main scene)
│   ├── map_2.tscn            ← Level 2
│   ├── map_3.tscn            ← Level 3
│   └── map_4.tscn            ← Level 4
├── player/
│   ├── player.tscn
│   ├── player.gd
│   └── camera_lock.gd        ← Lock trục Y + lookahead X
└── enemies/
    └── [tên_enemy]/
```

---

## Cấu trúc bên trong mỗi Map

```
MapX (Node2D)                 ← Root scene
│
├── Background                ← instance level_X.tscn, z_index = -10
│   └── ParallaxBackground
│       ├── Layer1_Far        motion_scale = (0.1, 0) — trời/núi xa
│       ├── Layer2_Mid        motion_scale = (0.4, 0) — rừng giữa
│       └── Layer3_Near       motion_scale = (0.7, 0) — cây gần
│
├── World (Node2D)            ← Toàn bộ thứ có thể va chạm
│   ├── TileMapLayer          ← Vẽ địa hình từ Tilemap_X.png
│   ├── Floor (StaticBody2D)  ← Sàn tạm (xóa sau khi có TileMap đầy đủ)
│   ├── Enemies (Node2D)      ← Kéo enemy instances vào đây
│   └── Items (Node2D)        ← Items, chest, collectibles
│
├── LevelBounds (Node2D)      ← Giới hạn camera trái/phải
│
└── Player                    ← instance player.tscn
```

---

## Quy tắc quan trọng

### Background (ParallaxBackground)
- **`motion_scale`**: trục Y luôn = 0 (camera_lock.gd đã khóa Y)
- **`motion_mirroring`**: script `parallax_auto_mirror.gd` tự set = chiều rộng texture
- Khi thêm assets mới cho level 2/3/4: kéo ảnh vào `Sprite2D` trong từng layer

### Camera (`camera_lock.gd`)
- Khóa tọa độ Y: camera không lắc theo nhảy
- Lookahead X: camera nhìn rướn về hướng player đang mặt
- Export: `lookahead_distance = 150`, `lookahead_speed = 2.0`

### Player
- `camera_lock.gd` gắn vào `Camera2D` con của player
- Ranh giới map được set từ `LevelBounds` → gọi `player.set_left_bound()` / `player.set_right_bound()`

### Enemies
- Luôn đặt trong node `World/Enemies`
- Group name: `"enemies"` — để bullet/skill dùng `get_tree().get_nodes_in_group("enemies")`

### TileMapLayer
- TileSet tạo từ `assets/background/level_X/Tilemap_X.png`
- Kích thước tile: cần xác định khi setup (32x32 hoặc 64x64)
- Tile có collision → thêm Physics Layer trong TileSet Editor

---

## Chuyển cảnh giữa các map

```gdscript
# Ví dụ chuyển sang map_2 khi player đến cuối map
get_tree().change_scene_to_file("res://scenes/map/map_2.tscn")
```

---

## Checklist khi tạo map mới

- [ ] Tạo `scenes/background/level_X.tscn` với 3 ParallaxLayer
- [ ] Kéo ảnh Background/Midground/Foreground vào các Sprite2D
- [ ] Tạo `scenes/map/map_X.tscn` từ template cấu trúc chuẩn
- [ ] Setup TileMapLayer với TileSet đúng
- [ ] Đặt Player spawn position
- [ ] Set LevelBounds (Camera limit trái/phải)
- [ ] Kéo enemy vào `World/Enemies`
