extends Control

## Cutscene player – phát image sequence từ thư mục res://assets/video/
## Mỗi clip hỗ trợ: folder, first_frame, last_frame, fps (tùy chỉnh riêng), audio_path

var clips: Array = []
var next_scene_path: String = "res://scenes/map/map_2.tscn"

## FPS mặc định nếu clip không tự định nghĩa
@export var default_fps: float = 24.0

# --- State ---
var _current_clip: int = 0
var _current_frame: int = 0
var _timer: float = 0.0
var _playing: bool = false
var _current_fps: float = 24.0

@onready var frame_display: TextureRect = $FrameDisplay
@onready var skip_label: Label = $SkipLabel
@onready var audio_player: AudioStreamPlayer = $AudioPlayer

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if clips.size() > 0:
		_load_clip(0)
	else:
		_finish()

func _load_clip(index: int) -> void:
	_current_clip = index
	var clip = clips[index]
	_current_frame = clip["first"]
	_current_fps = clip.get("fps", default_fps)
	_timer = 0.0
	_playing = true

	# Phát audio nếu clip có cấu hình audio_path
	# Nếu không có → giữ nguyên audio đang phát (không tắt)
	if clip.has("audio_path"):
		var stream = load(clip["audio_path"])
		if stream:
			audio_player.stream = stream
			audio_player.play()

	_show_frame()

func _show_frame() -> void:
	var clip = clips[_current_clip]
	var folder: String = clip["folder"]
	var path = "res://assets/video/%s/%04d.jpg" % [folder, _current_frame]
	var tex = load(path)
	if tex:
		frame_display.texture = tex

func _process(delta: float) -> void:
	if not _playing:
		return
	_timer += delta
	var frame_time = 1.0 / _current_fps
	if _timer >= frame_time:
		_timer -= frame_time
		_advance_frame()

func _advance_frame() -> void:
	var clip = clips[_current_clip]
	_current_frame += 1
	if _current_frame > clip["last"]:
		_next_clip()
	else:
		_show_frame()

func _next_clip() -> void:
	# KHÔNG dừng audio khi chuyển clip — để audio tiếp tục chạy xuyên suốt
	_current_clip += 1
	if _current_clip < clips.size():
		_load_clip(_current_clip)
	else:
		_finish()

func _finish() -> void:
	_playing = false
	audio_player.stop()
	get_tree().change_scene_to_file(next_scene_path)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept") or \
	   (event is InputEventMouseButton and event.pressed):
		_finish()
