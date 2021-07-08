extends Node

export (NodePath) var Eyes_Node
export (NodePath) var Body_Node

#onready var shader_fix = preload("res://good to know/compile_shader_fix.tscn")
onready var simple_hud = preload("res://Assets/2D/Simple_Hud/Simple_Hud.tscn")

# How fast the player moves in meters per second.
export var speed = 14
# The downward acceleration when in the air, in meters per second squared.
export var fall_acceleration = 75

var Points = 0
func set_points(new_value):
	rpc("_set_points", new_value)
	return Points
	
remotesync func _set_points(new_value):
	Points = new_value

var Eyes = null
var Body = null
var Weapon:Node = null
var Destroyable:Node = null
var Hud: Control = null

var velocity = Vector3.ZERO

var mouse_sensitivity = 0.1

func set_visibility(value):
	rpc("_set_visibility", value)

remotesync func _set_visibility(value):
	Body.visible=value

func _ready():
	# TODO: Move set_mouse_mode to code where scene is loaded, instead of character _ready
	Eyes = get_node(Eyes_Node)
	Body = get_node(Body_Node)
	Eyes.visible=true
#	Eyes.add_child(shader_fix.instance())
	if not Body.is_in_group(Globals.GROUP_PLAYERS):
		Body.add_to_group(Globals.GROUP_PLAYERS)
	Destroyable = Body.get_node("destroyable")
	Destroyable.delete_on_death=false
	
	if Body.is_network_master():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		Hud = simple_hud.instance()
		Hud.player_controller = self
		Hud.destroyable = Destroyable
		Hud.name = "HUD"
		Eyes.add_child(Hud)
		Hud.destroyable.connect("on_death", self, "_on_death")
		
		_connect_weapon_signals()

func _connect_weapon_signals():
	if Weapon != null:
		Weapon.connect("on_hit", self, "on_hit")
		Weapon.connect("on_kill", self, "on_kill")

func on_hit(spatial_hit, spatial_from):
	if spatial_hit.is_in_group(Globals.GROUP_ENEMIES):
		set_points(Points + 10)
	elif spatial_hit.is_in_group(Globals.GROUP_BUYABLE):
		if Weapon == null or Weapon.Weapon_Name != spatial_hit.get_parent().Gun_Name:
			var seller = spatial_hit.get_parent()
			if seller.Price <= Points:
				set_gun(Globals.get_gun_index_by_name(seller.Gun_Name))
				set_points(Points - seller.Price)

func on_kill(spatial_hit, spatial_from):
	if spatial_hit.is_in_group(Globals.GROUP_ENEMIES):
		set_points(Points + 100)

func _input(event):
	if Body.is_network_master():
		if Globals.is_game_paused() or Destroyable.is_dead:
			return
		if event is InputEventMouseMotion:
			Body.rotation_degrees.y -= event.relative.x * mouse_sensitivity
			Eyes.rotation_degrees.x = clamp(Eyes.rotation_degrees.x - event.relative.y * mouse_sensitivity, -90, 90)
			rpc_unreliable("_client_set_rotation", Body.rotation_degrees, Eyes.rotation_degrees)
		
	#	if event is InputEventKey:
	#		if Input.is_action_just_released("ui_end"):
	#			get_tree().quit()
	#		elif Input.is_action_just_released("ui_cancel"):
	#			if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
	#				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	#				Globals.set_game_pause(true)
	#			else:
	#				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	#				Globals.set_game_pause(false)
		
		if event is InputEventMouseButton:
			if Weapon != null:
				if Input.is_action_pressed("shoot"):
					Weapon.trigger_pulled()
				elif Input.is_action_just_released("shoot"):
					Weapon.trigger_released()
		elif event is InputEventKey:
			if Weapon != null:
				if Input.is_action_just_pressed("reload"):
					Weapon.reload()

func _physics_process(delta):
	if Body.is_network_master():
		if Globals.is_game_paused() or Destroyable.is_dead:
			return

		var direction = Vector2.ZERO
		if Input.is_action_pressed("move_right"):
			direction.y += 1
		if Input.is_action_pressed("move_left"):
			direction.y -= 1
		if Input.is_action_pressed("move_back"):
			direction.x -= 1
		if Input.is_action_pressed("move_forward"):
			direction.x += 1

		# Turning
		direction = direction.normalized().rotated(-Body.rotation.y)
		
		velocity.x = direction.x * speed
		velocity.z = direction.y * speed
		velocity.y -= fall_acceleration * delta
		
		velocity = Body.move_and_slide(velocity, Vector3.UP)
		rpc_unreliable("_client_set_position", Body.global_transform.origin)
	
func _on_death():
#	Body.hide()
	set_visibility(false)
#	Globals.set_game_pause(true)
#	get_tree().change_scene("res://Scenes/main_menu/main_menu.tscn")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

remote func _client_set_position(pos):
	Body.global_transform.origin = pos
	
remote func _client_set_rotation(body_rot, eyes_rot):
	Body.rotation_degrees = body_rot
	Eyes.rotation_degrees = eyes_rot

func set_gun(gun_index: int):
	rpc("_set_gun", gun_index)

remotesync func _set_gun(gun_index: int):
	var g:Spatial = Globals.guns[gun_index].Scene.instance()
	g.set_network_master(get_network_master())
	g.actor = get_parent().get_path()
	var wl = get_node("../Camera/weapon_location")
	
	if wl.get_child_count() > 0:
		wl.remove_child(wl.get_child(0))
	
	if gun_index < 0:
		return
	
	Weapon = g
	wl.add_child(g)
	g.set_display_nodes("../../HUD/ammo_display/lbl_total_ammo_number", "../../HUD/ammo_display/lbl_clip_number")
	if Body.is_network_master():
		_connect_weapon_signals()
