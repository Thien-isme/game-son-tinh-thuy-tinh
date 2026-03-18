extends Control

@onready var frames_display: TextureRect = $FramesDisplay

# Lưu trữ danh sách các đường dẫn ảnh đã quét được theo thứ tự
var _image_paths: Array[String] = []
var _current_index: int = 0
var timer: float = 0.0
var is_playing: bool = true

# Cấu hình phát
var fps: float = 30.0
var frame_duration: float = 1.0 / 30.0

func _ready() -> void:
	# Quét toàn bộ ảnh thực tế còn lại trong 3 thư mục
	_scan_all_images()
	
	if _image_paths.size() > 0:
		# Tính toán lại FPS để ép thời lượng chuẩn thành 60 giây (1 phút)
		# Công thức: Tổng số Khung hình / Tổng thời gian
		fps = float(_image_paths.size()) / 60.0
		frame_duration = 1.0 / fps
		
		# Load frame đầu tiên
		_load_frame(_image_paths[0])
	else:
		_go_to_map1()

func _scan_all_images() -> void:
	_image_paths.clear()
	
	# Duyệt qua cả 3 thư mục (intro_1, intro_2, intro_3)
	for part in range(1, 4):
		var dir_path: String = "res://assets/video/intro/intro_%d/" % part
		# Mở thư mục
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var file_name = dir.get_next()
			
			# Lấy danh sách ảnh tạm
			var temp_files: Array[String] = []
			while file_name != "":
				# Bỏ qua thư mục và lấy đúng file jpg
				if not dir.current_is_dir() and file_name.ends_with(".jpg"):
					temp_files.append(dir_path + file_name)
				file_name = dir.get_next()
			
			# Sắp xếp lại file theo alpha-beta để đảm bảo đúng thứ tự 0001 -> 0xxx
			temp_files.sort()
			
			# Thêm vào mảng chính
			_image_paths.append_array(temp_files)
		else:
			print("Không thể mở thư mục Intro part: ", part)

func _unhandled_input(event: InputEvent) -> void:
	# Bỏ qua Intro nếu nhấn Enter (ui_accept), Esc (ui_cancel) hoặc click chuột
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel") or (event is InputEventMouseButton and event.pressed):
		_go_to_map1()

func _process(delta: float) -> void:
	if not is_playing or _image_paths.size() == 0:
		return
		
	timer += delta
	# Đã đến lúc chuyển sang cảnh ảnh tiếp theo
	if timer >= frame_duration:
		timer -= frame_duration 
		_advance_frame()

func _advance_frame() -> void:
	_current_index += 1
	
	# Kiểm tra xem đã hết mảng ảnh chưa
	if _current_index >= _image_paths.size():
		_go_to_map1()
		return
		
	_load_frame(_image_paths[_current_index])

func _load_frame(path: String) -> void:
	# Load và hiển thị frame
	if ResourceLoader.exists(path):
		var tex: Texture2D = load(path)
		frames_display.texture = tex
	else:
		# Trường hợp lỗi nạp
		pass

func _go_to_map1() -> void:
	is_playing = false
	get_tree().change_scene_to_file("res://scenes/map/map_1.tscn")
