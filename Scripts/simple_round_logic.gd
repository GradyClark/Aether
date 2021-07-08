extends Node

onready var ai_control = preload("res://Assets/3D/Character/AI_Control.gd")
onready var character = preload("res://Assets/3D/Character/character.tscn")

export (NodePath) var Spawners_Node

var spawners_enemies = []
var spawners_players = []
var spawned_enemies_node: Node
var spawned_players_node: Node

var spawn_timer: Timer = null
var round_timer: Timer = null

func _ready():
	var tmp = get_node(Spawners_Node)
	
	spawners_enemies = tmp.get_node("enemies").get_children()
	spawners_players = tmp.get_node("players").get_children()
	
	spawned_enemies_node = Spatial.new()
	spawned_enemies_node.name = "spawned_enemies"
	add_child(spawned_enemies_node)
	
	spawned_players_node = Spatial.new()
	spawned_players_node.name = "spawned_players"
	add_child(spawned_players_node)
	
	
	if not get_tree().is_network_server():
		return
	else:
		spawn_players()
	
#	var np = character.instance()
#
#	var s = Node.new()
#	np.add_child(s)
#	s.set_script(player_control)
#	s.Eyes_Node = "../Camera"
#	s.Body_Node = ".."
#	var gun = handgun.instance()
#	np.get_node("Camera/weapon_location").add_child(gun)
#	s.Weapon = gun
#
#	np.transform = spawners_players[0].transform
#	Globals.players[0][1] = np
#	Globals.players[0][2] = s.Eyes
#	add_child(np)
#
	spawn_timer = Timer.new()
	spawn_timer.wait_time = .5
	spawn_timer.name="spawn timer"
	add_child(spawn_timer)
	
#	spawn_timer.start()
	spawn_timer.connect("timeout", self, "spawn_timer_timeout")
	
	round_timer = Timer.new()
	round_timer.wait_time = 5
	round_timer.one_shot = true
	round_timer.name="round timer"
	add_child(round_timer)
	round_timer.start()

	round_timer.connect("timeout", self, "round_timer_timeout")
	
	Globals.connect("game_pause_state_changed", self, "_on_game_pause_state_changed")
	Globals.set_network_master(1)
	

func on_zomb_death():
#	Globals.zombies_killed_this_round += 1
	Globals.set_zombies_killed_this_round(Globals.zombies_killed_this_round+1)
	
	if Globals.zombies_killed_this_round >= Globals.zombies_to_spawn_this_round:
		round_timer.start()

func server_spawn_zombie():
	rpc("spawn_zombie",
	spawners_enemies[rand_range(0, spawners_enemies.size())].global_transform.origin,
	rand_range(3,14),
	"zombie_" + str(Globals.zombies_spawned_this_round))

remotesync func spawn_zombie(at: Vector3, speed, name):
	var np = character.instance()
	var s = Node.new()
	np.add_child(s)
	s.name = "AI_Controller"
	s.set_script(ai_control)
	s.Body_Node = ".."
	s.Navigation_Node = "../../../../Navigation"
	s.speed = speed
	var des = np.get_node("destroyable")
	des.health = Globals.current_zombie_health
	if get_tree().is_network_server():
		des.connect("on_death", self, "on_zomb_death")
	np.global_transform.origin = at
	np.name = name
	spawned_enemies_node.add_child(np)
#	Globals.zombies_spawned_this_round += 1
	Globals.set_zombies_spawned_this_round(Globals.zombies_spawned_this_round + 1)
	return np

func round_timer_timeout():
#	Globals.rset("zombie_round", Globals.zombie_round + 1)
	Globals.set_round(Globals.zombie_round + 1)
	Globals.set_zombies_killed_this_round(0)
	Globals.set_zombies_spawned_this_round(0)


#	Globals.zombie_round += 1
#	Globals.zombies_killed_this_round = 0
#	Globals.zombies_spawned_this_round = 0
	if Globals.zombie_round > 1:
		Globals.set_current_zombie_health(round(Globals.current_zombie_health * 1.3))
		Globals.set_zombies_to_spawn_this_round(round(max(Globals.zombies_to_spawn_this_round, 1) * 1.2))
	spawn_timer.start()
	
	rpc("spawn_players")

func spawn_timer_timeout():
	if Globals.is_game_paused():
		return
	
	for i in range(0, spawners_enemies.size()):
		if Globals.zombies_spawned_this_round >= Globals.zombies_to_spawn_this_round:
			spawn_timer.stop()
			break
		if spawners_enemies.size() >= Globals.max_zombies_at_a_time:
			break
		server_spawn_zombie()

func _on_game_pause_state_changed(paused):
	self.round_timer.paused = paused
	self.spawn_timer.paused = paused

remotesync func spawn_players():
	for i in range(Globals.players.size()):
		var p = spawned_players_node.get_node(Globals.players[i].ID)
		if  p == null:
			Globals.players[i].Body.transform = spawners_players[0].transform
			spawned_players_node.add_child(Globals.players[i].Body)
		elif Globals.players[i].Destroyable.is_dead:
			Globals.players[i].Body.transform = spawners_players[0].transform
			Globals.players[i].Body.get_node("Player Controls").set_gun(0)
			Globals.players[i].Player_Control.set_visibility(true)

		Globals.players[i].Destroyable.set_health(Globals.players[i].max_health)
		if Globals.players[i].Player_Control.Weapon == null:
			Globals.players[i].Player_Control.set_gun(0)
