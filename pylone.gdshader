shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform float brightness_threshold : hint_range(0.0, 1.0) = 0.9;
uniform vec4 neon_color : source_color = vec4(1.0, 0.0, 0.0, 0.0);
uniform float emission_strength : hint_range(0.0, 50.0) = 10.0;
uniform bool tint_with_original = true;

void fragment() {
    vec3 base_color = COLOR.rgb;
    float brightness = dot(base_color, vec3(0.299, 0.587, 0.114));
    float glow_mask = smoothstep(brightness_threshold, 1.0, brightness);

    // Couleur du néon plus dominante
    vec3 emission_color = tint_with_original
        ? mix(base_color, neon_color.rgb, 0.8)
        : neon_color.rgb;

    ALBEDO = base_color;
    EMISSION = emission_color * emission_strength * glow_mask;

    // Accentuer visuellement les zones lumineuses
    ALBEDO += emission_color * glow_mask * 0.3;
}
