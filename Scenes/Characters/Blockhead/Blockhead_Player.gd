extends KinematicBody

func _ready():
	$editor_only.visible=false
	pass

func set_active_camera():
	$Camera.current = true

var SID = "Blockhead_Character"
func serialize():
	return {"SID": SID, "name": name}

func deserialize(data):
	pass
