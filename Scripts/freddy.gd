extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")

@export var SPEED = 10

var freeze : bool = false

func _physics_process(delta: float) -> void:
	if freeze:
		velocity = Vector3.ZERO
		move_and_slide()
		freeze = false
		return
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var direction = (next_location - current_location).normalized()
	var target_position = Vector3(
		TARGET.global_position.x,
		global_position.y,
		TARGET.global_position.z
	)
	look_at(target_position)

	velocity = direction * SPEED
	move_and_slide()

func update_target_location(target_location):
	nav_agent.set_target_position(target_location)
