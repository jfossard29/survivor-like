shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;

void fragment() {
	// UV coordonnées : x = autour du cylindre (0 à 1), y = hauteur (0 à 1)
	float height = UV.y;
	
	// Calculer les lignes : une en haut (y proche de 1), une en bas (y proche de 0)
	// Elles se rejoignent au milieu du cylindre (x = 0.5)
	
	// Distance au centre horizontal (0.5 = milieu du cylindre)
	float dist_to_center = abs(UV.x - 0.5);
	
	// Ligne du haut : descend vers le milieu
	float top_line = smoothstep(1.0 - line_thickness, 1.0, height) * (1.0 - dist_to_center * 2.0);
	
	// Ligne du bas : monte vers le milieu
	float bottom_line = smoothstep(line_thickness, 0.0, height) * (1.0 - dist_to_center * 2.0);
	
	// Combiner les deux lignes
	float line_mask = max(top_line, bottom_line);
	line_mask = smoothstep(0.3, 0.7, line_mask);
	
	// Appliquer la couleur et la transparence
	ALBEDO = line_color.rgb;
	EMISSION = line_color.rgb * glow_intensity * line_mask;
	ALPHA = line_mask;
}