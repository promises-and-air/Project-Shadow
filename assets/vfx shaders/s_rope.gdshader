shader_type spatial;
render_mode unshaded, cull_disabled, blend_add; // Unshaded для яркого свечения, blend_add для магии

uniform vec4 color : source_color = vec4(0.0, 1.0, 0.8, 1.0); // Призрачно-бирюзовый
uniform float speed : hint_range(-5.0, 5.0) = 2.0; // Скорость потока энергии
uniform float beam_length : hint_range(0.0, 100.0) = 1.0; // Длина луча (передадим из кода)
uniform float tile_factor : hint_range(0.1, 10.0) = 5.0; // Как часто повторяется текстура на 1 метр

// Текстура луча (нужна бесшовная вертикальная текстура: цепь, молния или луч)
uniform sampler2D beam_texture : source_color, repeat_enable, filter_linear_mipmap;

void fragment() {
    // 1. Коррекция UV
    // Мы растягиваем UV по Y в зависимости от реальной длины луча, 
    // чтобы текстура не выглядела растянутой.
    vec2 new_uv = UV;
    new_uv.y = (new_uv.y * beam_length * tile_factor) + (TIME * speed);
    
    // 2. Чтение текстуры
    vec4 tex = texture(beam_texture, new_uv);
    
    // 3. Цвет и прозрачность
    // Используем канал цвета текстуры или просто альфу
    ALBEDO = color.rgb * tex.rgb;
    
    // Мягкие края по бокам (градиент по X)
    float side_fade = smoothstep(0.0, 0.2, UV.x) * smoothstep(1.0, 0.8, UV.x);
    
    ALPHA = color.a * tex.a * side_fade;
}