extends Node

export (Material) var zombie_skin
export (AudioStream) var attack_sound

export (NodePath) var Body_Node
export (NodePath) var Skin_Node
export (NodePath) var Sound_Node
export (int) var weight = 1

export var speed = 1

export var attack_dammage = 34

var body: KinematicBody = null
var velocity = Vector3.ZERO

var path = []
var path_node = 0

var target: Spatial = null

func _ready():
	body = get_node(Body_Node)
	if not body.is_in_group(Globals.GROUP_ENEMIES):
		body.add_to_group(Globals.GROUP_ENEMIES)
	
	Skin_Node = get_node(Skin_Node)

	Skin_Node.set_surface_material(0, zombie_skin)
	
	Sound_Node = get_node(Sound_Node)
	
	Sound_Node.stream = attack_sound

	if not get_tree().is_network_server():
		return

	$pathing_timer.start()

	$attack_timer.start()
	
	$retarget_timer.start()


func _physics_process(delta):
	if  not get_tree().is_network_server():
		pass
	else:
		if path_node < path.size():
			var direction = (path[path_node] - body.global_transform.origin)
			
			direction.y -= Globals.gravity * weight * delta
			
			if direction.length() < 1:
				path_node += 1
			else:
#				body.move_and_slide(direction.normalized() * speed, Vector3.UP, true)
				body.move_and_slide_with_snap(direction.normalized() * speed, Vector3(0,1,0), Vector3.UP, true) # Can't jump with this
				rpc_unreliable("_client_set_position", body.global_transform.origin)
#				var a = body.global_transform.origin.angle_to(target.global_transform.origin)
#				body.rotate_x(a)

		if target != null:
			if is_instance_valid(target) and target.is_inside_tree():
				body.look_at(target.global_transform.origin, Vector3.UP)
			else:
				target = null

func get_path_to_target(target_pos):
	if Globals.Navigation_Node != null:
		path = Globals.Navigation_Node.get_simple_path(body.global_transform.origin, target_pos)
		path_node = 0

remotesync func set_target(new_target:NodePath):
	target = get_node_or_null(new_target)

func _on_pathing_timer_timeout():
	if target != null and is_instance_valid(target) and not target.get_node(Globals.GROUP_DESTROYABLE).is_dead:
		get_path_to_target(target.global_transform.origin)
	else:
		var closest = _get_closest_player()

		if closest != null and  closest.Body != null and  is_instance_valid(closest.Body) and closest.Body.is_inside_tree() and closest.Body != target:
			rpc("set_target", closest.Body.get_path())

func _on_attack_timer_timeout():
	var c = _get_closest_player()
	if c!=null and c.Body.global_transform.origin.distance_to(body.global_transform.origin) < 5:
		Sound_Node.play()
		
	if target != null and is_instance_valid(target) and target.is_in_group(Globals.GROUP_DESTROYABLE) and target.is_inside_tree():
		var distance = body.global_transform.origin.distance_to(target.global_transform.origin)
		if distance < 2:
			var info = target.get_node(Globals.GROUP_DESTROYABLE)
			info.change_health_by(-attack_dammage)

remote func _client_set_position(pos):
	body.global_transform.origin = pos

	if target != null:
		if is_instance_valid(target):
			body.look_at(target.global_transform.origin, Vector3.UP)
		else:
			target = null

func _on_retarget_timer_timeout():
	var c = _get_closest_player()
	if not is_instance_valid(target):
		set_target("")

	if c != null:
		if target == null or target.name != c.ID:
			set_target(c.Body.get_path())

func _get_closest_player():
	# Returns PLAYER (OBJECT), NOT NODE
	var closest = null
	for p in Globals.players:
		if p.Body.is_inside_tree() and not p.Destroyable.is_dead and not p.Destroyable.is_bleeding_out and p.Body.visible == true and ( closest == null or
		 closest.Body.global_transform.origin.distance_to(body.global_transform.origin) > p.Body.global_transform.origin.distance_to(body.global_transform.origin)):
			closest = p
	return closest
