extends Node

export (NodePath) var Node_Path_Enemy_Spawners
export (NodePath) var Node_Path_Player_Spawners
export (NodePath) var Node_Path_Navigation

export (int) var override_player_speed = 0
export (int) var override_enemy_max_speed = 0

var _spawners_enemies = []
var _spawners_players = []

var players_done_syncing = 0
var game_already_loaded = false

func _ready():
	players_done_syncing = 0
	Globals.Navigation_Node = get_node_or_null(Node_Path_Navigation)
	
	_spawners_enemies = get_node(Node_Path_Enemy_Spawners).get_children()
	_spawners_players = get_node(Node_Path_Player_Spawners).get_children()
	
	Globals.connect("when_player_added", self, "_player_added")
	Globals.connect("when_player_removed", self, "_player_removed")
	
	Networking.connect("on_server_disconnected", self, "_server_disconnected")
	
	if Networking.is_server():
		game_already_loaded=false
		Globals._reset_globals_map_data()
		
		for p in Globals.players:
			p.init_nodes()
			p.reset_to_default_values()
		
		spawn_players(true)
		yield(get_tree().create_timer(.3), "timeout")
		_client_is_done_syncing()
		
		# Game Start/Join Flow
		#Wait until all other players map's have loaded in
		#Sync Game Data Across Clients
		#Spawn Players in (and wait for all clients)
		#Start Game
		
	else:
		# Client asks for Server's Map Info
		yield(get_tree().create_timer(.3), "timeout") # Wait for server to finish seting up, before asking for game data
		rpc_id(NetworkedMultiplayerPeer.TARGET_PEER_SERVER, "_client_requesting_game_data")


remote func _client_requesting_game_data():
	#Should always be server when this is called
	var id = get_tree().get_rpc_sender_id()
	
	Globals.emit_signal("send_client_map_setup_info", id)
	
	# Send game info to client
	var a = []
	for p in Globals.players:
		a.append(p.serialize())
	rpc_id(id, "_server_sent_game_data", {"game_info": Globals.serialize_game_data(), "players_info":a})


remote func _server_sent_game_data(data:Dictionary):
	#Should Always be client when this is called
	Globals.deserialize_game_data(data.game_info)
	
	if data.players_info.size() != Globals.players.size():
		print("Player Size Mismatch! Server has a different amount of players registered, Error Not Handled")
	
	spawn_players(true)
	
	for info in data.players_info:
		for p in Globals.players:
			if p.ID == info.ID:
				p.deserialize(info)
	
	yield(get_tree().create_timer(.3), "timeout") # Wait for setup to finish
	rpc_id(NetworkedMultiplayerPeer.TARGET_PEER_SERVER, "_client_is_done_syncing")

remote func _client_is_done_syncing():
	#Server and Client calls this function
	if Networking.is_server():
		players_done_syncing += 1
		if players_done_syncing == Globals.players.size():
			if not game_already_loaded:
				$Between_Round_Timer.start()
				game_already_loaded = true
				Globals.set_game_pause(false, true)
			else:
				Globals.set_game_pause(true, true)

func _exit_tree():
	# Disconnect Incoming signals
	Globals.disconnect("when_player_added", self, "_player_added")
	Globals.disconnect("when_player_removed", self, "_player_removed")
	Globals.Navigation_Node = null


func _server_disconnected():
	Networking.close_connection()
	Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")

