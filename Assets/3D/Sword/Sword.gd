extends Spatial

export (NodePath) var Hitbox
export (NodePath) var Anim
export (int) var Dammage

func _ready():
	Hitbox = get_node(Hitbox)
	Anim = get_node(Anim)
	
