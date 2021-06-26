extends Node

export (int) var health = 100

export (bool) var is_dead = false

export (bool) var delete_on_death = true
export (int) var delete_delay = 0

export (NodePath) var parent = null

signal on_death()

signal on_health_change(old_health, new_health, destroyable_node)

# TO USE THIS SCRIPT (OUTDATED INSTRUCTIONS)
# Add the Parent Node that you want to be destroyable, to the destroyable group
# Then add this "destroyable" "Node" to the Parent Node, make sure it's name is "destroyable"

# When this "destroyable" dies, it will delete it's parent, if the "delete_on_death" is set to true

# NEW INSTRUCTIONS
# add this node, then connect the "parent" variable to the top most node of the scene
# or just place this node as a Direct Child, of the parent node you want to be destroyable
# Add the parent node to the group "destroyable", or don't, this script will do it automatically
#

func _ready():
	_on_health_change(health, health)
	if parent != null:
		parent = get_node(parent)
	
	if parent == null:
		parent = get_parent()
	
	if !parent.is_in_group("destroyable"):
		parent.add_to_group("destroyable")

func set_health(new_health: int):
	var old = health
	health = new_health
	_on_health_change(old, health)
	
func change_health_by(amount: int):
	var old = health
	health += amount
	_on_health_change(old, health)

func _on_health_change(old_health: int, new_health: int):
	emit_signal("on_health_change", old_health, new_health, self)
	if health <= 0:
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

func _delete():
	if is_instance_valid(parent):
		get_parent().queue_free()
