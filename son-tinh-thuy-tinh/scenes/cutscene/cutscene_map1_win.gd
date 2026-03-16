## Cutscene sau khi thắng Map 1.
## Audio "son-tinh-ruoc-mi-nuong.mp3" dài 37s, bao phủ CẢ 2 clip.
##
## Tính toán FPS:
##   Clip 1: 170 frames (0023→0192)
##   Clip 2: 475 frames (0026→0500)
##   Tổng:   645 frames / 37 giây = 17.43 fps

extends "res://scenes/cutscene/cutscene.gd"

func _ready() -> void:
	var TOTAL_FPS: float = 645.0 / 37.0  # = 17.432...

	clips = [
		{
			"folder": "son-tinh-ruoc-mi-nuong",
			"first": 23,
			"last": 192,
			"fps": TOTAL_FPS,
			# Audio phát từ đây, sẽ chạy xuyên suốt cả 2 clip
			"audio_path": "res://assets/audio/son-tinh-ruoc-mi-nuong/son-tinh-ruoc-mi-nuong.mp3"
		},
		{
			"folder": "thuy-tinh-den-sau",
			"first": 26,
			"last": 500,
			"fps": TOTAL_FPS
			# Không có audio_path → audio không bị tắt hay phát lại
		}
	]
	next_scene_path = "res://scenes/map/map_2.tscn"
	super._ready()
