shader_type spatial;

uniform float visibility : hint_range(0.0, 0.5) = 0.0;
uniform vec3 base_color = vec3(0.0, 0.9, 1.0);

void fragment() {
    ALBEDO = base_color;
    EMISSION = base_color * visibility * 3.0; // émission proportionnelle à la visibilité
    ALPHA = visibility;
}
