extends Node2D

func _ready():
	$ctrl_map_selection/list_maps.add_item("Barn")

func _on_btn_back_pressed():
	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")

func _on_btn_start_pressed():
	get_tree().change_scene(Globals.maps[Globals.selected_map][1])
	if Globals.is_game_paused():
		Globals.set_game_pause(false)
