extends Node

onready var character = preload("res://Assets/3D/Character/character.tscn")
onready var player_control = preload("res://Assets/3D/Character/Player_Controls.gd")
onready var ai_control = preload("res://Assets/3D/Character/AI_Control.gd")
onready var handgun = preload("res://Assets/3D/Handgun/Handgun.tscn")

export (NodePath) var Spawners_Node

var spawners_enemies = []
var spawners_players = []
var spawned_enemies_node: Node

var spawn_timer: Timer = null
var round_timer: Timer = null

func _ready():
	var tmp = get_node(Spawners_Node)
	
	spawners_enemies = tmp.get_node("enemies").get_children()
	spawners_players = tmp.get_node("players").get_children()
	
	spawned_enemies_node = Spatial.new()
	spawned_enemies_node.name = "spawned_enemies"
	add_child(spawned_enemies_node)
	
	var np = character.instance()
	
	var s = Node.new()
	np.add_child(s)
	s.set_script(player_control)
	s.Eyes_Node = "../Camera"
	s.Body_Node = ".."
	var gun = handgun.instance()
	np.get_node("Camera/weapon_location").add_child(gun)
	s.Weapon = gun
	
	np.transform = spawners_players[0].transform
	Globals.players[0][1] = np
	Globals.players[0][2] = s.Eyes
	add_child(np)
#
	spawn_timer = Timer.new()
	spawn_timer.wait_time = .5
	add_child(spawn_timer)
	
#	spawn_timer.start()
	spawn_timer.connect("timeout", self, "spawn_timer_timeout")
	
	round_timer = Timer.new()
	round_timer.wait_time = 5
	round_timer.one_shot = true
	add_child(round_timer)
	round_timer.start()

	round_timer.connect("timeout", self, "round_timer_timeout")
	
	Globals.connect("game_pause_state_changed", self, "_on_game_pause_state_changed")

func on_zomb_death():
	Globals.zombies_killed_this_round += 1
	print("Left:   ", Globals.zombies_to_spawn_this_round - Globals.zombies_killed_this_round)
	print("Killed: ", Globals.zombies_killed_this_round)
	print()
	
	if Globals.zombies_killed_this_round >= Globals.zombies_to_spawn_this_round:
		round_timer.start()

func spawn_zombie(at: Vector3, target: Spatial):
	var np = character.instance()
	var s = Node.new()
	np.add_child(s)
	s.set_script(ai_control)
	s.Body_Node = ".."
	s.Navigation_Node = "../../../../Navigation"
	s.target=target
	s.speed = rand_range(3,14)
	var des = np.get_node("destroyable")
	des.health = Globals.current_zombie_health
	des.connect("on_death", self, "on_zomb_death")
	np.global_transform.origin = at
	spawned_enemies_node.add_child(np)
	Globals.zombies_spawned_this_round += 1

func round_timer_timeout():
	Globals.zombie_round += 1
	Globals.zombies_killed_this_round = 0
	Globals.zombies_spawned_this_round = 0
	if Globals.zombie_round > 1:
		Globals.current_zombie_health = round(Globals.current_zombie_health * 1.3)
		Globals.zombies_to_spawn_this_round = round(max(Globals.zombies_to_spawn_this_round, 1) * 1.2)
	print("Round Start: ", Globals.zombie_round)
	print("To Spawn: ", Globals.zombies_to_spawn_this_round)
	print("Zomb Health: ", Globals.current_zombie_health)
	print()
	spawn_timer.start()

func spawn_timer_timeout():
	if Globals.is_game_paused():
		return
	
	for i in range(0, spawners_enemies.size()):
		if Globals.zombies_spawned_this_round >= Globals.zombies_to_spawn_this_round:
			spawn_timer.stop()
			break
		if spawners_enemies.size() >= Globals.max_zombies_at_a_time:
			break
		spawn_zombie(spawners_enemies[rand_range(0, spawners_enemies.size())].global_transform.origin,Globals.players[0][1])

func _on_game_pause_state_changed(paused):
	self.round_timer.paused = paused
	self.spawn_timer.paused = paused
