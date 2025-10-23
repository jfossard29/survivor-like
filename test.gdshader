shader_type sky;

uniform vec4 sky_color : source_color = vec4(0.05, 0.05, 0.1, 1.0);
uniform vec4 grid_color : source_color = vec4(0.2, 0.4, 0.6, 0.3);
uniform vec4 horizon_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform vec4 mountain_color : source_color = vec4(0.3, 0.1, 0.4, 1.0);  // Violet vaporwave
uniform vec4 mountain_outline : source_color = vec4(1.0, 0.2, 0.8, 1.0);  // Rose néon

uniform float grid_size : hint_range(0.1, 10.0) = 2.0;
uniform float line_width : hint_range(0.01, 0.2) = 0.02;
uniform float intersection_glow : hint_range(0.0, 2.0) = 0.5;
uniform float horizon_height : hint_range(-1.0, 1.0) = -0.2;
uniform float grid_fade_distance : hint_range(1.0, 50.0) = 20.0;

// Paramètres montagnes
uniform float mountain_height : hint_range(0.0, 0.5) = 0.15;
uniform float mountain_scale : hint_range(0.5, 10.0) = 2.0;
uniform float outline_width : hint_range(0.0, 0.05) = 0.015;

// Fonction simple pour générer des pics de montagnes
float mountain_shape(float x) {
    // Pics triangulaires simples style vaporwave
    float pattern = 0.0;
    
    // Grand pic principal
    pattern = max(pattern, 1.0 - abs(fract(x * 0.8) - 0.5) * 3.0);
    
    // Pics moyens
    pattern = max(pattern, (1.0 - abs(fract(x * 1.5 + 0.3) - 0.5) * 4.0) * 0.7);
    
    // Petits pics
    pattern = max(pattern, (1.0 - abs(fract(x * 3.0 + 0.7) - 0.5) * 5.0) * 0.5);
    
    return clamp(pattern, 0.0, 1.0);
}

void sky() {
    vec3 dir = EYEDIR;
    
    // Calculer la limite supérieure de la zone montagne
    float mountain_top = horizon_height + mountain_height;
    
    if (dir.y < horizon_height) {
        // === SOL AVEC GRILLE ===
        float t = -1.0 / dir.y;
        vec2 grid_pos = vec2(dir.x, dir.z) * t * grid_size;
        vec2 grid_fract = fract(grid_pos);
        
        float line_h = smoothstep(line_width, 0.0, grid_fract.x) + smoothstep(1.0 - line_width, 1.0, grid_fract.x);
        float line_v = smoothstep(line_width, 0.0, grid_fract.y) + smoothstep(1.0 - line_width, 1.0, grid_fract.y);
        float line = max(line_h, line_v);
        
        float is_intersection = line_h * line_v;
        vec2 to_intersection = abs(grid_fract - vec2(0.0, 0.0));
        to_intersection = min(to_intersection, abs(grid_fract - vec2(1.0, 1.0)));
        float dist_to_intersection = length(to_intersection);
        float glow = smoothstep(0.15, 0.0, dist_to_intersection) * intersection_glow * is_intersection;
        
        float distance_fade = smoothstep(grid_fade_distance, 0.0, abs(t));
        line *= distance_fade;
        glow *= distance_fade;
        
        vec3 final_color = mix(horizon_color.rgb, grid_color.rgb, line * 0.3);
        final_color += grid_color.rgb * glow * 0.5;
        
        COLOR = final_color;
    } 
    else if (dir.y >= horizon_height && dir.y <= mountain_top) {
        // === ZONE DES MONTAGNES ===
        
        // Position horizontale (angle)
        float angle = atan(dir.x, dir.z) / 3.14159265;
        
        // Profil de montagne
        float mountain_profile = mountain_shape(angle * mountain_scale);
        
        // Hauteur actuelle dans la zone montagne (0 = bas, 1 = haut)
        float normalized_height = (dir.y - horizon_height) / mountain_height;
        
        // La montagne est visible si on est en dessous du profil
        float is_mountain = step(normalized_height, mountain_profile);
        
        // Détection du contour (près du bord supérieur)
        float distance_to_edge = abs(normalized_height - mountain_profile);
        float is_outline = smoothstep(outline_width, 0.0, distance_to_edge) * is_mountain;
        
        // Dégradé de couleur (plus clair vers le sommet)
        vec3 mountain_shade = mix(mountain_color.rgb * 0.6, mountain_color.rgb * 1.1, normalized_height);
        
        // Couleur de fond (ciel/horizon)
        vec3 background = mix(horizon_color.rgb, sky_color.rgb, normalized_height);
        
        // Composition
        vec3 final_color = mix(background, mountain_shade, is_mountain);
        final_color = mix(final_color, mountain_outline.rgb, is_outline);
        
        COLOR = final_color;
    } 
    else {
        // === CIEL ===
        float horizon_blend = smoothstep(horizon_height, horizon_height + 0.3, dir.y);
        COLOR = mix(horizon_color.rgb, sky_color.rgb, horizon_blend);
    }
}