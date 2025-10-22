shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 color_top : source_color = vec4(1.0, 0.5, 0.0, 1.0);  // Couleur en haut
uniform vec4 color_bottom : source_color = vec4(1.0, 0.0, 0.5, 1.0);  // Couleur en bas
uniform float line_speed : hint_range(0.0, 5.0) = 1.0;
uniform float line_width : hint_range(0.01, 0.5) = 0.05;
uniform float line_spacing : hint_range(0.1, 1.0) = 0.2;
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// Dégradé de couleur du haut vers le bas
	vec3 gradient_color = mix(color_bottom.rgb, color_top.rgb, UV.y);
	
	if (UV.y > 0.5) {
		// MOITIÉ BASSE : Lignes qui montent
		float scroll = fract((UV.y - 1.0) + TIME * line_speed);
		float pattern = fract(scroll / line_spacing);
		float line = smoothstep(line_width, 0.0, pattern) + smoothstep(1.0 - line_width, 1.0, pattern);
		float fade = smoothstep(0.0, 0.3, UV.y);
		float final_line = line * fade;
		
		// Appliquer le dégradé aux lignes
		ALBEDO = gradient_color * emission_strength;
		EMISSION = gradient_color * emission_strength * final_line;
		ALPHA = final_line;
	} else {
		// MOITIÉ HAUTE : Couleur unie avec dégradé
		ALBEDO = gradient_color * emission_strength;
		EMISSION = gradient_color * emission_strength;
		ALPHA = 1.0;
	}
}