extends CanvasLayer
class_name AimHud

@export var CrossOffset : Vector2 = Vector2.ZERO
@onready var cross: TextureRect = $AimHud/Cross

func _ready() -> void:
	cross.position = cross.position + CrossOffset
	cross = $AimHud/Cross
	

func SetCross(crossTexture : Texture2D):
	print("setting cross", crossTexture, " on ", cross)
	cross = $AimHud/Cross
	cross.texture = crossTexture
