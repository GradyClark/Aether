extends Control

var destroyable = null

func _ready():
	if destroyable == null:
		$health_display.visible=false
		
	$pause_menu.visible=false
	Globals.connect("game_pause_state_changed", self, "_on_game_pause_state_changed")

func _on_poll_timer_timeout():
	$round_display/lbl_round_number.text = str(Globals.zombie_round)
	$zombies_left_display/lbl_zombies_left_number.text = str(Globals.zombies_to_spawn_this_round-Globals.zombies_killed_this_round)
	if destroyable != null:
		$health_display/lbl_health_number.text = str(destroyable.health)


func _on_btn_exit_to_main_menu_pressed():
	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")

func _on_game_pause_state_changed(paused):
	$pause_menu.visible=paused

func _on_btn_continue_pressed():
	Globals.set_game_pause(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if Globals.is_game_paused():
		pass
	else:
		pass
	
	if event is InputEventKey:
		if Input.is_action_just_released("ui_end"):
			get_tree().quit()
		elif Input.is_action_just_released("ui_cancel"):
			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
				Globals.set_game_pause(true)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
				Globals.set_game_pause(false)
