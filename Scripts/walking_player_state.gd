class_name PlayerWalkingState

extends State2

func update(delta):
	print("Walking update")
	if Global.player.velocity.length() == 0.0:
		transition.emit("IdlePlayerState")
