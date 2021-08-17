extends "res://Scenes/Game_Logic/Weapon/Weapon.gd"

export (NodePath) var Node_Spread_Hitbox
var _Node_Spread_Hitbox: Area

func _ready():
	_Node_Spread_Hitbox = get_node(Node_Spread_Hitbox)

func custom_process(delta:float):
	hits.clear()
	var hs = _Node_Spread_Hitbox.get_overlapping_bodies()
	for h in hs:
		hits.append([h])
