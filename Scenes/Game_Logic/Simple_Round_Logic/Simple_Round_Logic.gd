extends Node

export (NodePath) var Node_Path_Enemy_Spawners
export (NodePath) var Node_Path_Player_Spawners
export (NodePath) var Node_Path_Navigation

export (int) var override_player_speed = 0
export (int) var override_enemy_max_speed = 0

var _spawners_enemies = []
var _spawners_players = []

func _ready():
	Globals.current_scene = get_parent()
	Globals._reset_globals_map_data()
	
	Globals.Navigation_Node = get_node_or_null(Node_Path_Navigation)
	
	_spawners_enemies = get_node(Node_Path_Enemy_Spawners).get_children()
	_spawners_players = get_node(Node_Path_Player_Spawners).get_children()
	
	Globals.connect("when_player_added", self, "_player_added")
	Globals.connect("when_player_removed", self, "_player_removed")
	
	Globals.net.connect("server_disconnected", self, "_server_disconnected")
	Globals.connect("client_finished_changing_scene", self, "_client_finished_changing_scene")
	
	if get_tree().is_network_server():
		rpc("spawn_players", true)
		$Between_Round_Timer.start()
		rpc("_play_round_end_sound")
	else:
		Globals.rpc_id(1, "client_requests_map_info")

func _server_disconnected():
	Globals.network_close_connection()
	Globals.change_scene("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")

func _on_player_death():
	var b = true
	for p in Globals.players:
		if p.Destroyable != null and not p.Destroyable.is_dead:
			b = false
			break
	if b:
		Globals.rpc("change_scene","res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
		Dialog.rpc("display","Game Over", "Zombies Ate Your Brains")

func _spawn_player(player):
	var spawner:Spatial = _spawners_players[randi() % _spawners_players.size()]
	$Spawned_Players.add_child(player.Body)
	player.Body.global_transform.origin = spawner.global_transform.origin
	player.Body.rotation = spawner.rotation
	
	if get_tree().is_network_server():
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
		
		if p.Destroyable.is_dead:
			p.Destroyable.rpc("Resurrect", p.Max_Health)
		elif p.Destroyable.is_bleeding_out:
			p.Destroyable.rpc("Revive", p.Max_Health)
		
		if (reset_all_players or p.Destroyable.is_dead):
			p.Player_Controller.set_gun(0)
		
		if $Spawned_Players.get_node_or_null(p.Body.name) == null:
			# Add Players to the Map
			_spawn_player(p)


func _on_Spawn_Timer_timeout():#
	var close_spawners_by_player = []
	
	for player in Globals.players:
		var close_spawners = []
		for spawner in _spawners_enemies:
			var dis = spawner.global_transform.origin.distance_to(player.Body.global_transform.origin)
			if dis > 25:
				close_spawners.append([dis,spawner])
		
		close_spawners.sort_custom(self, "_sort_custom")
		while close_spawners.size() > 3:
			close_spawners.pop_back()
			
		close_spawners_by_player.append(close_spawners)
	
	for i in range(0, close_spawners_by_player.size()):
		if Globals.zombies_spawned_this_round >= Globals.zombies_to_spawn_this_round:
			$Spawn_Timer.stop()
			break
		if $Spawned_Enemies.get_child_count() >= Globals.max_zombies_at_a_time:
			break
		server_spawn_zombie(close_spawners_by_player[i][rand_range(0, close_spawners_by_player[i].size())][1].global_transform.origin)

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
	if Globals.network_is_server():
		Globals.rpc_id(int(player.ID), "change_map_selection", Globals.selected_map)
		Globals.rpc_id(int(player.ID), "change_scene", Globals.maps[Globals.selected_map].Resource)

func _client_finished_changing_scene(player_id, changed_to:NodePath):
	rpc_id(player_id, "spawn_players", false)
	Globals.rpc_id(player_id, "_set_game_pause", get_tree().paused)

func _player_removed(player):
	while true:
		var n = $Spawned_Players.get_node_or_null(str(player.ID))
		if n == null:
			break
		else:
			$Spawned_Players.remove_child(n)


func on_zomb_death():
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
	
	if get_tree().is_network_server():
		des.connect("on_death", self, "on_zomb_death")
		
	zomb.get_node("AI_Controller").speed = speed
	zomb.name = name
	
	$Spawned_Enemies.add_child(zomb)
	zomb.global_transform.origin = at
	if get_tree().is_network_server():
		Globals.set_zombies_spawned_this_round(Globals.zombies_spawned_this_round + 1)

static func _sort_custom(a:Array,b:Array):
	# a,b formating = [distance,spawner]
	return a[0] < b[0]
	
	
#class MyCustomSorter:
#    static func sort_ascending(a, b):
#        if a[0] < b[0]:
#            return true
#        return false
#
#var my_items = [[5, "Potato"], [9, "Rice"], [4, "Tomato"]]
#my_items.sort_custom(MyCustomSorter, "sort_ascending")
#print(my_items) # Prints [[4, Tomato], [5, Potato], [9, Rice]].

