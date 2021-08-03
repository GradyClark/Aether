extends Node

signal game_pause_state_changed

signal when_player_added(player)
signal when_player_removed(player)
signal on_map_selection_changed(index)

signal send_client_map_setup_info(client_id)

#Make sure this signleton is loaded first, before any other script uses this enum (this goes for all enums that are refereced outside of their host script)
enum Product_Types {gun, barrier, perk, grenade}

onready var game_setup = load("res://Scenes/User_Interface/Menus/game_setup/game_setup.tscn")
onready var main_menu = load("res://Scenes/User_Interface/Menus/main_menu/main_menu.tscn")

onready var pl_character = load("res://Scenes/Characters/Blockhead/Blockhead_Player.tscn")
onready var ai_zombie = load("res://Scenes/Characters/Blockhead/Blockhead_Zombie.tscn")
onready var pl_blockhead_character = load("res://Scenes/Characters/Blockhead/Blockhead.tscn").instance()
onready var pl_grenade = load("res://Assets/3D/Grenade/Grenade.tscn").instance()

#DON'T PRELOAD MAPS, BECAUSE THEY WILL LOAD BEFORE GLOBALS, AND BREAK and Enums The Map uses that are from Globals, or any other AutoLoaded Singleton
onready var game_maps = [
	Map.new("Theater", "Zombies like to watch movies too, except with brains instead of popcorn.", load("res://Scenes/Map_Stuff/Maps/Theater/Theater.tscn")),
	Map.new("Theater, Dark", "Are you Scared of the Dark?", load("res://Scenes/Map_Stuff/Maps/Theater/Theater_Dark.tscn")),
	Map.new("Modular Test", "Map for Testing AI and Geomotry", load("res://Scenes/Map_Stuff/Maps/Modular_Test/Modular_Test.tscn")),
	Map.new("Ramp_House_Test", "Map for Testing AI and Geomotry", load("res://Scenes/Map_Stuff/Maps/Ramp_Test_House/Ramp_Test_House.tscn")),
	Map.new("Barn", "Very Simple Zombie Map", load("res://Scenes/Map_Stuff/Maps/Barn/Barn.tscn")),
	]

#var maps = [
#	{"Name": "Theater", "Resource": "res://Scenes/Map_Stuff/Maps/Theater/Theater.tscn", "Description": "Zombies like to watch movies too, except with brains instead of popcorn."},
#	{"Name": "Theater, Dark", "Resource": "res://Scenes/Map_Stuff/Maps/Theater/Theater_Dark.tscn", "Description": "Are you Scared of the Dark?"},
#	{"Name": "Modular Test", "Resource": "res://Scenes/Map_Stuff/Maps/Modular_Test/Modular_Test.tscn", "Description": "Map for Testing AI and Geomotry"},
#	{"Name": "Barn Fast", "Resource": "res://Scenes/Map_Stuff/Maps/Barn/Barn_Fast.tscn", "Description": "Very Simple Zombie Map, But Faster"},
#	{"Name": "Barn", "Resource": "res://Scenes/Map_Stuff/Maps/Barn/Barn.tscn", "Description": "Very Simple Zombie Map"},
#	{"Name": "Ramp_House_Test", "Resource": "res://Scenes/Map_Stuff/Maps/Ramp_Test_House/Ramp_Test_House.tscn", "Description": "Map for Testing AI and Geomotry"},
#]

onready var serializables = [
	ai_zombie.instance(),
	pl_grenade
]


var guns = [
	{"Scene": load("res://Assets/3D/Handgun/Handgun.tscn"), "Name": "Handgun"},
	{"Scene": load("res://Assets/3D/Rifle/Rifle.tscn"), "Name": "Rifle"},
	{"Scene": load("res://Assets/3D/skunk_rifle/skunk_rifle.tscn"), "Name": "Skunk_Rifle"},
	]

var Navigation_Node: Navigation = null

