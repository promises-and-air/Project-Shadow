shader_type canvas_item;

// --- НАСТРОЙКИ ТЕНЕВОГО РЫВКА ---
uniform vec4 veil_color : source_color = vec4(0.05, 0.0, 0.1, 1.0); // Глубокий темный
uniform float intensity : hint_range(0.0, 2.0) = 0.0;
uniform float density : hint_range(0.0, 1.0) = 0.4;

// --- НАСТРОЙКИ ИСКАЖЕНИЯ (DISTORTION) ---
// Сила искажения. Для Dark Fantasy лучше небольшие значения, чтобы казалось, что пространство "плывет" от жара или магии.
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;

// --- НАСТРОЙКИ ИНДИКАТОРА ПЕРЕЗАРЯДКИ ---
// Цвет "призрачного вздоха" при готовности. Бледно-бирюзовый/мятный хорошо контрастирует с темным рывком.
uniform vec4 cooldown_flash_color : source_color = vec4(0.4, 0.8, 0.7, 1.0);
uniform float cooldown_flash_intensity : hint_range(0.0, 1.0) = 0.0;


// --- ТЕКСТУРЫ ---
// Текстура экрана для искажения (ОБЯЗАТЕЛЬНО)
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap;
// Наш шум дыма
uniform sampler2D noise_texture : repeat_enable, filter_linear_mipmap;
uniform float speed_1 : hint_range(-2.0, 2.0) = 0.15;
uniform float speed_2 : hint_range(-2.0, 2.0) = -0.08;


void fragment() {
    vec2 center = vec2(0.5, 0.5);
    float dist = distance(UV, center);
    
    // --- ГЕНЕРАЦИЯ ШУМА ---
    vec2 movement_1 = vec2(TIME * speed_1, TIME * speed_1 * 0.3);
    vec2 movement_2 = vec2(TIME * speed_2, -TIME * speed_2 * 0.5);
    
    // Читаем шум дважды для R и G каналов, чтобы получить вектор смещения
    vec2 noise_vec;
    noise_vec.x = texture(noise_texture, UV + movement_1).r;
    noise_vec.y = texture(noise_texture, UV * 1.3 + movement_2).g; // Используем другой канал или масштаб
    
    // Приводим шум из диапазона [0, 1] в диапазон [-1, 1] для движения в обе стороны
    noise_vec = (noise_vec * 2.0 - 1.0);
    
    // Комбинированный шум для маски
    float combined_noise_mask = (noise_vec.x + noise_vec.y) * 0.5 + 0.5;


    // --- ИСКАЖЕНИЕ (DISTORTION) ---
    // Маска искажения: центр чистый, края искажаются
    float distortion_mask = smoothstep(0.2, 0.9, dist);
    vec2 displaced_uv = SCREEN_UV + noise_vec * distortion_strength * distortion_mask * intensity; // Искажение зависит от интенсивности рывка
    
    // Читаем искаженный экран
    vec4 screen_color = texture(screen_texture, displaced_uv);


    // --- ТЕНЕВАЯ ЗАВЕСА (VEIL) ---
    // Формируем рваные края тьмы
    float smoke_edge = smoothstep(1.0 - intensity, 1.0 + intensity * 0.2, dist + combined_noise_mask * density * 0.5);
    vec4 final_veil = veil_color;
    final_veil.a *= smoke_edge;
    
    
    // --- ВСПЫШКА ПЕРЕЗАРЯДКИ (COOLDOWN FLASH) ---
    // Используем тот же шум, но для яркой вспышки по краям
    float flash_edge = smoothstep(0.6, 1.0, dist + combined_noise_mask * 0.2);
    vec4 final_flash = cooldown_flash_color;
    final_flash.a *= flash_edge * cooldown_flash_intensity;

    
    // --- ФИНАЛЬНЫЙ КОМПОЗИТ ---
    // 1. Берем искаженный экран.
    // 2. Накладываем темную завесу (через alpha blending).
    // 3. Накладываем вспышку перезарядки (аддитивно или через alpha, здесь alpha для мягкости).
    
    vec4 output = screen_color;
    output = mix(output, final_veil, final_veil.a); // Наложение тьмы
    output = mix(output, final_flash, final_flash.a); // Наложение вспышки
    
    COLOR = output;
}