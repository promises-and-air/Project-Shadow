shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture : source_color, filter_nearest_mipmap;
// 1. ДОБАВЛЯЕМ СЛОТ ДЛЯ NORMAL MAP
uniform sampler2D normal_texture : hint_normal, filter_linear_mipmap;

// --- ГЛОБАЛЬНЫЕ НАСТРОЙКИ ---
const vec3 FRESNEL_COLOR = vec3(0.5, 0.7, 1.0);
const float FRESNEL_POWER = 4.0;
const float FRESNEL_INTENSITY = 1.0;

const float LIGHT_OFFSET = 0.05;
const float SOFTNESS = 0.02;
// ----------------------------

void fragment() {
	vec4 albedo_tex = texture(albedo_texture, UV);
	ALBEDO = albedo_tex.rgb;
	
	// 2. ПРИМЕНЯЕМ NORMAL MAP
	// Просто читаем текстуру и отдаем движку. 
	// Он сам пересчитает NORMAL для функции light().
	vec3 n_tex = texture(normal_texture, UV).rgb;
	NORMAL_MAP = n_tex;
	
	// Расчет Френеля
	float dotNV = dot(NORMAL, VIEW);
	float fresnel_base = clamp(1.0 - dotNV, 0.0, 1.0);
	float fresnel_final = pow(fresnel_base, FRESNEL_POWER);
	EMISSION = ALBEDO * fresnel_final * FRESNEL_INTENSITY;
}

void light() {
	// Здесь менять ничего не нужно! 
	// Переменная NORMAL уже будет искажена картой нормалей автоматически.
	float NdotL = dot(NORMAL, LIGHT);
	float light_change = fwidth(NdotL) + SOFTNESS;
	float light_intensity = smoothstep(LIGHT_OFFSET - light_change, LIGHT_OFFSET + light_change, NdotL);
	
	float shadow = ATTENUATION; 

	vec3 light_contribution = LIGHT_COLOR * light_intensity * shadow;
	DIFFUSE_LIGHT += ALBEDO * light_contribution;
}