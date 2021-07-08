extends Node

onready var zombie_skin = preload("res://Assets/3D/Character/Material_Green.material")

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

var retarget_timer = null

func _ready():
	body = get_node(Body_Node)
	if not body.is_in_group(Globals.GROUP_ENEMIES):
		body.add_to_group(Globals.GROUP_ENEMIES)
	
	nav = get_node(Navigation_Node)
	
	body.get_node("blockhead_character/Skeleton/body").set_surface_material(0, zombie_skin)
	
	if not get_tree().is_network_server():
		return
	
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
	
	retarget_timer = Timer.new()
	retarget_timer.name = "Retarget_Timer"
	retarget_timer.wait_time = 2
	retarget_timer.connect("timeout", self, "_retarget_timer_timeout")
	add_child(retarget_timer)
	retarget_timer.start()


func _physics_process(delta):
	if Globals.is_game_paused() or not get_tree().is_network_server():
		pass
	else:
		if path_node < path.size():
			var direction = (path[path_node] - body.global_transform.origin)

			direction.y -= fall_acceleration * delta

			if direction.length() < 1:
				path_node += 1
			else:
				body.move_and_slide(direction.normalized() * speed, Vector3.UP)
				rpc_unreliable("_client_set_position", body.global_transform.origin)

		if target != null:
			if is_instance_valid(target):
				body.look_at(target.global_transform.origin, Vector3.UP)
			else:
				target = null

func get_path_to_target(target_pos):
	path = nav.get_simple_path(body.global_transform.origin, target_pos)
	path_node = 0

remotesync func set_target(new_target:NodePath):
	target = get_node(new_target)

func _pathing_timeout():
	if Globals.is_game_paused():
		return

	if target != null and is_instance_valid(target) and not target.get_node("destroyable").is_dead:
		get_path_to_target(target.global_transform.origin)
	else:
		if target != null:
			rset("target", null)
			
		var closest = _get_closest_player()
		
		if closest != null:
			rpc("set_target", closest.Body.get_path())

func _attack_timeout():
	if Globals.is_game_paused():
		return
	if target != null and is_instance_valid(target) and target.is_in_group(Globals.GROUP_DESTROYABLE):
		var distance = body.global_transform.origin.distance_to(target.global_transform.origin)
		if distance < 1:
			var info = target.get_node("destroyable")
			info.change_health_by(-attack_dammage)

remote func _client_set_position(pos):
	body.global_transform.origin = pos
	
	if target != null:
		if is_instance_valid(target):
			body.look_at(target.global_transform.origin, Vector3.UP)
		else:
			target = null
	
func _retarget_timer_timeout():
	var c = _get_closest_player()
	if not is_instance_valid(target):
		set_target("/")

	if c != null:
		if target == null or target.name != c.ID:
			set_target(c.Body.get_path())

func _get_closest_player():
	var closest = null
	for p in Globals.players:
		if not p.Destroyable.is_dead and p.Body.visible == true and ( closest == null or
		 closest.Body.global_transform.origin.distance_to(body.global_transform.origin) > p.Body.global_transform.origin.distance_to(body.global_transform.origin)):
			closest = p
	return closest
