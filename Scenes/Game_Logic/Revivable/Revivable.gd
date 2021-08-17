extends "res://Scenes/Game_Logic/Destroyable/Destroyable.gd"

signal on_start_bleeding_out()
signal on_revived()

export (int) var bleedout_max = 60 # reach this, and you die
export (int) var bleedout_heal = 5 # per secound
export (int) var bleedout_by = 1 # every secound in bleedout subtract this from health
export (bool) var is_bleeding_out = false
export (float) var bleedout = 0
var is_reviving: bool = false

var _override_bleedout_heal:int = 0

func _init():
	SID = "Revivable"


func serialize():
	return {"SID": SID}


func deserialize(data):
	pass

# TO USE THIS SCRIPT (OUTDATED INSTRUCTIONS)
# Add the Parent Node that you want to be destroyable, to the destroyable group
# Then add this "destroyable" "Node" to the Parent Node, make sure it's name is "Destroyable"

# When this "destroyable" dies, it will delete it's parent, if the "delete_on_death" is set to true

# NEW INSTRUCTIONS
# add this node, then connect the "parent" variable to the top most node of the scene
# or just place this node as a Direct Child, of the parent node you want to be destroyable
# Add the parent node to the group "destroyable", or don't, this script will do it automatically
#

func _ready():
	if !parent.is_in_group(Globals.GROUP_REVIVABLE):
		parent.add_to_group(Globals.GROUP_REVIVABLE)


remotesync func set_death(new_val):
	is_dead = new_val
	if is_dead:
		emit_signal("on_death")


func set_health(new_health: int):
	rpc("_set_health", new_health)


remotesync func _set_health(new_health: int):
	var old = health
	health = new_health
	_on_health_change(old, health)


func change_health_by(amount: int):
	rpc("_change_health_by", amount)
	return health


remotesync func _change_health_by(amount: int):
	var old = health
	health += amount
	_on_health_change(old, health)


remotesync func _set_bleedout(new_val, stop_bleeding: bool = false):
	bleedout = new_val
	if stop_bleeding:
		is_bleeding_out = false


func set_bleedout(new_val, stop_bleeding: bool = false):
	rpc("_set_bleedout", new_val, stop_bleeding)


func _on_health_change(old_health: int, new_health: int):
	emit_signal("on_health_change", old_health, new_health, self)
	
	var out_of_bounds = false
	
	if parent != null and typeof(parent) != typeof(NodePath()) and parent.global_transform.origin.y < -20:
		out_of_bounds = true
	
	if health <= 0:
		if not is_dead:
			if out_of_bounds:
				rpc("set_death", true)
			else:
				if not is_bleeding_out:
					bleedout = 0
					is_bleeding_out = true
					emit_signal("on_start_bleeding_out")
					if Networking.is_server():
						$Bleedout_Timer.start()

	if new_health < old_health and is_network_master() and Regen and not is_dead and not is_bleeding_out:
		$Regen_Timer.stop()
		$Regen_Delayed_Timer.stop()
		$Regen_Delayed_Timer.start()

func _bounds_timer_timeout():
	if parent != null and parent.global_transform.origin.y < -20:
		if health > 0:
			set_health(-666)
		else:
			set_bleedout(bleedout_max, true)

func _delete():
	if is_instance_valid(parent):
		get_parent().queue_free()


func _on_Regen_Timer_timeout():
	if is_dead or is_bleeding_out:
		$Regen_Timer.stop()
		$Regen_Delayed_Timer.stop()
		return
	
	if Regen:
		var h = health + Regen_Per_Secound
		if h > Max_Regen:
			h = Max_Regen
		
		if h != health:
			set_health(h)
	$Regen_Timer.stop()
	$Regen_Timer.start()


func _on_Regen_Delayed_Timer_timeout():
	if is_dead or is_bleeding_out:
		$Regen_Timer.stop()
		$Regen_Delayed_Timer.stop()
		return
		
	if Regen:
		_on_Regen_Timer_timeout()
	$Regen_Timer.start()
	$Regen_Delayed_Timer.stop()


func _on_Bleedout_Timer_timeout():
	if bleedout < bleedout_max:
		set_bleedout(bleedout + bleedout_by)
		if Networking.is_server():
			$Bleedout_Timer.start()
	elif not is_dead:
		rpc("set_death", true)


remotesync func Resurrect(new_health):
	if new_health > 0 and (is_dead or is_bleeding_out):
		is_dead = false
		is_bleeding_out = false
		_set_health(new_health)
		emit_signal("on_resurrect", new_health)


remotesync func Revive(new_health):
	if new_health > 0 and not is_dead and is_bleeding_out:
		$Bleedout_Timer.stop()
		is_bleeding_out = false
		bleedout = 0
		_set_health(new_health)
		emit_signal("on_revived", new_health)
	is_reviving = false


remotesync func Start_Reviving(override_bleadout_heal:int = 0):
	if is_reviving:
		return
	
	_override_bleedout_heal = override_bleadout_heal
	
	if Networking.is_server():
		$Bleedout_Timer.stop()
		$Revive_Timer.start()
	is_reviving = true


remotesync func Stop_Reviving():
	if not is_reviving:
		return
	if Networking.is_server() and is_bleeding_out:
		$Revive_Timer.stop()
		$Bleedout_Timer.start()
	is_reviving = false


func _on_Revive_Timer_timeout():
	var heal = bleedout_heal
	if _override_bleedout_heal > 0:
		heal = _override_bleedout_heal
	if bleedout - heal <= 0:
		rpc("Revive", Max_Regen)
	else:
		set_bleedout(bleedout - heal)
		if is_bleeding_out:
			$Revive_Timer.start()

func set_max_health(new_max_health: int, update_health: bool = true):
	if is_inside_tree():
		rpc("_set_max_health", new_max_health, update_health)
	else:
		_set_max_health(new_max_health, update_health)
	
remotesync func _set_max_health(new_max_health: int, update_health: bool):
	Max_Regen = new_max_health
	if update_health:
		_set_health(Max_Regen)
