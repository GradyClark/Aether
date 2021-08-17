extends Control

var player: Globals.Player = null

func _ready():
	player = Globals.players[0]
	if player.Destroyable == null:
		$health_display.hide()
	
	if player.Player_Controller == null:
		$points_display.hide()
		
	$pause_menu.visible=false
	$interaction_display.hide()
	Globals.connect("game_pause_state_changed", self, "_on_game_pause_state_changed")
	
	_on_game_pause_state_changed(get_tree().paused, Globals.player_can_toggle_pause_state)

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
					if col.Product_Type == Globals.Product_Types.gun:
						if player.Player_Controller.weapon.Weapon_Name == col.Product_ID:
							if col.Ammo_Amount == 0:
								$interaction_display.text = "Press (E) to Buy\nPrice: "+str(col.Price_Ammo)+"\nFor: Ammo"
							else:
								$interaction_display.text = "Press (E) to Buy\nPrice: "+str(col.Price_Ammo)+"\nFor: "+str(col.Ammo_Amount)+"x Ammo"
						else:
							$interaction_display.text = "Press (E) to Buy\nPrice: "+str(col.Price)+"\nFor: "+col.Product_Name
					else:
						$interaction_display.text = "Press (E) to Buy\nPrice: "+str(col.Price)+"\nFor: "+col.Product_Name
				elif col.is_in_group(Globals.GROUP_PLAYERS):
					var _p = Globals.get_player_with_id(col.get_network_master())
					if _p != null and _p.Destroyable.is_bleeding_out:
						$interaction_display.text = "Hold (E) to Revive\n"+str(_p.Name)+"-"+str(_p.ID)+"\n"+str(_p.Destroyable.bleedout)+"/"+str(_p.Destroyable.bleedout_max)
					elif _p != null:
						$interaction_display.text = "Player:\n"+str(_p.Name)+"-"+str(_p.ID)
				if not $interaction_display.visible:
					$interaction_display.show()
	
	$stamina_display/lbl_stamina_number.text = str(player.Stamina)
	
	$fps_display/lbl_fps_number.text = str(Engine.get_frames_per_second())

func _on_btn_exit_to_main_menu_pressed():
	if get_tree().is_network_server():
		Globals.rpc("change_scene","res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
	else:
		Networking.close_connection()
		while Networking.is_network_connected():
			yield(get_tree().create_timer(0.2),"timeout")
		Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
		

func _on_game_pause_state_changed(paused, player_can_toggle_pause_state):
	$pause_menu/btn_continue.disabled = not player_can_toggle_pause_state
	
	$pause_menu.visible=paused
	
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		$pause_menu/btn_continue.grab_focus()
		$Sound_Relaxing.play()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		$Sound_Relaxing.stop()
	

func _on_btn_continue_pressed():
	Globals.set_game_pause(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	Dialog.hide()

func _input(event):
	if event is InputEventKey or event is InputEventJoypadButton:
		if event.is_action_released("ui_cancel"):
			Globals.set_game_pause(!get_tree().paused)

func refresh_perk_display():
	
	for i in range(1,$perks_display.get_child_count()):
		$perks_display.remove_child($perks_display.get_child(1))
	
	for i in player.Perks.size():
		var p: Globals.Perk = player.Perks[i]
		var n: TextureRect = $perks_display.get_child(0).duplicate()
		var l: Label = n.get_child(0)
		l.text = str(p.Perk_Level)
		n.texture = p.Perk_Image
		n.rect_position.x = 44 * i
		n.visible = true
		n.name = p.Product_ID
		$perks_display.add_child(n)
