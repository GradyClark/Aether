extends Node

signal on_death()
signal on_health_change(old_health, new_health, destroyable_node)
signal on_resurrect()
signal on_start_bleeding_out()
signal on_revived()


export (int) var health = 100

export (bool) var is_dead = false

export (bool) var delete_on_death = true
export (int) var delete_delay = 0

export (bool) var Regen = false
export (float) var Regen_Per_Secound = 0
export (float) var Damage_Delays_Regen_By_secounds = 0.1
export (float) var Max_Regen = 100

export (int) var bleedout_max = 60 # reach this, and you die
export (int) var bleedout_heal = 5 # per secound
export (int) var bleedout_by = 1 # every secound in bleedout subtract this from health
export (bool) var is_bleeding_out = false
export (float) var bleedout = 0
var is_reviving: bool = false

export (NodePath) var parent = null


var bounds_timer: Timer = null

var SID = "Revivable"
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
	$Regen_Delayed_Timer.wait_time = Damage_Delays_Regen_By_secounds
	
	_on_health_change(health, health)
	if parent != null:
		parent = get_node(parent)
	
	if parent == null:
		parent = get_parent()
	
	if !parent.is_in_group(Globals.GROUP_DESTROYABLE):
		parent.add_to_group(Globals.GROUP_DESTROYABLE)
		
	if !parent.is_in_group(Globals.GROUP_REVIVABLE):
		parent.add_to_group(Globals.GROUP_REVIVABLE)
		
	if get_tree().is_network_server():
		bounds_timer = Timer.new()
		bounds_timer.wait_time = 1
		bounds_timer.name = "bounds_timer"
		bounds_timer.connect("timeout", self, "_bounds_timer_timeout")
		add_child(bounds_timer)
		bounds_timer.start()


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
	if parent != null and parent.global_transform.origin.y < -20 and health > 0:
		set_health(-666)

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


remotesync func Start_Reviving():
	if is_reviving:
		return
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
	if bleedout - bleedout_heal <= 0:
		rpc("Revive", Max_Regen)
	else:
		set_bleedout(bleedout - bleedout_heal)
		if is_bleeding_out:
			$Revive_Timer.start()

func set_max_health(new_max_health: int, update_health: bool = true):
	rpc("_set_max_health", new_max_health, update_health)
	
remotesync func _set_max_health(new_max_health: int, update_health: bool):
	Max_Regen = new_max_health
	if update_health:
		_set_health(Max_Regen)
