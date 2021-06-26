extends Node2D

func _ready():
	$lbl_version_number.text = ProjectSettings.get_setting("application/config/version")


func _on_btn_exit_pressed():
	get_tree().quit()

func _on_btn_start_pressed():
	get_tree().change_scene("res://Scenes/game_setup/game_setup.tscn")
