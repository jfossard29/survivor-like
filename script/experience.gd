extends Area3D

@onready var game_manager: GameManager

@export var base_speed: float = 5.0
@export var base_valeur: float = 10.0
@export var base_pickup_radius: float = 1.0

var target: Node3D = null
var is_following: bool = false
var valeur: float
var speed: float
var pickup_radius: float

func _ready():
	add_to_group("experience")
	connect("body_entered", Callable(self, "_on_body_entered"))
	_update_from_game_manager()
	if game_manager:
		game_manager.connect("multipliers_changed", Callable(self, "_update_from_game_manager"))

func _update_from_game_manager():
	valeur = base_valeur * (game_manager.xp_multiplier if game_manager else 1.0)
	pickup_radius = base_pickup_radius * (game_manager.pickup_scale_multiplier if game_manager else 1.0)
	$CollisionShape3D.scale = Vector3.ONE * pickup_radius


func start_following(player: Node3D):
	target = player
	is_following = true

func _physics_process(delta: float) -> void:
	if is_following and target and is_instance_valid(target):
		var dir = (target.global_position - global_position).normalized()
		global_position += dir * speed * delta
		look_at(target.global_position, Vector3.UP)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		if body.has_method("add_experience"):
			body.add_experience(valeur)
		
		queue_free()
