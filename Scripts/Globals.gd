extends Node

signal game_pause_state_changed

signal when_player_added(player)
signal when_player_removed(player)
signal on_map_selection_changed(index)
signal client_finished_changing_scene(player_id, changed_to) #Resource

signal send_client_map_setup_info(client_id)

onready var game_setup = preload("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
onready var main_menu = preload("res://Scenes/User_Interface/Menus/main_menu/main_menu.tscn")

onready var pl_character = preload("res://Scenes/Characters/Blockhead/Blockhead_Player.tscn")
onready var ai_zombie = preload("res://Scenes/Characters/Blockhead/Blockhead_Zombie.tscn")

enum Product_Types {gun, barrier, perk, grenade}

var guns = [
	{"Scene": preload("res://Assets/3D/Handgun/Handgun.tscn"), "Name": "Handgun"},
	{"Scene": preload("res://Assets/3D/Rifle/Rifle.tscn"), "Name":"Rifle"}
	]
	
var Navigation_Node: Navigation = null

var current_scene: Spatial = null
var node_spawnedin: Node = null
var node_spawnedin_unsynced: Node = null
var node_spawnedin_synced: Node = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

func get_unique_name(node_at: Node, prefix: String = ""):
	while true:
		var _name:String = prefix
		_name = _name + str(round(rand_range(0,9)*100))
		if node_at.get_node_or_null(_name) == null:
			return _name

func get_gun_by_name(name):
	for g in guns:
		if name == g.Name:
			return g
	return null
	
func get_gun_index_by_name(name):
	for i in range(guns.size()):
		if name == guns[i].Name:
			return i
	return null

var maps = [
	{"Name": "Theater", "Resource": "res://Scenes/Map_Stuff/Maps/Theater/Theater.tscn", "Description": "Zombies like to watch movies too, except with brains instead of popcorn."},
	{"Name": "Theater, Dark", "Resource": "res://Scenes/Map_Stuff/Maps/Theater/Theater_Dark.tscn", "Description": "Are you Scared of the Dark?"},
	{"Name": "Modular Test", "Resource": "res://Scenes/Map_Stuff/Maps/Modular_Test/Modular_Test.tscn", "Description": "Map for Testing AI and Geomotry"},
	{"Name": "Barn Fast", "Resource": "res://Scenes/Map_Stuff/Maps/Barn/Barn_Fast.tscn", "Description": "Very Simple Zombie Map, But Faster"},
	{"Name": "Barn", "Resource": "res://Scenes/Map_Stuff/Maps/Barn/Barn.tscn", "Description": "Very Simple Zombie Map"},
	{"Name": "Ramp_House_Test", "Resource": "res://Scenes/Map_Stuff/Maps/Ramp_Test_House/Ramp_Test_House.tscn", "Description": "Map for Testing AI and Geomotry"},
]

#var my_player: Player = null
var players: Array = []

func get_player_with_id(id):
	for x in players:
		if x.ID == str(id):
			return x
	return null

func delete_player_with_id(id):
	var p = Globals.get_player_with_id(id)
	p.Destroyable._delete()
	Globals.players.erase(p)
	
func safe_delete_all_players():
	for x in players:
		self.queue_free()
		x.Body.queue_free()
		x.Destroyable.queue_free()
	players.clear()

const GROUP_PLAYERS = "Players"
const GROUP_ENEMIES = "Enemies"
const GROUP_DESTROYABLE = "Destroyable"
const GROUP_REVIVABLE = "Revivable"
const GROUP_BUYABLE = "Buyable"
const GROUP_SERIALIZABLE = "Serializable"

var selected_map:int = 0

var max_zombies_at_a_time = 75 # Limitations due to bad FPS, from physics processing the hoard of zombies running into each other
var zombies_to_spawn_this_round = 6
var zombies_spawned_this_round = 0
var zombies_killed_this_round = 0
var zombie_round = 0
var current_zombie_health = 100
var starting_zombie_health = 100
var max_zombie_speed = 5
var min_zombie_speed_percent = 0.4

var upnp: UPNP = UPNP.new()
var net: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
var default_port: int = 4000
var my_peer_id = null
var opened_ports = []
var upnp_discovery_ran = false

func _ready():
	randomize()
	
	_network_connect_all()
	
	add_player(Player.new())

func upnp_discovery():
	if not upnp_discovery_ran:
		upnp.discover(2000, 2, "InternetGatewayDevice")
		upnp_discovery_ran = true

func upnp_open_port(port: int = default_port):
	upnp_discovery()
	
	var gate = upnp.get_gateway()
	
	if gate == null:
		return UPNP.UPNP_RESULT_NO_GATEWAY
	elif not gate.is_valid_gateway():
		return UPNP.UPNP_RESULT_INVALID_GATEWAY
	
	var r = upnp.add_port_mapping(port, 0, "Aether Multiplayer", "UDP")
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		opened_ports.append(port)
		
	return r


func upnp_close_port(port: int = default_port):
	upnp_discovery()
	
	var gate = upnp.get_gateway()
	
	if gate == null:
		return UPNP.UPNP_RESULT_NO_GATEWAY
	elif not gate.is_valid_gateway():
		return UPNP.UPNP_RESULT_INVALID_GATEWAY
		
	var r = upnp.delete_port_mapping(port)
	
	if r == UPNP.UPNP_RESULT_SUCCESS:
		opened_ports.erase(port)
	
	return r


func upnp_get_external_ip():
	upnp_discovery()
	
	return upnp.query_external_address()


func network_close_connection():
	if net.get_connection_status() != NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		net.close_connection()
		
		get_tree().network_peer = null # DO NOT REMOVE, ABSOLUTLY REQUIRED FOR RECONNECTING CLIENTS
		# This causes Godot to clear the Multiplayer API Cache, allowing the same client to reconnect after disconnecting
		
		while players.size() > 1:
			remove_player_with_id(players[1].ID)


func _net_check(result):
	if result == OK:
		get_tree().network_peer = net
		my_peer_id = get_tree().get_network_unique_id()
		players[0].ID = str(my_peer_id)
#		players[0].Body.set_network_master(my_peer_id)
#		players[0].Body.name = str(my_peer_id)
##		players[0].Body.node_camera.current = true
	else:
		network_close_connection()
		print("Connection Check Failed, closing Connection")


func network_create_client(IPv4, port = default_port):
	Globals.net.refuse_new_connections=false
	if get_tree().network_peer != null and not get_tree().network_peer.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		network_close_connection()
	var r = net.create_client(IPv4, port)
	_net_check(r)
	return r


func network_create_server(port = default_port):
	Globals.net.refuse_new_connections=false
	if get_tree().network_peer != null and not get_tree().network_peer.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		network_close_connection()
	var r = net.create_server(port)
	_net_check(r)
	return r


func network_single_player(port = default_port):
	Globals.net.refuse_new_connections=true
	if get_tree().network_peer != null and not get_tree().network_peer.get_connection_status() == NetworkedMultiplayerENet.CONNECTION_DISCONNECTED:
		network_close_connection()
	var r = net.create_server(port)
	_net_check(r)
	return r


func quit():
	network_close_connection()
	
	for p in opened_ports:
		upnp_close_port(p)
	
	get_tree().quit()


func network_is_server():
	return get_tree().network_peer != null and get_tree().is_network_server()


func network_connected():
	return get_tree().network_peer != null and net.get_connection_status() != net.CONNECTION_DISCONNECTED


remotesync func change_scene(resource):
	_set_game_pause(true)
	Navigation_Node = null
	get_tree().change_scene(resource)
	_set_game_pause(false)
	if network_connected() and get_tree().get_rpc_sender_id() != my_peer_id:
		rpc_id(get_tree().get_rpc_sender_id(), "_client_finished_changing_scene", resource)


remote func _client_finished_changing_scene(changed_to: NodePath):
	emit_signal("client_finished_changing_scene", get_tree().get_rpc_sender_id(), changed_to)


func _network_connect_all():
	net.connect("peer_connected", self, "_network_player_connected")
	net.connect("peer_disconnected", self, "_network_player_disconnected")
	net.connect("server_disconnected", self, "_network_server_disconnected")
	net.connect("connection_failed", self, "_network_connection_failed")
	net.connect("connection_succeeded", self, "_network_connection_succeeded")


remote func _returned_player(player):
	Globals.add_player(Player.new().deserialize(player))
	print("returned: ", get_tree().get_rpc_sender_id(), player.Name)
	pass


remote func _request_my_player():
	var peer = get_tree().get_rpc_sender_id()
	rpc_id(peer, "_returned_player", Globals.players[0].serialize())
	print("request from: ", peer, name)
	pass

func _reset_globals_map_data():
	zombies_to_spawn_this_round = 4
	zombies_spawned_this_round = 0
	zombies_killed_this_round = 0
	zombie_round = 0
	current_zombie_health = starting_zombie_health

remote func _set_globals_data(data: Dictionary):
	_set_game_pause(data.pause)
	zombies_to_spawn_this_round = data.zombies_to_spawn_this_round
	zombies_spawned_this_round = data.zombies_spawned_this_round
	zombies_killed_this_round = data.zombies_killed_this_round
	zombie_round = data.zombie_round
	current_zombie_health = data.current_zombie_health


func _network_player_connected(id):
	print("Player Connected: ", id)
	rpc_id(id, "_request_my_player")
	if get_tree().is_network_server():
		rpc_id(id, "_set_globals_data", 
		{"pause": get_tree().paused,
		"zombies_to_spawn_this_round": zombies_to_spawn_this_round,
		"zombies_spawned_this_round": zombies_spawned_this_round,
		"zombies_killed_this_round": zombies_killed_this_round,
		"zombie_round": zombie_round,
		"current_zombie_health": current_zombie_health,
		}
		)

func _network_player_disconnected(id):
	remove_player_with_id(str(id))
	print("Player Disconnected: ", id)
	pass

func _network_server_disconnected():
	print("Server Disconnected")
	Dialog.display("Server Disconnected","")
	pass

func _network_connection_succeeded():
	print("Network Connection Succeeded")
	pass

func _network_connection_failed():
	print("Network Connection Failed")
	pass

remotesync func add_player(player: Player):
	players.append(player)
	emit_signal("when_player_added", player)

remotesync func remove_player_with_id(id: String):
	for i in range(players.size()):
		if players[i].ID == id:
			emit_signal("when_player_removed", players[i])
			if get_tree().network_peer != null and get_tree().is_network_server():
				net.disconnect_peer(int(id))
			players.remove(i)
			break

remotesync func change_map_selection(new_index: int):
	selected_map = new_index
	emit_signal("on_map_selection_changed", new_index)


remotesync func player_change_name(player_id: String, new_name: String):
	for p in players:
		if p.ID == player_id:
			p.Name = new_name
			break

remotesync func player_set_points(player_id: String, new_points: int):
	get_player_with_id(player_id).Points = new_points

var Default_Player_Speed: int = 5
class Player:
	var Name: String = "Unnamed"
	var ID: String = "No ID"
	
	var Max_Health: int = 100
	var Points: int = 0
	var Kills: int = 0
	var Deaths: int = 0
	
	var Body: KinematicBody = null
	var Destroyable: Node = null
	var Player_Controller: Node = null
	
	func init_nodes():
		Body = Globals.pl_character.instance()
		
		Destroyable = Body.get_node("Destroyable")
		Player_Controller = Body.get_node("Player_Controller")
		
		Player_Controller.player = self
		
		reset_to_default_values()
		
		Player_Controller.player = self
		
		Body.name = str(ID)
		Body.set_network_master(int(ID))
		
		if str(Globals.my_peer_id) == ID:
			Body.set_active_camera()
		
		Destroyable.health = Max_Health
		Destroyable.Max_Regen = Max_Health
		Player_Controller.Speed = Globals.Default_Player_Speed
		
		if Player_Controller != null:
			Player_Controller.set_visibility(true)
	
	func _init():
#		reset()
		pass
	
	
	#Except for the users name and ID
	# Remember this is not RPC, doesn't sync across devices
	func reset_to_default_values():
		Points = 0
		Kills = 0
		Deaths = 0
		
		Destroyable.health = Max_Health
		Destroyable.Max_Regen = Max_Health
		Destroyable.is_dead = false
		Player_Controller.Speed = Globals.Default_Player_Speed
		
		if Player_Controller != null:
			Player_Controller.set_visibility(true)
	
	func serialize():
		var a = {
			"Name": Name,
			"ID": ID,
			"Max_Health": Max_Health,
			"Points": Points,
			"Kills": Kills,
			"Deaths": Deaths,
			"Body": null,
			"Destroyable": null,
			"Player_Controller": null
		}
		
		if Body != null and is_instance_valid(Body) and Body.is_in_group(GROUP_SERIALIZABLE):
			a.Body = Body.serialize()
			
		if Destroyable != null and is_instance_valid(Destroyable) and Body.is_in_group(GROUP_SERIALIZABLE):
			a.Destroyable = Destroyable.serialize()
			
		if Player_Controller != null and is_instance_valid(Player_Controller) and Body.is_in_group(GROUP_SERIALIZABLE):
			a.Player_Controller = Player_Controller.serialize()
		
		return a
	
	func deserialize(data):
		Name = data.Name
		ID = data.ID
		Max_Health = data.Max_Health
		Points = data.Points
		Kills = data.Kills
		Deaths = data.Deaths
		
		if (data.Body != null or data.Destroyable != null or data.Player_Controller != null) and (Body == null or Destroyable == null or Player_Controller == null):
			init_nodes()
		
		if data.Body != null:
			Body.deserialize(data.Body)
			Body.name = str(data.ID)
		
		if data.Destroyable != null:
			Destroyable.deserialize(data.Destroyable)
		
		if data.Player_Controller != null:
			Player_Controller.deserialize(data.Player_Controller)
		
		return self


func set_game_pause(new_state):
	rpc("_set_game_pause", new_state)

remotesync func _set_game_pause(new_state):
	get_tree().paused = new_state
	emit_signal("game_pause_state_changed", new_state)


func set_zombies_killed_this_round(new_value: int):
	rpc("_set_zombies_killed_this_round", new_value)

remotesync func _set_zombies_killed_this_round(new_value: int):
	zombies_killed_this_round = new_value

func set_round(new_value: int):
	rpc("_set_round", new_value)

remotesync func _set_round(new_value: int):
	zombie_round = new_value

func set_zombies_to_spawn_this_round(new_value: int):
	rpc("_set_zombies_to_spawn_this_round", new_value)

remotesync func _set_zombies_to_spawn_this_round(new_value: int):
	zombies_to_spawn_this_round = new_value

func set_zombies_spawned_this_round(new_value: int):
	rpc("_set_zombies_spawned_this_round", new_value)

remotesync func _set_zombies_spawned_this_round(new_value: int):
	zombies_spawned_this_round = new_value

func set_current_zombie_health(new_value: int):
	rpc("_set_current_zombie_health", new_value)

remotesync func _set_current_zombie_health(new_value: int):
	current_zombie_health = new_value


remote func client_requests_map_info():
	print("requests map info: ", get_tree().get_rpc_sender_id())
	emit_signal("send_client_map_setup_info", get_tree().get_rpc_sender_id())
