extends Spatial

func _ready():
	pass

func _input(event):
	if event is InputEventKey:
		if Input.is_action_just_pressed("reload"):
			Networking.create_client("localhost")
			pass
		elif Input.is_action_just_pressed("throw_grenade"):
			Networking.create_server()
			pass


