shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_opaque;

uniform vec4 pixel_color : source_color = vec4(0.3, 0.8, 1.0, 1.0);
uniform float pixel_size : hint_range(0.01, 1.0) = 0.01;
uniform float edge_width : hint_range(0.0, 1.0) = 0.2;
uniform float edge_height : hint_range(0.0, 2.0) = 0.6;
uniform float glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float animation_speed : hint_range(0.0, 5.0) = 1.5;
uniform float fall_speed : hint_range(0.0, 5.0) = 0.1;

void vertex() {
	// Passer les coordonnées au fragment
}

void fragment() {
	// Utiliser la normale pour détecter les côtés
	vec3 normal = normalize(NORMAL);
	float vertical_component = abs(normal.y);

	// Si la normale pointe fortement vers le haut ou le bas, c'est le top/bottom
	// Seuil à 0.9 pour être plus permissif
	if (vertical_component > 0.9) {
		discard;
	}

	// Coordonnées UV du cylindre
	vec2 uv = UV;

	// Position sur le cylindre (0 à 1 autour, 0 à 1 en hauteur)
	float angle_pos = uv.x; // Position angulaire autour du cylindre
	float height_pos = uv.y; // Position en hauteur (0 = bas, 1 = haut)

	// Distance du sol (0 = en bas, 1 = en haut)
	float dist_from_bottom = 1.0 - height_pos;

	// Visibilité : seulement sur les bords et près de la base
	float edge_fade = smoothstep(edge_height, 0.0, dist_from_bottom);

	// Effet pixelisé avec mouvement vertical (style Matrix)
	vec2 moving_uv = uv;
	moving_uv.y += TIME * fall_speed; // Les pixels descendent
	vec2 pixelated_uv = floor(moving_uv / pixel_size) * pixel_size;
	float pixel_pattern = step(0.3, fract(sin(dot(pixelated_uv, vec2(12.9898, 78.233))) * 43758.5453));

	// Animation scintillante
	float flicker = sin(TIME * animation_speed + angle_pos * 20.0 + height_pos * 10.0) * 0.2 + 0.8;

	// Combinaison
	float alpha = edge_fade * pixel_pattern * flicker;

	// Si alpha trop faible, on rejette le fragment
	if (alpha < 0.01) {
		discard;
	}

	// Couleur finale
	vec3 final_color = pixel_color.rgb * glow_intensity;
	ALBEDO = final_color;
	ALPHA = alpha;
	EMISSION = final_color * alpha * 2.0;
}