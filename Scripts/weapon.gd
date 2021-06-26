extends Node

export (float) var weapon_damage
export (Vector3) var weapon_range
export (NodePath) var weapon_raycast_node

var _weapon_raycast: RayCast

func _ready():
	_weapon_raycast = get_node(weapon_raycast_node)
	_weapon_raycast.cast_to = weapon_range

func shoot():
	var target = _weapon_raycast.get_collider()
	if target != null and target.is_in_group("destroyable"):
		var info = target.get_node("destroyable")
		info.change_health_by(-weapon_damage)
