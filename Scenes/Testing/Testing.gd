extends Spatial

func _ready():
	pass
	
	
#	Globals.quit()

func _input(event):
	
	if event is InputEventJoypadButton:
		
		print("Button ", Input.is_action_just_pressed("reload"))
	elif event is InputEventJoypadMotion:
		pass
