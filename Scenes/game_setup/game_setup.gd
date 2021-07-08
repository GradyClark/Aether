extends Spatial

var game_map = null

onready var character = preload("res://Assets/3D/Character/character.tscn")
onready var player_control = preload("res://Assets/3D/Character/Player_Controls.gd")
onready var handgun = preload("res://Assets/3D/Handgun/Handgun.tscn")

var hosting = false

func _ready():
	$game_setup_menu/ctrl_map_selection/list_maps.add_item("Barn")

func _on_btn_back_pressed():
	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")
	

func connect_all():
	get_tree().connect("network_peer_connected", self, "_player_connected")
	get_tree().connect("network_peer_disconnected", self, "_player_disconnected")
	get_tree().connect("server_disconnected", self, "_server_disconnected")
	
func _on_btn_start_pressed():
#	get_tree().change_scene(Globals.maps[Globals.selected_map][1])
	if not hosting:
		Globals.net.create_server(Globals.default_port, 2)
		Globals.net.refuse_new_connections=true
		get_tree().network_peer = Globals.net
	Globals.my_peer_id = get_tree().get_network_unique_id()
	connect_all()
	
	# Create Player 1 Script
	_player_connected(get_tree().get_network_unique_id())
	
	$game_setup_menu.hide()
	game_map = load(Globals.maps[Globals.selected_map][1]).instance()
	game_map.name = "level"
	add_child(game_map)
	if Globals.is_game_paused():
		Globals.set_game_pause(false)


func _on_btn_online_host_pressed():
	Globals.net.create_server(Globals.default_port, 32)
	get_tree().network_peer = Globals.net
	$game_setup_menu/ctrl_online.hide()
	hosting=true
	_on_btn_start_pressed()

func _on_btn_online_join_pressed():
	Globals.net.create_client($game_setup_menu/ctrl_online/le_ipv4.text, Globals.default_port)
	get_tree().network_peer = Globals.net
	Globals.my_peer_id = get_tree().get_network_unique_id()
	$game_setup_menu.hide()
	connect_all()

func _player_connected(id):
	print("Player Connected: ", id)
	
	if not get_tree().is_network_server() and id == 1:
		return
		
	var p = character.instance()

	p = character.instance()
#	var gun = Globals.guns[0].instance()
#	gun.actor = "../../../"
#	p.get_node("Camera/weapon_location").add_child(gun)
	p.name = str(id)

	var s = Node.new()
	p.add_child(s)
	s.set_script(player_control)
	s.name = "Player Controls"
	s.Eyes_Node = "../Camera"
	s.Body_Node = ".."
#	s.Weapon = gun
	
	var gp = Globals.Player.new()
	gp.Eyes = p.get_node("Camera")
	gp.Body = p
	gp.Destroyable = p.get_node("destroyable")
	gp.ID = id
	gp.Player_Control = s
	p.set_network_master(id)
	Globals.players.append(gp)
	
	if get_tree().is_network_server():
		gp.Destroyable.connect("on_death",self,"_on_player_death")
	
	if id == 1:
		return
	
	p.global_transform.origin = get_node("/root/Node2D/level/round_logic/").spawners_players[0].global_transform.origin
	get_node("/root/Node2D/level/round_logic/spawned_players").add_child(p)
	if not get_tree().is_network_server() and id == 1:
		return
	
	
	rpc_id(id, "_client_echo", "Hello Client, This is Server: "+str(get_tree().get_network_unique_id()))
	if get_tree().is_network_server():
		var plist = []
		for x in Globals.players:
			var w = x.Player_Control.Weapon
			if w != null:
				w = w.Weapon_Name
			plist.append({"id": x.ID, "health": x.Destroyable.health,
			 "points":x.Player_Control.Points,
			 "max_health": x.max_health,
			 "origin": x.Body.global_transform.origin,
			 "weapon_name": w
			})
		rpc_id(id, "_client_configure_game", Globals.maps[Globals.selected_map][1], plist)
		
		# Enemies
		var elist = []
		if get_node("/root/Node2D/level/round_logic/spawned_enemies") != null:
			for x in get_node("/root/Node2D/level/round_logic/spawned_enemies").get_children():
				var t = x.get_node("AI_Controller").target
				if t != null:
					t = t.get_path()
				elist.append({"name": x.name, "health": x.get_node("destroyable").health, "speed": x.get_node("AI_Controller").speed, "attack_damage": x.get_node("AI_Controller").attack_dammage, "origin": x.global_transform.origin, "target":t})
		
		var game_info = {"round":Globals.zombie_round,
		 "zombies_killed_this_round": Globals.zombies_killed_this_round,
		 "zombies_spawned_this_round": Globals.zombies_spawned_this_round,
		 "current_zombie_health": Globals.current_zombie_health,
		 "zombies_to_spawn_this_round": Globals.zombies_to_spawn_this_round}
		
		rpc_id(id, "_client_configure_game", Globals.maps[Globals.selected_map][1], plist, elist, Globals.is_game_paused(), game_info)
		gp.Player_Control.set_gun(0)

