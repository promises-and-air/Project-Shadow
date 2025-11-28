shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_toon, specular_toon;

uniform sampler2D main_texture : source_color; // <--- Вот исправление
uniform sampler2D color_gradient;
uniform sampler2D fresnel_gradient;

float fresnel(float amount, vec3 normal, vec3 view)
{
	return pow(1.0 - clamp(dot(normalize(normal), normalize(view)), 0.0, 1.0), amount);
}

void vertex() {
	// Called for every vertex the material is visible on.
}

void fragment() {
	// Получаем базовый цвет из твоей текстуры
	vec3 albedo_tex = texture(main_texture, UV).rgb;

	// Рассчитываем Френель (свечение по краям)
	float basic_fresnel = fresnel(4.0, NORMAL, VIEW);
	vec3 fresnel_color = texture(fresnel_gradient, vec2(basic_fresnel, 0.0)).rgb;

	// Устанавливаем ALBEDO:
	// База — это твоя текстура, а Френель добавляется сверху
	ALBEDO = albedo_tex + (basic_fresnel * fresnel_color * 1.0);
}

void light() {
	float dotproduct = clamp(dot(NORMAL, LIGHT), -0.9, 0.9);
	float sample = clamp((dotproduct + 1.0) * ATTENUATION / 2.1, 0.05, 0.95);
	vec4 shaded = texture(color_gradient, vec2(sample, 0.0));
	DIFFUSE_LIGHT += clamp((shaded.rgb * LIGHT_COLOR), 0.0, 1.0);
	//DIFFUSE_LIGHT += (shaded.rgb * LIGHT_COLOR);
}