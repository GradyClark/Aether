extends Control

var player: Object = null

func _ready():
	player = Globals.players[0]
	if player.Destroyable == null:
		$health_display.hide()
	
	if player.Player_Controller == null:
		$points_display.hide()
		
	$pause_menu.visible=false
	$interaction_display.hide()
	Globals.connect("game_pause_state_changed", self, "_on_game_pause_state_changed")
	
	_on_game_pause_state_changed(get_tree().paused)

func _on_poll_timer_timeout():
	$round_display/lbl_round_number.text = str(Globals.zombie_round)
	$zombies_left_display/lbl_zombies_left_number.text = str(Globals.zombies_to_spawn_this_round-Globals.zombies_killed_this_round)
	if player.Destroyable != null:
		$health_display/lbl_health_number.text = str(player.Destroyable.health)
		
		if player.Destroyable.is_bleeding_out:
			if not $interaction_display.visible:
				$interaction_display.show()
			$interaction_display.text = "Bleeding Out: " + str(player.Destroyable.bleedout) + "/" + str(player.Destroyable.bleedout_max)
		
	if player.Player_Controller != null:
		$points_display/lbl_points_number.text = str(player.Points)
		
		if not player.Destroyable.is_bleeding_out:
			var col: Node = player.Player_Controller._interactable_selected
			if col == null and $interaction_display.visible:
				$interaction_display.hide()
			elif col != null:
				if col.is_in_group(Globals.GROUP_BUYABLE):
					$interaction_display.text = "Press (E) to Buy\nPrice: "+str(col.Price)+"\nFor: "+col.Product_Name
				elif col.is_in_group(Globals.GROUP_PLAYERS):
					var _p = Globals.get_player_with_id(col.get_network_master())
					if _p.Destroyable.is_bleeding_out:
						$interaction_display.text = "Hold (E) to Revive\n"+str(_p.Name)+"-"+str(_p.ID)+"\n"+str(_p.Destroyable.bleedout)+"/"+str(_p.Destroyable.bleedout_max)
					else:
						$interaction_display.text = "Player:\n"+str(_p.Name)+"-"+str(_p.ID)
				if not $interaction_display.visible:
					$interaction_display.show()

func _on_btn_exit_to_main_menu_pressed():
	if get_tree().is_network_server():
		Globals.rpc("change_scene","res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
	else:
		Globals.network_close_connection()
		Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
		

func _on_game_pause_state_changed(paused):
	$pause_menu.visible=paused
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$Sound_Relaxing.play()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Sound_Relaxing.stop()

func _on_btn_continue_pressed():
	Globals.set_game_pause(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _input(event):
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_pressed("ui_end"):
			if get_tree().is_network_server():
				Globals.net.close_connection()
			get_tree().quit()
		elif event.is_action_released("ui_cancel"):
			Globals.set_game_pause(!get_tree().paused)