extends Node

func _ready():
	var map_info = Globals.maps[Globals.selected_map]
	
	var map = Globals.maps[Globals.selected_map][1].instance()
	get_tree().get_root().add_child(map)
	
	print(Globals.players[0])
	
	$viewports/ViewportContainer_1/Viewport_1.add_child(Globals.players[0][2])
