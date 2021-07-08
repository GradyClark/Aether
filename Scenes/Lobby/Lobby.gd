extends Spatial


func _ready():
	connect("network_peer_connected", self, "_player_connected")
	
	add_child(Globals.game_setup.instance())
	get_tree().network_peer = Globals.net

func _on_btn_exit_pressed():
	get_tree().quit()


func _on_btn_start_pressed():
#	get_tree().change_scene("res://Scenes/game_setup/game_setup.tscn")
	Globals.net.create_server(Globals.default_port, 32)
	_player_connected(0)


func _player_connected(id):
	var game = preload("res://Scenes/Levels/Barn/Barn.tscn").instance()
	get_tree().get_root().add_child(game)