var node_spawnedin: Node = null
var node_spawnedin_unsynced: Node = null
var node_spawnedin_synced: Node = null

var gravity = ProjectSettings.get_setting("physics/3d/default_gravity")

var player_can_toggle_pause_state = true

func get_map_from_name(name):
	for m in game_maps:
		if m.Name == name:
			return m
	return null

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

#var my_player: Player = null
var players: Array = []

func get_player_with_id(id):
	for x in players:
		if x.ID == str(id):
			return x
	return null


func get_perk_by_product_id(product_id):
	for p in Perk_List:
		if product_id == p.Product_ID:
			return p
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

var Perk_List = [
	Perk.new("Hearty Sludge", "Drink_Health"),
	Perk.new("Roadrunner Liquor", "Drink_Speed")
]

func serialize_game_data():
	return {
		"zombies_to_spawn_this_round": zombies_to_spawn_this_round,
		"zombies_spawned_this_round": zombies_spawned_this_round,
		"zombies_killed_this_round": zombies_killed_this_round,
		"zombie_round": zombie_round,
		"current_zombie_health": current_zombie_health,
		}


func deserialize_game_data(data: Dictionary):
	zombies_to_spawn_this_round = data.zombies_to_spawn_this_round
	zombies_spawned_this_round = data.zombies_spawned_this_round
	zombies_killed_this_round = data.zombies_killed_this_round
	zombie_round = data.zombie_round
	current_zombie_health = data.current_zombie_health


func _ready():
	randomize()
	
	add_player(Player.new())


func _exit_tree():
	self.universal_disconnect_helper(self, ["game_pause_state_changed", "when_player_added",
	"when_player_removed","on_map_selection_changed"])


func universal_disconnect_helper(source, signal_name_list):
	for sig_name in signal_name_list:
		for sig in source.get_signal_connection_list(sig_name):
			source.disconnect(sig.signal, sig.target, sig.method)


func quit():
	Networking.clean_up()
	get_tree().quit()


remotesync func change_scene(resource):
	_set_game_pause(true, false)
	Navigation_Node = null
	node_spawnedin = null
	node_spawnedin_synced = null
	node_spawnedin_unsynced = null
	get_tree().change_scene(resource)
	if Networking.is_network_connected() and get_tree().get_rpc_sender_id() != Networking.my_peer_id:
		yield(get_tree().create_timer(1), "timeout")
	_set_game_pause(false, true)


remotesync func change_game_map(map_name):
	_set_game_pause(true, false)
	Navigation_Node = null
	node_spawnedin = null
	node_spawnedin_synced = null
	node_spawnedin_unsynced = null
	get_tree().change_scene_to(get_map_from_name(map_name).Scene)
#	if Networking.is_network_connected() and get_tree().get_rpc_sender_id() != Networking.my_peer_id:
#		yield(get_tree().create_timer(1), "timeout")


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
	_set_game_pause(data.pause, true)
	zombies_to_spawn_this_round = data.zombies_to_spawn_this_round
	zombies_spawned_this_round = data.zombies_spawned_this_round
	zombies_killed_this_round = data.zombies_killed_this_round
	zombie_round = data.zombie_round
	current_zombie_health = data.current_zombie_health

remotesync func add_player(player: Player):
	players.append(player)
	emit_signal("when_player_added", player)


remotesync func remove_player_with_id(id: String):
	for i in range(players.size()):
		if players[i].ID == id:
			emit_signal("when_player_removed", players[i])
			if Networking.is_server():
				get_tree().network_peer.disconnect_peer(int(id))
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

remotesync func add_perk_to_player(player_id:String, perk_name: String):
	var p:Player = get_player_with_id(player_id)	
	p.add_perk(get_perk_by_product_id(perk_name))

class Perk:
	var Name: String
	var Product_ID: String

	func _init(name:String, product_id:String):
		Name = name
		Product_ID = product_id
	
