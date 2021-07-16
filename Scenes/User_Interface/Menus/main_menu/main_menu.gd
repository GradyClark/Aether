extends Node2D

func _ready():
	$lbl_version_number.text = ProjectSettings.get_setting("application/config/version")


func _on_btn_exit_pressed():
	Globals.quit()


func _on_btn_start_pressed():
	Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
