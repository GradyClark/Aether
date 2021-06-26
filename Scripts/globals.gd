extends Node

signal game_pause_state_changed

var maps = [
	["Barn", "res://Scenes/Levels/Barn/Barn.tscn", "Very Simple Zombie Map"]
]

var players = [
	["Player 1",null, null]
]

var selected_map = 0

var max_zombies_at_a_time = 75 # Limitations due to bad FPS, from physics processing the hoard of zombies running into each other
var zombies_to_spawn_this_round = 4
var zombies_spawned_this_round = 0
var zombies_killed_this_round = 0
var zombie_round = 0
var current_zombie_health = 100

var _paused = false

func is_game_paused():
	return _paused

func set_game_pause(new_state):
	_paused=new_state
	emit_signal("game_pause_state_changed", _paused)
