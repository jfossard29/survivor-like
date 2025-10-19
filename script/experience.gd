extends Area3D

@export var speed: float = 5.0
@export var valeur: float = 10.0
var target: Node3D = null
var is_following: bool = false

func _ready():
	add_to_group("experience")
	connect("body_entered", Callable(self, "_on_body_entered"))
	print("🟢 Expérience prête :", name)

func start_following(player: Node3D):
	target = player
	is_following = true
	print("🎯 L'expérience suit le joueur :", player.name)

func _physics_process(delta: float) -> void:
	if is_following and target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
		look_at(target.global_position, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_experience"):
			body.add_experience(valeur)
		print("✨ Expérience collectée !")
		
		queue_free()
