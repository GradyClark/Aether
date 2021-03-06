extends Control

var local_ips = []

func _ready():
	$game_setup_menu/ctrl_map_selection/btn_start.grab_focus()
	
	$game_setup_menu/ctrl_online/lbl_upnp_port_number.text = str(Networking.default_port)
	$game_setup_menu/ctrl_online/lbl_upnp_result.hide()

	for map in Globals.game_maps:
		$game_setup_menu/ctrl_map_selection/list_maps.add_item(map.Name)
	
	if OS.is_debug_build():
		$game_setup_menu/ctrl_online/le_ipv4.text = "localhost"
		Globals.selected_map = 2
	
	$game_setup_menu/ctrl_map_selection/list_maps.select(Globals.selected_map)
	
	Globals.connect("when_player_added", self, "_on_players_changed")
	Globals.connect("when_player_removed", self, "_on_players_changed")
	_on_players_changed(null)
	
	Globals.connect("on_map_selection_changed", self, "_on_map_selection_changed")
	
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if Networking.is_network_connected():
		$game_setup_menu/ctrl_online/btn_online_host.hide()
		$game_setup_menu/ctrl_online/btn_online_join.hide()
		if get_tree().is_network_server():
			pass
		else:
			$game_setup_menu/ctrl_map_selection/list_maps.disabled = true
			$game_setup_menu/ctrl_map_selection/btn_start.hide()
			$game_setup_menu/ctrl_online.hide()
	
	_connect_all()
	

func _on_players_changed(player):
	_on_PlayerList_Refresh_Timer_timeout()


func _on_btn_find_public_ip_pressed():
	var r = Networking.upnp_get_external_ip()
	
	if r == "":
		$game_setup_menu/ctrl_online/lbl_public_ip_number.text = "Failed"
		$game_setup_menu/ctrl_online/btn_find_public_ip.disabled = true
	else:
		$game_setup_menu/ctrl_online/lbl_public_ip_number.text = str(r)


func _on_btn_upnp_open_port_pressed():
	var r = Networking.upnp_open_port()
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		$game_setup_menu/ctrl_online/lbl_upnp_result.text = "Port Opened"
	else:
		$game_setup_menu/ctrl_online/lbl_upnp_result.text = "Failed"
	$game_setup_menu/ctrl_online/lbl_upnp_result.show()
	$game_setup_menu/ctrl_online/btn_upnp_open_port.disabled = true


func _on_btn_start_pressed():
	if not Networking.is_network_connected():
		var r = Networking.single_player()
		if r != OK:
			Dialog.display("Couldn't Start Single Player", "")
			return

	Globals.rpc("change_game_map", Globals.game_maps[Globals.selected_map].Name)


func _on_list_maps_item_selected(index):
	if get_tree().network_peer != null and get_tree().is_network_server():
		Globals.rpc("change_map_selection", index)
	else:
		Globals.change_map_selection(index)


func _on_map_selection_changed(index):
	$game_setup_menu/ctrl_map_selection/list_maps.select(index)


func _on_btn_online_join_pressed():
	$game_setup_menu/ctrl_online.hide()
	$game_setup_menu/ctrl_map_selection/list_maps.disabled = true
	$game_setup_menu/ctrl_map_selection/btn_start.hide()
	
	var r = Networking.create_client($game_setup_menu/ctrl_online/le_ipv4.text)


func _on_btn_back_pressed():
	Networking.close_connection()
	Globals.change_scene("res://Scenes/User_Interface/Menus/main_menu/main_menu.tscn")


func _on_btn_online_host_pressed():
	$game_setup_menu/ctrl_online/btn_online_join.hide()
	$game_setup_menu/ctrl_online/btn_online_host.hide()
	
	if Networking.create_server() != OK:
		$game_setup_menu/ctrl_online/btn_online_join.show()
		$game_setup_menu/ctrl_online/btn_online_host.show()
		Dialog.display("Server Error", "Couldn't Create Server")
	else:
		var ints = IP.get_local_interfaces()
		$game_setup_menu/ctrl_online/btn_find_public_ip.grab_focus()
		
		$game_setup_menu/ctrl_online/ctrl_local_ips/list_local_ips.clear()
		local_ips.clear()
		for i in ints:
			for addr in i.addresses:
				if addr.count(".") == 3:
					local_ips.append(addr)
					$game_setup_menu/ctrl_online/ctrl_local_ips/list_local_ips.add_item(i.name+": "+addr)


func _on_PlayerList_Refresh_Timer_timeout():
	$Players/PlayerList.clear()
	for p in Globals.players:
		$Players/PlayerList.add_item(str(p.ID) + ": " + p.Name)


func _server_disconnected():
	_on_btn_back_pressed()


func _on_le_set_your_name_text_entered(new_text):
	if not Networking.is_network_connected():
		Globals.player_change_name(Globals.players[0].ID,new_text)
	else:
		Globals.rpc("player_change_name",Globals.players[0].ID,new_text)
	Globals.save_settings()


func _on_PlayerList_item_selected(index):
	if get_tree().is_network_server() and index != 0:
		Networking.kick(int(Globals.players[index].ID), "Host User Kicked You")


func _connect_all():
	Networking.connect("on_player_registered", self, "_player_connected")
	Networking.connect("on_connection_failed", self, "_connection_failed")
	Networking.connect("on_server_disconnected", self, "_server_disconnected")


func _disconnect_all():
	Globals.disconnect("when_player_added", self, "_on_players_changed")
	Globals.disconnect("when_player_removed", self, "_on_players_changed")
	
	Globals.disconnect("on_map_selection_changed", self, "_on_map_selection_changed")
	
	Networking.disconnect("on_player_registered", self, "_player_registered")
	Networking.disconnect("on_connection_failed", self, "_connection_failed")
	Networking.disconnect("on_server_disconnected", self, "_server_disconnected")

func _player_registered(user_name, id):
	pass

func _exit_tree():
	_disconnect_all()


func _on_le_ipv4_text_entered(new_text):
	_on_btn_online_join_pressed()


func _connection_failed():
	$game_setup_menu/ctrl_online/btn_online_join.show()
	$game_setup_menu/ctrl_online/btn_online_host.show()
	Dialog.display("Connection Error", "Couldn't Connect to Server")


func _on_lbl_public_ip_number_text_entered(new_text):
	OS.clipboard = $game_setup_menu/ctrl_online/lbl_public_ip_number.text


func _on_list_local_ips_item_activated(index):
	OS.clipboard = local_ips[$game_setup_menu/ctrl_online/ctrl_local_ips/list_local_ips.get_selected_items()[0]]


func _on_lbl_public_ip_number_gui_input(event):
	if event is InputEventJoypadButton:
		if  event.is_action_pressed("ui_accept"):
			_on_lbl_public_ip_number_text_entered("")
	elif event is InputEventMouseButton:
		if event.pressed:
			_on_lbl_public_ip_number_text_entered("")


func _on_le_set_your_name_gui_input(event):
	if event is InputEventJoypadButton:
		if  event.is_action_pressed("ui_accept"):
			_on_le_set_your_name_text_entered($Players/le_set_your_name.text)
		elif  event.is_action_pressed("ui_select"):
			$Players/le_set_your_name.text = str(OS.clipboard)


func _on_le_ipv4_gui_input(event):
	if event is InputEventJoypadButton:
		if  event.is_action_pressed("ui_select"):
			$game_setup_menu/ctrl_online/le_ipv4.text = str(OS.clipboard)
		elif  event.is_action_pressed("ui_accept"):
			_on_le_ipv4_text_entered($game_setup_menu/ctrl_online/le_ipv4.text)
