extends PanelContainer

@onready var property_container = %VBoxContainer
var fps_label : Label
var speed_label : Label
var timer_label : Label

func _ready():
	Global.debug = self
	add_property("FPS", "0.00", 0)
	add_property("Speed", "0.00", 1)
	add_property("Time", "0.00", 4)
	visible = false


func _process(delta: float) -> void:
	if visible:
		if fps_label:
			var fps = "%.2f" % (1.0 / delta)
			fps_label.text = "FPS: " + fps

		if speed_label:
			speed_label.text = "Speed: " + str(Global.player._speed)
		if timer_label:
			timer_label.text = "Time: " + str(snapped(Global.timer,0.01))


func _input(event):
	if event.is_action_pressed("debug"):
		visible = !visible

func add_property(title: String, value, order):
	var label = property_container.find_child(title, true, false) as Label
	if !label:
		label = Label.new()
		label.theme = ThemeDB.get_default_theme()
		property_container.add_child(label)
		label.name = title
		label.text = title + ": " + str(value)
		property_container.move_child(label, order)
	else:
		label.text = title + ": " + str(value)

	if title == "FPS":
		fps_label = label
	elif title == "Speed":
		speed_label = label
	elif title == "Time":
		timer_label = label



#func add_debug_property(title: String, value):
#	property = Label.new()
#	property.theme = ThemeDB.get_default_theme()
#	property_container.add_child(property)
#	property.name = title
#	property.text = property.name + value
