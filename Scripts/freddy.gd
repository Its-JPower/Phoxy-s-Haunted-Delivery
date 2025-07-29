extends CharacterBody3D

@onready var nav_agent = $NavigationAgent3D
@onready var TARGET : CharacterBody3D = get_tree().get_first_node_in_group("Player")

@export var SPEED = 10

func _physics_process(delta: float) -> void:
	var current_location = global_transform.origin
	var next_location = nav_agent.get_next_path_position()
	var direction = (next_location - current_location).normalized()
	if Global.freeze == true:
		velocity = Vector3.ZERO
	else:
		var target_rotation = Vector3.ZERO
		target_rotation.x = TARGET.global_position.x
		target_rotation.y = global_position.y
		target_rotation.z = TARGET.global_position.z
		look_at(target_rotation)
		velocity = direction * SPEED
		move_and_slide()

func update_target_location(target_location):
	nav_agent.set_target_position(target_location)


func _on_visible_on_screen() -> void:
	Global.freeze == true

func _on_not_visible_on_screen() -> void:
	Global.freeze == false
