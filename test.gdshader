shader_type sky;

uniform vec4 sky_color : source_color = vec4(0.05, 0.05, 0.1, 1.0);  // Ciel sombre
uniform vec4 grid_color : source_color = vec4(0.2, 0.4, 0.6, 0.3);  // Grille subtile et transparente
uniform vec4 horizon_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);  // Horizon discret
uniform float grid_size : hint_range(0.1, 10.0) = 2.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.02;  // Lignes fines
uniform float intersection_glow : hint_range(0.0, 2.0) = 0.5;  // Glow subtil
uniform float horizon_height : hint_range(-1.0, 1.0) = -0.2;
uniform float grid_fade_distance : hint_range(1.0, 50.0) = 20.0;

void sky() {
	vec3 dir = EYEDIR;
	
	if (dir.y < horizon_height) {
		// Projection sur le sol
		float t = -1.0 / dir.y;
		vec2 grid_pos = vec2(dir.x, dir.z) * t * grid_size;
		vec2 grid_fract = fract(grid_pos);
		
		// Lignes de la grille
		float line_h = smoothstep(line_width, 0.0, grid_fract.x) + smoothstep(1.0 - line_width, 1.0, grid_fract.x);
		float line_v = smoothstep(line_width, 0.0, grid_fract.y) + smoothstep(1.0 - line_width, 1.0, grid_fract.y);
		float line = max(line_h, line_v);
		
		// Intersections avec glow subtil
		float is_intersection = line_h * line_v;
		vec2 to_intersection = abs(grid_fract - vec2(0.0, 0.0));
		to_intersection = min(to_intersection, abs(grid_fract - vec2(1.0, 1.0)));
		float dist_to_intersection = length(to_intersection);
		float glow = smoothstep(0.15, 0.0, dist_to_intersection) * intersection_glow * is_intersection;
		
		// Fade avec la distance
		float distance_fade = smoothstep(grid_fade_distance, 0.0, abs(t));
		line *= distance_fade;
		glow *= distance_fade;
		
		// Couleur finale - plus sombre et subtile
		vec3 final_color = mix(horizon_color.rgb, grid_color.rgb, line * 0.3);
		final_color += grid_color.rgb * glow * 0.5;
		
		COLOR = final_color;
	} else {
		// Ciel avec dégradé doux
		float horizon_blend = smoothstep(horizon_height, horizon_height + 0.3, dir.y);
		COLOR = mix(horizon_color.rgb, sky_color.rgb, horizon_blend);
	}
}