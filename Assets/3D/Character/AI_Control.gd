extends Node

export (NodePath) var Body_Node
export (NodePath) var Navigation_Node

export var fall_acceleration = 75

export var speed = 13

export var attack_dammage = 50

var body: KinematicBody = null
var velocity = Vector3.ZERO

var nav = null
var path = []
var path_node = 0

var target: Spatial = null

var pathing_timer = null

var attack_timer = null

func _ready():
	body = get_node(Body_Node)
	
	nav = get_node(Navigation_Node)
	
	pathing_timer = Timer.new()
	pathing_timer.wait_time = .3
	pathing_timer.connect("timeout", self, "_pathing_timeout")
	add_child(pathing_timer)
	pathing_timer.start()
	
	attack_timer = Timer.new()
	attack_timer.wait_time = 1
	attack_timer.connect("timeout", self, "_attack_timeout")
	add_child(attack_timer)
	attack_timer.start()


func _physics_process(delta):
	if Globals.is_game_paused():
		pass
	else:
		if path_node < path.size():
			var direction = (path[path_node] - body.global_transform.origin)

			direction.y -= fall_acceleration * delta

			if direction.length() < 1:
				path_node += 1
			else:
				body.move_and_slide(direction.normalized() * speed, Vector3.UP)

		if target != null:
			if is_instance_valid(target):
				body.look_at(target.global_transform.origin, Vector3.UP)
			else:
				target = null

func get_path_to_target(target_pos):
	path = nav.get_simple_path(body.global_transform.origin, target_pos)
	path_node = 0

func _pathing_timeout():
	if Globals.is_game_paused():
		return

	if target != null and is_instance_valid(target):
		get_path_to_target(target.global_transform.origin)

func _attack_timeout():
	if Globals.is_game_paused():
		return
	if target != null and is_instance_valid(target) and target.is_in_group("destroyable"):
		var distance = body.global_transform.origin.distance_to(target.global_transform.origin)
		if distance < 1:
			var info = target.get_node("destroyable")
			info.change_health_by(-attack_dammage)
