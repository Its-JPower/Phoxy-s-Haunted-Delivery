extends PanelContainer

@onready var property_container = %VBoxContainer
var fps_label : Label

func _ready():
	Global.debug = self
	add_property("FPS", "0.00", 0)
	visible = false

func _process(delta: float) -> void:
	if visible and fps_label:
		var fps = "%.2f" % (1.0 / delta)
		fps_label.text = "FPS: " + fps

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

	# If this is the FPS property, store reference
	if title == "FPS":
		fps_label = label


#func add_debug_property(title: String, value):
#	property = Label.new()
#	property.theme = ThemeDB.get_default_theme()
#	property_container.add_child(property)
#	property.name = title
#	property.text = property.name + value
