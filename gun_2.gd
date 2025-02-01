extends MeshInstance3D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


func shoot ():
	if Input.is_action_just_pressed("fire"):
		print("Gun2 Fired")
