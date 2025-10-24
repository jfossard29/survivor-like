@tool
extends MeshInstance3D

@export var base_width := 2.0  # Largeur du côté large (base)
@export var top_ratio := 0.75  # Ratio de rétrécissement (0.0 à 1.0)
@export var depth := 1.0  # Profondeur du trapèze
@export var line_color := Color(0.0, 1.0, 1.0, 1.0) : set = _set_line_color  # Couleur des lignes
@export var line_speed := 1.0 : set = _set_line_speed  # Vitesse de défilement
@export var line_width := 0.05 : set = _set_line_width  # Largeur des lignes (contrôle la taille)
@export var line_spacing := 0.2 : set = _set_line_spacing  # Espacement entre les lignes
@export var emission_strength := 2.0 : set = _set_emission_strength  # Intensité lumineuse
@export var regenerate := false : set = _set_regenerate

var shader_material: ShaderMaterial

func _ready():
	if Engine.is_editor_hint():
		_update_mesh()
		_setup_shader()

func _set_regenerate(value):
	regenerate = false
	if Engine.is_editor_hint() and value:
		_update_mesh()

func _set_line_color(value: Color):
	line_color = value
	_update_shader_params()

func _set_line_speed(value: float):
	line_speed = value
	_update_shader_params()

func _set_line_width(value: float):
	line_width = value
	_update_shader_params()

func _set_line_spacing(value: float):
	line_spacing = value
	_update_shader_params()

func _set_emission_strength(value: float):
	emission_strength = value
	_update_shader_params()

func _update_shader_params():
	if shader_material:
		shader_material.set_shader_parameter("line_color", line_color)
		shader_material.set_shader_parameter("line_speed", line_speed)
		shader_material.set_shader_parameter("line_width", line_width)
		shader_material.set_shader_parameter("line_spacing", line_spacing)
		shader_material.set_shader_parameter("emission_strength", emission_strength)

func _setup_shader():
	var shader = Shader.new()
	shader.code = """
shader_type spatial;
render_mode blend_add, depth_draw_opaque, cull_back, unshaded;

uniform vec4 line_color : source_color = vec4(0.0, 1.0, 1.0, 1.0);
uniform float line_speed : hint_range(0.0, 5.0) = 1.0;
uniform float line_width : hint_range(0.01, 0.5) = 0.05;
uniform float line_spacing : hint_range(0.1, 1.0) = 0.2;
uniform float emission_strength : hint_range(0.0, 10.0) = 2.0;

void fragment() {
	// Inverser la direction : défilement du haut (1) vers la base (0)
	float scroll = fract(UV.y - TIME * line_speed);
	
	// Créer des lignes répétées
	float pattern = fract(scroll / line_spacing);
	
	// Déterminer si on est sur une ligne (contrôle de la taille)
	float line = smoothstep(line_width, 0.0, pattern) + smoothstep(1.0 - line_width, 1.0, pattern);
	
	// Effet de fade-out en arrivant au bout (UV.y proche de 0.0 maintenant)
	float fade = smoothstep(0.0, 0.15, UV.y);
	
	// Combiner la ligne avec le fade
	float final_line = line * fade;
	
	// Appliquer la couleur avec émission
	ALBEDO = line_color.rgb * emission_strength;
	EMISSION = line_color.rgb * emission_strength * final_line;
	ALPHA = final_line * line_color.a;
}
"""
	
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader
	material_override = shader_material
	
	_update_shader_params()

func _update_mesh():
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	var top_width: float = base_width * clamp(top_ratio, 0.0, 1.0)
	
	var verts = [
		Vector3(-base_width / 2, 0, -depth / 2),
		Vector3(base_width / 2, 0, -depth / 2),
		Vector3(top_width / 2, 0, depth / 2),
		Vector3(-top_width / 2, 0, depth / 2)
	]
	
	var normal = Vector3(0, 1, 0)
	
	# UVs pour le mapping des lignes
	var uvs = [
		Vector2(0, 0),  # Base gauche
		Vector2(1, 0),  # Base droite
		Vector2(1, 1),  # Haut droite
		Vector2(0, 1)   # Haut gauche
	]
	
	# Premier triangle (0, 1, 2)
	st.set_normal(normal)
	st.set_uv(uvs[0])
	st.add_vertex(verts[0])
	
	st.set_normal(normal)
	st.set_uv(uvs[1])
	st.add_vertex(verts[1])
	
	st.set_normal(normal)
	st.set_uv(uvs[2])
	st.add_vertex(verts[2])
	
	# Deuxième triangle (0, 2, 3)
	st.set_normal(normal)
	st.set_uv(uvs[0])
	st.add_vertex(verts[0])
	
	st.set_normal(normal)
	st.set_uv(uvs[2])
	st.add_vertex(verts[2])
	
	st.set_normal(normal)
	st.set_uv(uvs[3])
	st.add_vertex(verts[3])
	
	mesh = st.commit()
	
	# Configurer le shader après avoir créé le mesh
	if not shader_material:
		_setup_shader()
	
	print("Trapèze avec shader généré : base=", base_width, " top=", top_width, " depth=", depth)
