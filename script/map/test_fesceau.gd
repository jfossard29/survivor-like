@tool
extends Node3D
class_name LightBeam

@export var beam_color: Color = Color(1.0, 0.071, 0.302):
	set(value):
		beam_color = value
		_update_materials()

@export var beam_height: float = 20.0:
	set(value):
		beam_height = value
		_update_geometry()

@export var beam_radius: float = 0.5:
	set(value):
		beam_radius = value
		_update_geometry()

@export var rotation_speed: float = 1.0
@export var pulse_enabled: bool = true
@export var pulse_speed: float = 2.0

@export_group("Shader")
@export var beam_intensity: float = 2.0:
	set(value):
		beam_intensity = value
		_update_materials()

@export var scroll_speed: float = 0.5:
	set(value):
		scroll_speed = value
		_update_materials()

@export_file("*.gdshader") var shader_path: String = "res://shaders/fesceau.gdshader"

var mesh_instance: MeshInstance3D
var light: OmniLight3D
var time: float = 0.0

func _ready():
	if not Engine.is_editor_hint():
		_build_beam()

func _build_beam():
	_clear_children()
	
	# Créer le mesh cylindrique
	mesh_instance = MeshInstance3D.new()
	mesh_instance.name = "BeamMesh"
	var cylinder = CylinderMesh.new()
	cylinder.top_radius = beam_radius
	cylinder.bottom_radius = beam_radius * 1.5
	cylinder.height = beam_height
	cylinder.radial_segments = 16
	cylinder.rings = 4
	mesh_instance.mesh = cylinder
	mesh_instance.position.y = beam_height / 2.0
	
	# Appliquer le shader ou matériau par défaut
	_setup_material()
	
	add_child(mesh_instance)
	
	# Créer la lumière
	light = OmniLight3D.new()
	light.name = "BeamLight"
	light.light_color = beam_color
	light.light_energy = beam_intensity
	light.omni_range = beam_height * 1.5
	light.omni_attenuation = 0.5
	light.position.y = beam_height * 0.8
	add_child(light)

func _setup_material():
	if not mesh_instance:
		return
	
	var material: ShaderMaterial
	
	# Si un shader est fourni, l'utiliser
	if shader_path != "" and ResourceLoader.exists(shader_path):
		material = ShaderMaterial.new()
		material.shader = load(shader_path)
	else:
		# Sinon, créer un shader basique en code
		material = ShaderMaterial.new()
		var shader = Shader.new()
		shader.code = _get_default_shader_code()
		material.shader = shader
	
	# Définir les paramètres du shader
	material.set_shader_parameter("beam_color", Vector3(beam_color.r, beam_color.g, beam_color.b))
	material.set_shader_parameter("beam_intensity", beam_intensity)
	material.set_shader_parameter("scroll_speed", scroll_speed)
	
	mesh_instance.material_override = material

func _get_default_shader_code() -> String:
	return """
shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec3 beam_color = vec3(1.0, 0.8, 0.3);
uniform float beam_intensity = 2.0;
uniform float scroll_speed = 0.5;

float noise(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	float radial = length(UV - vec2(0.5, 0.5)) * 2.0;
	vec3 normal = normalize(NORMAL);
	vec3 view = normalize(VIEW);
	float fresnel = pow(1.0 - abs(dot(normal, view)), 2.0);
	float vertical = 1.0 - UV.y;
	float scroll = UV.y + TIME * scroll_speed;
	float n = noise(vec2(UV.x * 2.0, scroll * 2.0));
	
	float alpha = fresnel * vertical * (1.0 - radial) * (0.7 + n * 0.3);
	
	ALBEDO = beam_color;
	EMISSION = beam_color * beam_intensity;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
"""

func _process(delta):
	if Engine.is_editor_hint():
		return
		
	time += delta
	
	# Rotation
	if rotation_speed > 0:
		rotation.y += rotation_speed * delta
	
	# Pulse de l'intensité
	if pulse_enabled and light:
		var pulse_value = sin(time * pulse_speed) * 0.3
		light.light_energy = beam_intensity + pulse_value

func _update_geometry():
	if mesh_instance and mesh_instance.mesh is CylinderMesh:
		var cylinder = mesh_instance.mesh as CylinderMesh
		cylinder.top_radius = beam_radius
		cylinder.bottom_radius = beam_radius * 1.5
		cylinder.height = beam_height
		mesh_instance.position.y = beam_height / 2.0
	
	if light:
		light.omni_range = beam_height * 1.5
		light.position.y = beam_height * 0.8

func _update_materials():
	if mesh_instance and mesh_instance.material_override:
		var mat = mesh_instance.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("beam_color", Vector3(beam_color.r, beam_color.g, beam_color.b))
			mat.set_shader_parameter("beam_intensity", beam_intensity)
			mat.set_shader_parameter("scroll_speed", scroll_speed)
	
	if light:
		light.light_color = beam_color
		light.light_energy = beam_intensity

func _clear_children():
	for child in get_children():
		child.queue_free()

# Fonction helper pour créer rapidement un faisceau
static func create_beam(parent: Node, pos: Vector3, color: Color = Color.YELLOW) -> LightBeam:
	var beam = LightBeam.new()
	beam.position = pos
	beam.beam_color = color
	parent.add_child(beam)
	return beam
