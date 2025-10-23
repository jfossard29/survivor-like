shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform sampler2D albedo_texture;
uniform vec4 target_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);  // Couleur à faire briller
uniform float color_tolerance : hint_range(0.0, 1.0) = 0.1;  // Tolérance de détection
uniform float emission_strength : hint_range(0.0, 20.0) = 5.0;  // Intensité du néon
uniform vec4 neon_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);  // Couleur du néon (optionnel)
uniform bool use_original_color = true;  // Utiliser la couleur d'origine ou neon_color

void fragment() {
	// Lire la couleur de la texture
	vec4 tex_color = texture(albedo_texture, UV);
	
	// Calculer la différence avec la couleur cible
	vec3 color_diff = abs(tex_color.rgb - target_color.rgb);
	float diff = length(color_diff);
	
	// Déterminer si on est proche de la couleur cible
	float is_target = smoothstep(color_tolerance, 0.0, diff);
	
	// Choisir la couleur d'émission
	vec3 emission_color = use_original_color ? tex_color.rgb : neon_color.rgb;
	
	// Appliquer l'albedo normal
	ALBEDO = tex_color.rgb;
	
	// Faire briller uniquement la couleur cible
	EMISSION = emission_color * emission_strength * is_target;
	
	// Augmenter la brillance de la couleur cible dans l'albedo aussi
	ALBEDO = mix(ALBEDO, emission_color, is_target * 0.3);
}