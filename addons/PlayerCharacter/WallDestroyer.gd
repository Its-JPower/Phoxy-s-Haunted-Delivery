extends RayCast3D

func _physics_process(delta: float) -> void:
	if is_colliding():
		var collider = get_collider()
		if collider.get_parent().get_parent().is_in_group("Maze"):
			collider.get_parent().queue_free()