class Player:
	var Name: String = "Unnamed"
	var ID: String = "No ID"
	
	var Default_Max_Health: int = 100
	var Max_Health: int = Default_Max_Health
	var Points: int = 0
	var Kills: int = 0
	var Deaths: int = 0
	
	var Default_Max_Stamina: float = 50
	var Max_Stamina: float = Default_Max_Stamina
	var Stamina: float = Max_Stamina
	var Default_Stamina_Drain: float = 20
	var Stamina_Drain: float = Default_Stamina_Drain
	var Default_Stamina_Regen: float = 5
	var Stamina_Regen: float = Default_Stamina_Regen
	var Default_Sprint_Bonus: float = 2 # Percent
	var Sprint_Bonus: float = Default_Sprint_Bonus
	var Default_Speed: float = 3
	var Speed: float = Default_Speed
	
	var Body: KinematicBody = null
	var Destroyable: Node = null
	var Player_Controller: Node = null
	
	var Perks: Array = []
	
	func init_nodes():
		Body = Globals.pl_character.instance()
		
		Destroyable = Body.get_node_or_null("Destroyable")
		Player_Controller = Body.get_node_or_null("Player_Controller")
		
		Player_Controller.player = self
		
		reset_to_default_values()
		
		Player_Controller.player = self
		
		Body.name = str(ID)
		Body.set_network_master(int(ID))
		
		if str(Networking.my_peer_id) == ID:
			Body.set_active_camera()
		
		Destroyable.health = Max_Health
		Destroyable.Max_Regen = Max_Health
		
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
		
		Perks = []
		
		Max_Stamina = Default_Max_Stamina
		Stamina = Max_Stamina
		Stamina_Drain = Default_Stamina_Drain
		Stamina_Regen = Default_Stamina_Regen
		Sprint_Bonus = Default_Sprint_Bonus
		Speed = Default_Speed
		
		Max_Health = Default_Max_Health
		
		Destroyable.set_max_health(Max_Health)
#		Destroyable.is_dead = false
		
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
		
#		if (data.Body != null or data.Destroyable != null or data.Player_Controller != null) and (Body == null or Destroyable == null or Player_Controller == null):
		if Body == null or Destroyable == null or Player_Controller == null:
			init_nodes()
		
		if data.Body != null:
			Body.deserialize(data.Body)
			Body.name = str(data.ID)
		
		if data.Destroyable != null:
			Destroyable.deserialize(data.Destroyable)
		
		if data.Player_Controller != null:
			Player_Controller.deserialize(data.Player_Controller)
		
		return self
	
	func add_perk(perk: Perk):
		if perk == null:
			return
		
		self.Perks.append(perk)
		
		if perk.Product_ID == "Drink_Health":
			Max_Health += 100
			if Destroyable != null:
				Destroyable.set_max_health(Max_Health)
		elif perk.Product_ID == "Drink_Speed":
			Sprint_Bonus += 0.2
			Max_Stamina += 25
			Stamina_Regen += 5
	
	
	func remove_perk(index: int):
		if index > 0 and index < self.Perks.size():
			var perk = Perks[index]
			Perks.erase(perk)
			
			if perk.Product_ID == "Drink_Health":
				Max_Health -= 100
				if Destroyable != null:
					Destroyable.set_max_health(Max_Health)
			elif perk.Product_ID == "Drink_Speed":
				Sprint_Bonus -= 0.2
				Max_Stamina -= 25
				Stamina_Regen -= 5

class Map:
	var Name: String
	var Scene: Resource
	var Description: String

	func _init(name:String, description: String, scene:Resource):
		Name = name
		Description = description
		Scene = scene



func set_game_pause(new_state, _player_can_toggle_pause_state=true):
	rpc("_set_game_pause", new_state, _player_can_toggle_pause_state)


remotesync func _set_game_pause(new_state, _player_can_toggle_pause_state):
	get_tree().paused = new_state
	player_can_toggle_pause_state = _player_can_toggle_pause_state
	emit_signal("game_pause_state_changed", new_state, _player_can_toggle_pause_state)


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
