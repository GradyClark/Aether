extends Node

signal game_pause_state_changed

onready var game_setup = preload("res://Scenes/game_setup/game_setup.tscn")
onready var main_menu = preload("res://Scenes/main_menu/main_menu.tscn")

var guns = [
	{"Scene": preload("res://Assets/3D/Handgun/Handgun.tscn"), "Name": "Handgun"},
	{"Scene": preload("res://Assets/3D/Rifle/Rifle.tscn"), "Name":"Rifle"}
	]

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
	["Barn", "res://Scenes/Levels/Barn/Barn.tscn", "Very Simple Zombie Map"]
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
const GROUP_BUYABLE = "Buyable"

var selected_map = 0

var max_zombies_at_a_time = 75 # Limitations due to bad FPS, from physics processing the hoard of zombies running into each other
var zombies_to_spawn_this_round = 4
var zombies_spawned_this_round = 0
var zombies_killed_this_round = 0
var zombie_round = 0
var current_zombie_health = 100

var _paused = false

var net: NetworkedMultiplayerENet = NetworkedMultiplayerENet.new()
var default_port: int = 4000
var my_peer_id = null

func is_game_paused():
	return _paused

func reset():
	get_tree().quit() # Due to a problem with GLobals Singleton Disapearing. The only "Safe" thing to do, is exit entirely
#	net.close_connection()
	safe_delete_all_players()
	max_zombies_at_a_time = 75
	zombies_to_spawn_this_round = 4
	zombies_spawned_this_round = 0
	zombies_killed_this_round = 0
	zombie_round = 0
	current_zombie_health = 100
	_paused = false
#	net = NetworkedMultiplayerENet.new()
#	get_tree().network_peer = net

func set_game_pause(new_state):
	rpc("_set_game_pause", new_state)

remotesync func _set_game_pause(new_state):
	_paused=new_state
	emit_signal("game_pause_state_changed", _paused)
	


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

class Player:
	var Name: String = "Unnamed"
	var ID: String = "No ID"
	var Body: KinematicBody = null
	var Eyes: Camera = null
	var Destroyable = null
	var Player_Control = null
	var Kill_Count: int = 0
	var max_health: int = 100
