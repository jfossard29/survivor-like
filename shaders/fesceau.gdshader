shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec3 beam_color : source_color = vec3(1.0, 0.8, 0.3);
uniform float beam_intensity : hint_range(0.0, 5.0) = 2.0;
uniform float scroll_speed : hint_range(0.0, 2.0) = 0.5;
uniform float fresnel_power : hint_range(0.1, 5.0) = 2.0;
uniform float noise_scale : hint_range(0.1, 10.0) = 2.0;

// Fonction noise simple
float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	// Distance du centre (effet radial)
	float radial = length(UV - vec2(0.5, 0.5)) * 2.0;

	// Effet de fresnel (plus lumineux sur les bords)
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float fresnel = pow(1.0 - abs(dot(normal, view)), fresnel_power);

	// Gradient vertical (plus lumineux en bas)
	float vertical_gradient = 1.0 - UV.y;

	// Animation de scroll
	float scroll = UV.y + TIME * scroll_speed;
	float noise_value = noise(vec2(UV.x * noise_scale, scroll * noise_scale));

	// Combinaison des effets
	float alpha = fresnel * vertical_gradient * (1.0 - radial);
	alpha *= (0.7 + noise_value * 0.3); // Ajouter du bruit

	// Couleur finale
	ALBEDO = beam_color;
	EMISSION = beam_color * beam_intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}