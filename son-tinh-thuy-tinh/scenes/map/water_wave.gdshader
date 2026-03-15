shader_type canvas_item;

// ---- Tham số sóng ----
uniform float wave_amplitude : hint_range(0.0, 0.05) = 0.015; // Tỷ lệ UV (không dùng px)
uniform float wave_speed     : hint_range(0.0, 10.0) = 2.5;
uniform float wave_frequency : hint_range(0.5, 10.0) = 2.0;

// ---- Màu nước ----
uniform vec4 water_color_deep    : source_color = vec4(0.03, 0.20, 0.65, 0.95);
uniform vec4 water_color_surface : source_color = vec4(0.15, 0.55, 0.95, 0.80);
uniform vec4 foam_color          : source_color = vec4(0.82, 0.94, 1.00, 0.85);

// ---- Thời gian (truyền từ GDScript) ----
uniform float time_offset : hint_range(0.0, 10000.0) = 0.0;

// ---- Shimmer ----
uniform float shimmer_speed    : hint_range(0.0, 10.0) = 3.0;
uniform float shimmer_strength : hint_range(0.0, 0.4)  = 0.10;

void fragment() {
    vec2 uv = UV;

    // --- Mặt sóng: 2 sine chồng nhau ---
    float t = time_offset;
    float wave1 = sin(uv.x * wave_frequency * TAU + t * wave_speed);
    float wave2 = sin(uv.x * wave_frequency * 1.7 * TAU - t * wave_speed * 0.65 + 1.3);
    float wave  = (wave1 * 0.6 + wave2 * 0.4) * 0.5 + 0.5;  // normalize 0..1

    // surface_uv: điểm cao nhất sóng nằm tại đây (UV y)
    float surface_uv = wave_amplitude * wave;

    // Vùng trên sóng → trong suốt hoàn toàn
    if (uv.y < surface_uv) {
        COLOR = vec4(0.0);
        return;
    }

    // --- Độ sâu tính từ mặt sóng xuống đáy ---
    float depth = clamp((uv.y - surface_uv) / (1.0 - surface_uv + 0.001), 0.0, 1.0);

    // --- Gradient màu ---
    vec4 water_col = mix(water_color_surface, water_color_deep, sqrt(depth));

    // --- Foam ngay dưới mặt sóng ---
    float foam_band = 1.0 - smoothstep(0.0, wave_amplitude * 2.0, uv.y - surface_uv);
    water_col = mix(water_col, foam_color, foam_band * 0.60);

    // --- Shimmer ánh sáng ---
    float shimmer = sin(uv.x * 9.0 * TAU + t * shimmer_speed)
                  * sin(uv.x * 5.7 * TAU - t * shimmer_speed * 1.2) * 0.5 + 0.5;
    shimmer *= (1.0 - smoothstep(0.0, 0.15, depth));  // Chỉ gần mặt nước
    water_col.rgb += shimmer * shimmer_strength;

    COLOR = water_col;
}
