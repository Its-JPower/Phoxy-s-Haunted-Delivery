class_name StateMachine

extends PlayerMovementState


@export var CURRENT_STATE : State2
var states: Dictionary = {}

func _ready() -> void:
	for child in get_children():
		if child is State2:
			states[child.name] = child
			child.transition.connect(on_child_transition)
		else:
			push_warning("State machine contains incompatible child node")
	await owner.ready
	CURRENT_STATE.enter(null)

func _process(delta):
	CURRENT_STATE.update(delta)
	Global.debug.add_property("CurrentState", CURRENT_STATE.name, 1)

func _physics_process(delta):
	CURRENT_STATE.physics_update(delta)

func on_child_transition(new_state_name: StringName) -> void:
	var new_state = states.get(new_state_name)
	if new_state != null:
		if new_state != CURRENT_STATE:
			CURRENT_STATE.exit()
			new_state.enter(CURRENT_STATE)
			CURRENT_STATE = new_state
	else:
		push_warning("State does not exist!")
