import os

# Cố gắng import theo cả hai cách để tránh lỗi phiên bản
try:
    from moviepy.editor import VideoFileClip  # Cho MoviePy v1.x
except ImportError:
    from moviepy import VideoFileClip         # Cho MoviePy v2.x

def extract_audio_from_folder(folder_path):
    # Kiểm tra đường dẫn
    if not os.path.exists(folder_path):
        print(f"Lỗi: Không tìm thấy thư mục tại {folder_path}")
        return

    # Duyệt qua các file trong thư mục
    files = [f for f in os.listdir(folder_path) if f.lower().endswith(".mp4")]
    
    if not files:
        print("Không tìm thấy file .mp4 nào trong thư mục này.")
        return

    print(f"Tìm thấy {len(files)} file video. Bắt đầu chuyển đổi...\n")

    for file_name in files:
        video_path = os.path.join(folder_path, file_name)
        
        # Tạo tên file mp3 (giữ nguyên tên gốc, đổi đuôi)
        audio_name = os.path.splitext(file_name)[0] + ".mp3"
        audio_path = os.path.join(folder_path, audio_name)
        
        try:
            # Trích xuất âm thanh
            video = VideoFileClip(video_path)
            
            if video.audio is not None:
                # write_audiofile sẽ tự động dùng ffmpeg để convert
                video.audio.write_audiofile(audio_path, logger=None)
                print(f"[OK] Đã tạo: {audio_name}")
            else:
                print(f"[Skip] {file_name} không có dữ liệu âm thanh.")
            
            video.close()
            
        except Exception as e:
            print(f"[Lỗi] Không thể xử lý {file_name}: {e}")

# Đường dẫn đến project Godot của Thien
path = r"D:\GameWithGodot\game-son-tinh-thuy-tinh\son-tinh-thuy-tinh\assets\audio\character\thuy_tinh"

if __name__ == "__main__":
    extract_audio_from_folder(path)
    print("\n--- Hoàn tất! Chúc Thien làm game vui vẻ! ---")