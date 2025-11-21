extends Node3D

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@export var animation_name: String = "Fermer"
@export var stop_frame: float = 0.99  # 0.0 début / 1.0 fin

var anim: Animation = null
var target_forward := false
var target_backward := false
var area: Area3D = null

func _ready():
	# --- Crée l'Area3D et le CollisionShape3D ---
	area = Area3D.new()
	add_child(area)
	
	# Layer / Mask
	area.collision_layer = 1 << 9  # bit 9 = 512
	area.collision_mask = 1 << 10  # bit 10 = 1024
	
	# CollisionShape3D enfant
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 10.0
	shape.shape = sphere
	area.add_child(shape)
	
	# Activation
	area.monitoring = true
	area.monitorable = true
	
	# Connecte les signaux
	area.area_entered.connect(_on_area_entered)
	area.area_exited.connect(_on_area_exited)
	
	# --- Prépare l'animation ---
	anim = anim_player.get_animation(animation_name)
	if anim == null:
		push_error("Animation '%s' introuvable !" % animation_name)
		return
	
	# Commence à la fin et bloque
	anim_player.play(animation_name)
	anim_player.seek(anim.length * stop_frame, true)
	anim_player.pause()  # ← UTILISE pause() au lieu de speed_scale = 0
	set_process(false)

# --- Déclencheurs Area3D ---
func _on_area_entered(other_area):
	if anim == null:
		return
	
	target_backward = true
	target_forward = false
	anim_player.speed_scale = -1.0
	anim_player.play(animation_name)  # ← Assure que l'animation est active
	set_process(true)
	print("Area entrée :", other_area.name)

func _on_area_exited(other_area):
	if anim == null:
		return
	
	target_forward = true
	target_backward = false
	anim_player.speed_scale = 1.0
	anim_player.play(animation_name)  # ← Assure que l'animation est active
	set_process(true)
	print("Area sortie :", other_area.name)

# --- Animation progressive ---
func _process(delta: float):
	if anim == null:
		return
	
	var pos := anim_player.current_animation_position
	var length := anim.length
	
	if target_forward:
		if pos >= length * stop_frame:
			anim_player.pause()
			anim_player.seek(length * stop_frame, true)
			target_forward = false
			set_process(false)
			print("Animation arrêtée en position forward")
	
	elif target_backward:
		if pos <= 0.01:
			anim_player.pause()
			anim_player.seek(0.0, true)
			target_backward = false
			set_process(false)
			print("Animation arrêtée en position backward")
