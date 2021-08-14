extends Node

signal on_death()
signal on_health_change(old_health, new_health, destroyable_node)
signal on_resurrect(new_health)


export (int) var health = 100

export (bool) var is_dead = false

export (bool) var delete_on_death = true
export (int) var delete_delay = 0

export (bool) var Regen = false
export (float) var Regen_Per_Secound = 0
export (float) var Damage_Delays_Regen_By_secounds = 0.1
export (float) var Max_Regen = 100

export (float) var Absorption = 1

export (NodePath) var parent = null


var bounds_timer: Timer = null

var SID = "Destroyable"
func serialize():
	return {"SID": SID, "health": health, "absorption": Absorption}

func deserialize(data):
	health = data.health
	Absorption = data.absorption

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
		
	if Networking.is_server():
		bounds_timer = Timer.new()
		bounds_timer.wait_time = 1
		bounds_timer.name = "bounds_timer"
		bounds_timer.connect("timeout", self, "_bounds_timer_timeout")
		add_child(bounds_timer)
		bounds_timer.start()


func _exit_tree():
	_disconnect_incoming_signals()
	_disconnect_outgoing_signals()


func _disconnect_incoming_signals():
	if bounds_timer != null:
		bounds_timer.disconnect("timeout", self, "_bounds_timer_timeout")


func _disconnect_outgoing_signals():
	Globals.universal_disconnect_helper(self, ["on_death", "on_health_change", "on_resurrect"])


func set_health(new_health: int):
	rpc("_set_health", new_health)


func set_max_health(new_max_health: int, update_health: bool = true):
	rpc("_set_max_health", new_max_health, update_health)


remotesync func _set_max_health(new_max_health: int, update_health: bool):
	Max_Regen = new_max_health
	if update_health:
		_set_health(Max_Regen)


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


func _on_health_change(old_health: int, new_health: int):
	emit_signal("on_health_change", old_health, new_health, self)
	if health <= 0 and not is_dead:
		is_dead = true
		emit_signal("on_death")
		if delete_on_death:
			if self.delete_delay == 0:
				_delete()
			else:
				var t = Timer.new()
				t.wait_time = delete_delay
				t.connect("timeout", self, "_delete")
				self.add_child(t)
				t.start()
	
	if new_health < old_health and is_network_master() and Regen:
		$Regen_Timer.stop()
		$Regen_Delayed_Timer.stop()
		$Regen_Delayed_Timer.start()


remotesync func Resurrect(new_health):
	if new_health > 0:
		is_dead = false
		_set_health(new_health)
		emit_signal("on_resurrect", new_health)


func _delete():
	if is_instance_valid(parent):
		get_parent().queue_free()


func _bounds_timer_timeout():
	if parent != null and parent.global_transform.origin.y < -20 and health > 0:
		set_health(-666)


func _on_Regen_Timer_timeout():
	if is_dead:
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
	if is_dead:
		$Regen_Timer.stop()
		$Regen_Delayed_Timer.stop()
		return
		
	if Regen:
		_on_Regen_Timer_timeout()
	$Regen_Timer.start()
	$Regen_Delayed_Timer.stop()
