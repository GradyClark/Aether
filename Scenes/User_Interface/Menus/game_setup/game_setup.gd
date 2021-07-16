extends Spatial

func _ready():
	$game_setup_menu/ctrl_online/lbl_upnp_port_number.text = str(Globals.default_port)
	$game_setup_menu/ctrl_online/lbl_upnp_result.hide()

	for map in Globals.maps:
		$game_setup_menu/ctrl_map_selection/list_maps.add_item(map.Name)
	
	$game_setup_menu/ctrl_map_selection/list_maps.select(Globals.selected_map)
	
	Globals.connect("when_player_added", self, "_on_players_changed")
	Globals.connect("when_player_removed", self, "_on_players_changed")
	_on_players_changed(null)
	
	Globals.connect("on_map_selection_changed", self, "_on_map_selection_changed")
	
	Globals.net.connect("server_disconnected", self, "_server_disconnected")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if get_tree().network_peer != null and Globals.net.get_connection_status() != NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		$game_setup_menu/ctrl_online/btn_online_host.hide()
		$game_setup_menu/ctrl_online/btn_online_join.hide()
		if get_tree().is_network_server():
			pass
		else:
			$game_setup_menu/ctrl_map_selection/list_maps.disabled = true
			$game_setup_menu/ctrl_map_selection/btn_start.hide()
			$game_setup_menu/ctrl_online.hide()
	
func _on_players_changed(player):
	_on_PlayerList_Refresh_Timer_timeout()

func _on_btn_find_public_ip_pressed():
	var r = Globals.upnp_get_external_ip()
	
	if r == "":
		$game_setup_menu/ctrl_online/lbl_public_ip_number.text = "Failed"
		$game_setup_menu/ctrl_online/btn_find_public_ip.disabled = true
	else:
		$game_setup_menu/ctrl_online/lbl_public_ip_number.text = str(r)


func _on_btn_upnp_open_port_pressed():
	var r = Globals.upnp_open_port()
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		$game_setup_menu/ctrl_online/lbl_upnp_result.text = "Port Opened"
	else:
		$game_setup_menu/ctrl_online/lbl_upnp_result.text = "Failed"
	$game_setup_menu/ctrl_online/lbl_upnp_result.show()
	$game_setup_menu/ctrl_online/btn_upnp_open_port.disabled = true


func _on_btn_start_pressed():
	if get_tree().network_peer == null or Globals.net.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		Globals.network_single_player()

	Globals.rpc("change_scene", Globals.maps[Globals.selected_map].Resource)


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
	
	var r = Globals.network_create_client($game_setup_menu/ctrl_online/le_ipv4.text)

func _on_btn_back_pressed():
	Globals.network_close_connection()
	Globals.change_scene("res://Scenes/User_Interface/Menus/main_menu/main_menu.tscn")


func _on_btn_online_host_pressed():
	$game_setup_menu/ctrl_online/btn_online_join.hide()
	$game_setup_menu/ctrl_online/btn_online_host.hide()
	
	Globals.network_create_server()


func _on_PlayerList_Refresh_Timer_timeout():
	$Players/PlayerList.clear()
	for p in Globals.players:
		$Players/PlayerList.add_item(str(p.ID) + ": " + p.Name)


func _server_disconnected():
	_on_btn_back_pressed()


func _on_le_set_your_name_text_entered(new_text):
	if Globals.net.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		Globals.player_change_name(Globals.players[0].ID,new_text)
	else:
		Globals.rpc("player_change_name",Globals.players[0].ID,new_text)


func _on_PlayerList_item_selected(index):
	if get_tree().is_network_server() and index != 0:
		Globals.remove_player_with_id(Globals.players[index].ID)

func connect_all():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
