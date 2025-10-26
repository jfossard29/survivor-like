shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, unshaded;

uniform vec4 line_color : source_color = vec4(1.0, 0.0, 0.0, 1.0);
uniform float line_thickness : hint_range(0.01, 0.2) = 0.05;
uniform float glow_intensity : hint_range(0.0, 5.0) = 2.0;

void fragment() {

	ALBEDO = line_color.rgb;
	EMISSION = line_color.rgb * glow_intensity;
}