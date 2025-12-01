shader_type spatial;
render_mode blend_add, cull_back, unshaded; // Unshaded для чистого света

uniform vec4 color : source_color = vec4(0.0, 0.5, 1.0, 1.0); // Цвет Неро (Голубой)
uniform float rim_power : hint_range(0.5, 8.0) = 3.0; // Сила свечения краев
uniform float pulse_speed : hint_range(0.0, 10.0) = 2.0;

void fragment() {
    // Эффект Френеля (свечение по краям)
    float fresnel = pow(1.0 - dot(NORMAL, VIEW), rim_power);
    
    // Пульсация
    float pulse = (sin(TIME * pulse_speed) * 0.2 + 0.8);
    
    ALBEDO = color.rgb;
    // Центр прозрачный, края светятся
    ALPHA = fresnel * color.a * pulse;
}