remote func _client_echo(message):
	print(get_tree().get_rpc_sender_id(), ": ", message)

remote func _client_configure_game(map, plist, elist, paused, game_info: Dictionary):
	game_map = load(map).instance()
	game_map.name = "level"
	add_child(game_map)
	var spawned_players_node = get_node("/root/Node2D/level/round_logic/spawned_players")

	# Game Config
	Globals._set_round(game_info.round)
	Globals._set_zombies_killed_this_round(game_info.zombies_killed_this_round)
	Globals._set_zombies_spawned_this_round(game_info.zombies_spawned_this_round)
	Globals._set_current_zombie_health(game_info.current_zombie_health)
	Globals._set_zombies_to_spawn_this_round(game_info.zombies_to_spawn_this_round)

	# Player Config
	for x in plist:
		var p = character.instance()
#		var gun = Globals.get_gun_by_name(x.weapon_name).instance()
#		gun.actor = "../../../"
#		p.get_node("Camera/weapon_location").add_child(gun)
		p.name = str(x.id)
		
		var s = Node.new()
		p.add_child(s)
		s.set_script(player_control)
		s.name = "Player Controls"
		s.Eyes_Node = "../Camera"
		s.Body_Node = ".."
#		s.Weapon = gun
#		s.set_gun(x.weapon_name)
		
		var gp = Globals.Player.new()
		gp.Eyes = p.get_node("Camera")
		gp.Eyes.current = true
		gp.Body = p
		gp.Destroyable = p.get_node("destroyable")
		gp.ID = x.id
		gp.Player_Control = s
		Globals.players.append(gp)
		p.set_network_master(int(x.id))
		spawned_players_node.add_child(gp.Body)
		
		gp.Body.global_transform.origin = x.origin
		gp.Player_Control.Points = x.points
		gp.Destroyable.health = x.health
		if x.health <= 0:
			gp.Player_Control._set_visibility(false)
		gp.max_health = x.max_health
		
		p.set_network_master(int(x.id))
		get_node("/root/Node2D/level/round_logic/spawned_players").add_child(p)
		
#		s._set_gun(1)
		if x.weapon_name != null:
			var i = Globals.get_gun_index_by_name(x.weapon_name)
			if i != null:
				s._set_gun(i)
#	{"name": x.name, "health": x.get_node("destroyable").health, "speed": x.get_node("AI_Control").speed, "attack_damage": x.get_node("AI_Control").attack_dammage}
	# Enemy Config
	for x in elist:
		var e = get_node("/root/Node2D/level/round_logic").spawn_zombie(x.origin, x.speed, x.name)
		e.get_node("destroyable").health = x.health
		e.get_node("AI_Controller").attack_dammage = x.attack_damage
		e.get_node("AI_Controller").target = get_node(x.target)
		get_node("/root/Node2D/level/round_logic/spawned_enemies").add_child(e)
	
	Globals._paused = paused
	Globals.emit_signal("game_pause_state_changed", paused)
	if paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _player_disconnected(id):
	Globals.delete_player_with_id(int(id))
	
func _server_disconnected():
	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")
	Globals.net.close_connection()
	Globals.players.clear()
	Globals.reset()

func _on_player_death():
	var l = Globals.players.size()
	for x in Globals.players:
		if x.Destroyable.is_dead:
			l -= 1
	if l == 0:
		_server_disconnected()
