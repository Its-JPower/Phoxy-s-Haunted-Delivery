class_name PlayerWalkingState

extends State2
func update(delta):
	if Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
