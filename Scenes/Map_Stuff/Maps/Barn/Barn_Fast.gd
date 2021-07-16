extends Spatial

func _ready():
	$Level_Barn/Simple_Round_Logic.override_player_speed = 14
	$Level_Barn/Simple_Round_Logic.override_enemy_max_speed = 13
		
	for p in $Level_Barn/Simple_Round_Logic/Spawned_Players.get_children():
		p.get_node("Player_Controller").Speed=14
