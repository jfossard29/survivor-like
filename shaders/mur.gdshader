shader_type spatial;

uniform float tile_scale : hint_range(0.1, 10.0) = 1.0;
uniform vec3 metal_color : source_color = vec3(0.3, 0.35, 0.4);
uniform vec3 energy_color : source_color = vec3(0.2, 0.6, 1.0);
uniform float energy_intensity : hint_range(0.0, 2.0) = 1.2;
uniform float energy_speed : hint_range(0.0, 2.0) = 0.0;
uniform float vein_thickness : hint_range(0.01, 0.3) = 0.02;
uniform float vein_density : hint_range(0.5, 5.0) = 2.0;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.1;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.9;

// --- Noise et FBM ---
float hash(vec2 p){ return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p){
	vec2 i=floor(p);
	vec2 f=fract(p);
	f=f*f*(3.0-2.0*f);
	float a=hash(i);
	float b=hash(i+vec2(1.0,0.0));
	float c=hash(i+vec2(0.0,1.0));
	float d=hash(i+vec2(1.0,1.0));
	return mix(mix(a,b,f.x),mix(c,d,f.x),f.y);
}
float fbm(vec2 p){
	float v=0.0,a=0.5,f=1.0;
	for(int i=0;i<4;i++){ v+=a*noise(p*f); f*=2.0; a*=0.5; }
	return v;
}
float veins(vec2 uv,float t){
	vec2 p=uv*vein_density;
	float v1=fbm(p+vec2(t*0.1,0.0));
	float v2=fbm(p*1.5+vec2(0.0,t*0.15));
	float v3=fbm(p*2.3+vec2(t*0.08,t*0.12));
	float vp=(v1+v2*0.5+v3*0.3)/1.8;
	vp=abs(sin(vp*10.0));
	return smoothstep(1.0-vein_thickness,1.0,vp);
}

// Varyings
varying vec3 v_world_normal;
varying vec3 v_world_pos;

void vertex(){
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL,0.0)).xyz);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX,1.0)).xyz;
}

void fragment(){
	vec3 n = normalize(v_world_normal);

	// Masque murs (faces quasi-verticales)
	float is_wall = step(0.5, abs(n.x)) + step(0.5, abs(n.z));
	is_wall = clamp(is_wall,0.0,1.0);

	// UV proportionnel à la taille du mur
	vec2 wall_uv;
	if(abs(n.x) > 0.5){
		wall_uv = vec2(v_world_pos.z, v_world_pos.y);
	} else {
		wall_uv = vec2(v_world_pos.x, v_world_pos.y);
	}

	wall_uv *= tile_scale;

	// Base métal
	float base_var = noise(wall_uv*5.0)*0.2;
	vec3 wall_color = metal_color*(0.8+base_var);

	// Veines animées
	float vein_mask = veins(wall_uv,TIME*energy_speed);
	float pulse = sin(TIME*2.0)*0.2 + 0.8;
	wall_color = mix(wall_color, energy_color, vein_mask*0.6);
	vec3 wall_emission = energy_color*vein_mask*energy_intensity*pulse;

	// Appliquer uniquement sur murs
	ALBEDO = mix(vec3(0.0), wall_color, is_wall);
	METALLIC = mix(0.0, metallic_value, is_wall);
	ROUGHNESS = mix(1.0, mix(roughness_value,0.1,vein_mask), is_wall);
	EMISSION = mix(vec3(0.0), wall_emission, is_wall);
}