func _on_player_death():
	var b = true
	for p in Globals.players:
		if p.Destroyable != null and not p.Destroyable.is_dead:
			b = false
			break
	if b:
		Globals.rpc("change_scene","res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
		Dialog.rpc("display","Game Over", "Zombies Ate Your Brains, rnd: "+str(Globals.zombie_round))

func _spawn_player(player, _origin=null):
	$Spawned_Players.add_child(player.Body)
	if _origin==null:
		_origin =  _spawners_players[randi() % _spawners_players.size()].global_transform.origin
	player.Body.global_transform.origin = _origin
	
	if Networking.is_server():
		player.Destroyable.connect("on_death", self, "_on_player_death")
	
	if override_player_speed > 0:
		player.Player_Controller.Speed = override_player_speed
	
	if player.Player_Controller.weapon == null and player.Player_Controller.weapons.size() == 0:
		player.Player_Controller.set_gun(0)

remotesync func spawn_players(reset_all_players: bool = false):
	for p in Globals.players:
		if p.Destroyable == null or not is_instance_valid(p.Destroyable):
			p.init_nodes()
		
		if reset_all_players:
			# Reset Player Values
			p.reset_to_default_values()
			
		var is_dead = p.Destroyable.is_dead
		
		if $Spawned_Players.get_node_or_null(p.Body.name) == null:
			# Add Players to the Map
			_spawn_player(p)
		elif is_dead:
			var _origin =  _spawners_players[randi() % _spawners_players.size()].global_transform.origin
			p.Body.global_transform.origin = _origin
		
		if (reset_all_players or is_dead):
			p.Player_Controller.set_gun(0)
			var w = p.Player_Controller.weapon
			p.Player_Controller.weapon.set_ammo(w.clip_can_hold, w.max_total_ammo)
		
		if p.Player_Controller.weapon != null and is_instance_valid(p.Player_Controller.weapon) and p.Player_Controller.weapon.Weapon_Name == Globals.guns[0].Name:
			var w = p.Player_Controller.weapon
			p.Player_Controller.weapon.set_ammo(w.ammo_in_clip, w.total_ammo+w.max_total_ammo)
		
		if p.Destroyable.is_dead:
			p.Destroyable.rpc("Resurrect", p.Max_Health)
		elif p.Destroyable.is_bleeding_out:
			p.Destroyable.rpc("Revive", p.Max_Health)


func _on_Spawn_Timer_timeout():#
	var close_spawners_by_player = []
	
	var close_spawners = []
	var dis = 0
	
	# Filter out all spawners that are too close to any player
	for spawner in _spawners_enemies:
		var to_close = false
		for player in Globals.players:
			dis = spawner.global_transform.origin.distance_to(player.Body.global_transform.origin)
			if dis <= 25:
				to_close = true
				break
		if not to_close:
			close_spawners.append([dis,spawner])
		
	# Sort spawners by players, and how close the spawners are to each player
	for player in Globals.players:
		for i in range(0,close_spawners.size()):
			close_spawners[i][0] = close_spawners[i][1].global_transform.origin.distance_to(player.Body.global_transform.origin)
		
		close_spawners.sort_custom(self, "_sort_custom")

		close_spawners_by_player.append(close_spawners)
		
		#Only select a couple of the closest spawners
		while close_spawners_by_player[close_spawners_by_player.size()-1].size() > 3:
			close_spawners_by_player[close_spawners_by_player.size()-1].pop_back()
	
	# Make sure each spawner is only selected once
	close_spawners = []
	for spawners in close_spawners_by_player:
		for spawner in spawners:
			if not close_spawners.has(spawner):
				close_spawners.append(spawner[1])
	
	# Spawn zombies (Hopefully, every player will have zombies spawn near not close to them, and without zombie spawn spamming)
	for i in range(0, close_spawners.size()):
		if Globals.zombies_spawned_this_round >= Globals.zombies_to_spawn_this_round:
			$Spawn_Timer.stop()
			break
		if $Spawned_Enemies.get_child_count() >= Globals.max_zombies_at_a_time:
			break
		server_spawn_zombie(close_spawners[i].global_transform.origin)


static func _sort_custom(a:Array,b:Array):
	# a,b formating = [distance,spawner]
	return a[0] < b[0]


remotesync func _play_round_end_sound():
	$Sound_Round_End.play()
	
remotesync func _new_round():
	$Sound_Round_Start.play()
	for player in Globals.players:
		player.Player_Controller.new_round()


func _on_Between_Round_Timer_timeout():
	Globals.set_round(Globals.zombie_round + 1)
	Globals.set_zombies_killed_this_round(0)
	Globals.set_zombies_spawned_this_round(0)

	if Globals.zombie_round > 1:
		Globals.set_current_zombie_health(round(Globals.zombie_round * Globals.starting_zombie_health * 0.8))
		Globals.set_zombies_to_spawn_this_round(ceil(Globals.zombies_to_spawn_this_round * 1.1))
	$Spawn_Timer.start()
	$Between_Round_Timer.stop()
	
	rpc("spawn_players", false)
	rpc("_new_round")


func _player_added(player):
	if player.Body == null:
		player.init_nodes()
	$Spawned_Players.add_child(player.Body)
	if Networking.is_server():
		Globals.set_game_pause(true,false)
		players_done_syncing = Globals.players.size()-1
		Globals.rpc_id(int(player.ID), "change_map_selection", Globals.selected_map)
		Globals.rpc_id(int(player.ID),"change_game_map", Globals.game_maps[Globals.selected_map].Name)
#		Globals.rpc_id(int(player.ID), "change_scene", Globals.maps[Globals.selected_map].Resource)


func _player_removed(player):
	while true:
		var n = $Spawned_Players.get_node_or_null(str(player.ID))
		if n == null:
			break
		else:
			$Spawned_Players.remove_child(n)


func on_zomb_death():
	if Networking.is_server():
		Globals.set_zombies_killed_this_round(Globals.zombies_killed_this_round+1)

		if Globals.zombies_killed_this_round >= Globals.zombies_to_spawn_this_round:
			$Between_Round_Timer.start()
			rpc("spawn_players")
			rpc("_play_round_end_sound")

func server_spawn_zombie(_origin):
	var max_speed = Globals.max_zombie_speed
	if override_enemy_max_speed:
		max_speed = override_enemy_max_speed
	
	var min_speed = min(max_speed * Globals.min_zombie_speed_percent + Globals.zombie_round * 0.1, max_speed-1)
	var zspeed = rand_range(min_speed, max_speed)
	
	
	rpc("spawn_zombie",
	_origin,
	zspeed,
	"zombie_" + str(Globals.zombies_spawned_this_round))

remotesync func spawn_zombie(at: Vector3, speed, name):
	var zomb = Globals.ai_zombie.instance()
	var des = zomb.get_node(Globals.GROUP_DESTROYABLE)
	des.health = Globals.current_zombie_health
	des.Absorption = 1 + Globals.zombie_round * 1.5
	
	if Networking.is_server():
		des.connect("on_death", self, "on_zomb_death")
		
	zomb.get_node("AI_Controller").speed = speed
	zomb.name = name
	
#	$Spawned_Enemies.add_child(zomb)
	Globals.node_spawnedin_synced.add_child(zomb)
	zomb.global_transform.origin = at
	if Networking.is_server():
		Globals.set_zombies_spawned_this_round(Globals.zombies_spawned_this_round + 1)
	
	
#class MyCustomSorter:
#    static func sort_ascending(a, b):
#        if a[0] < b[0]:
#            return true
#        return false
#
#var my_items = [[5, "Potato"], [9, "Rice"], [4, "Tomato"]]
#my_items.sort_custom(MyCustomSorter, "sort_ascending")
#print(my_items) # Prints [[4, Tomato], [5, Potato], [9, Rice]].

