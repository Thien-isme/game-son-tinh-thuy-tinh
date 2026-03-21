from moviepy import VideoFileClip
import os

video_name = "Video_11.mp4"

def split_video_into_three(filename):
    if not os.path.exists(filename):
        print(f"Không tìm thấy file {filename}.")
        return

    # Mở video lần 1 chỉ để lấy tổng thời gian
    with VideoFileClip(filename) as clip:
        total_duration = clip.duration
    
    part_duration = total_duration / 3.0
    print(f"Tổng thời lượng: {total_duration}s. Mỗi đoạn: {part_duration:.2f}s.\n")

    for i in range(3):
        start_time = i * part_duration
        end_time = (i + 1) * part_duration if i < 2 else total_duration 
        output_name = f"intro_part_{i + 1}.mp4"
        
        print(f"Đang xử lý {output_name} (từ {start_time:.2f} đến {end_time:.2f})...")
        
        # Mở lại file video gốc cho TỪNG ĐOẠN để luồng dữ liệu không bị đóng giữa chừng
        with VideoFileClip(filename) as current_clip:
            subclip_video = current_clip.subclipped(start_time, end_time)
            subclip_video.write_videofile(output_name, codec="libx264", audio_codec="aac", logger=None)
        
        print(f"Đã lưu thành công: {output_name}\n")

    print("Hoàn thành việc cắt video!")

# Chạy hàm
split_video_into_three(video_name)