extends Node

export (NodePath) var Node_Path_Camera = null
export (NodePath) var Node_Path_Weapon_Location = null
export (NodePath) var Node_Path_Total_Ammo_Display
export (NodePath) var Node_Path_Clip_Ammo_Display

export (NodePath) var Node_Path_Eye_Raycast

export (NodePath) var Node_Path_Interaction_Display

export (NodePath) var NP_Grenade_Display

export (NodePath) var Node_Flashlight

export (float) var weight = 1
export (float) var Speed_When_Bleeding_Out = 1

var velocity = Vector3.ZERO

var _node_camera: Camera = null
var _node_weapon_location: Spatial = null
var _node_grenade_display: Node = null

var _node_eye_raycast: RayCast = null

var _node_interaction_display: RichTextLabel = null

var _node_flashlight: SpotLight

var player: Globals.Player = null

var weapons = []
var weapon = null
var trigger_pulled = false

var max_grenades = 4
var grenades = 4
var grenades_per_round = 2

var mouse_sensitivity = 0.1
var gamepad_sensitivity_vertical = 70
var gamepad_sensitivity_horizontal = 70

var disabled = false

var _interactable_selected: Spatial = null

var is_sprinting = false

var flashlight_color_yellow = Color(1, 0.87451, 0.447059)
var flashlight_color_black = Color(0, 0, 0)
var flashlight_color_redish = Color(0.807843, 0.352941, 0.152941)
var flashlight_default_angle_attenuation = 1
var flashlight_default_attenuation = 1
var flashlight_default_range = 1
var flashlight_default_angle = 1
var flashlight_default_energy = 1
var flashlight_cancel_horror = false


var SID = "Simple_Player_Controller"
func serialize():
	var data = {
		"SID": SID,
		"Weapon_Name": null,
		"max_grenades": self.max_grenades,
		"grenades": self.grenades
	}
	if weapon != null:
		data.weapon = weapon.Weapon_Name
	return data


func deserialize(data):
	if data.Weapon_Name != null:
		weapon = Globals.get_gun_by_name(data.Weapon_Name).instance()
	grenades = data.grenades
	max_grenades = data.max_grenades


func _ready():
	
	_node_grenade_display = get_node(NP_Grenade_Display)
	
	_node_flashlight = get_node(Node_Flashlight)
	
	if not player.Body.is_in_group(Globals.GROUP_PLAYERS):
		player.Body.add_to_group(Globals.GROUP_PLAYERS)
		
	if Node_Path_Camera != null:
		_node_camera = get_node(Node_Path_Camera)
		
	if Node_Path_Weapon_Location != null:
		_node_weapon_location = get_node(Node_Path_Weapon_Location)
		
	if int(player.ID) != int(Networking.my_peer_id):
		$Simple_Hud.queue_free()
		disabled = true
		return

	_node_eye_raycast = get_node(Node_Path_Eye_Raycast)
	
	_node_interaction_display = get_node(Node_Path_Interaction_Display)
	
	if player.Body.is_network_master() or int(player.ID) == int(Networking.my_peer_id):
		player.Body.set_active_camera()
		player.Destroyable.connect("on_death", self, "_on_death")
		player.Destroyable.connect("on_resurrect", self, "_on_resurrect")
	
	
	rpc("set_gun", 0)


func _input(event):
	if disabled or not Networking.is_network_connected():
		return
	if player.Body.is_network_master():
		if player.Destroyable.is_dead:
			return
			
		var turn = player.Body.rotation_degrees #.y
		var look = _node_camera.rotation_degrees #.x
		var turn_or_look = false
		
		if event is InputEventJoypadButton or event is InputEventKey:
			if event.is_action_pressed("sprint"):
				is_sprinting = true
			elif event.is_action_released("sprint"):
				is_sprinting = false
		
		if event is InputEventMouseMotion:
			turn.y -= event.relative.x * mouse_sensitivity
			look.x = clamp(_node_camera.rotation_degrees.x - event.relative.y * mouse_sensitivity, -90, 90)
			turn_or_look = true

		if turn_or_look:
			rpc_unreliable("set_rotation", turn, look)
			
		if event is InputEventMouseButton:
			if weapon != null:
				if event.is_action_pressed("shoot"):
					weapon.trigger_pulled()
					trigger_pulled = true
				elif event.is_action_released("shoot"):
					weapon.trigger_released()
					trigger_pulled = false
		elif event is InputEventKey:
			if weapon != null:
				if event.is_action_pressed("reload"):
					weapon.reload()
			if event.is_action_released("throw_grenade"):
				spawn_grenade()
			if event.is_action_pressed("interact"):
				_interact()
			if event.is_action_pressed("toggle_flashlight"):
				rpc("_set_flashlight_visibility", !_node_flashlight.visible)
		elif event is InputEventJoypadButton:
			if weapon != null:
				if event.is_action_pressed("shoot"):
					weapon.trigger_pulled()
					trigger_pulled = true
				elif event.is_action_released("shoot"):
					weapon.trigger_released()
					trigger_pulled = false
			if weapon != null:
				if event.is_action_pressed("reload"):
					weapon.reload()
			
			if event.is_action_pressed("throw_grenade"):
				spawn_grenade()
				
			if event.is_action_pressed("interact"):
				_interact()
				
			if event.is_action_pressed("toggle_flashlight"):
				rpc("_set_flashlight_visibility", !_node_flashlight.visible)


func _reset_flashlight():
	# Reset Flashlight to default values
	_node_flashlight.light_negative = false
	_node_flashlight.spot_range = 40
	_node_flashlight.spot_attenuation = 1
	_node_flashlight.spot_angle = 9
	_node_flashlight.spot_angle_attenuation = 1
	_node_flashlight.light_color = flashlight_color_yellow
	_node_flashlight.light_energy = 1
	_node_flashlight.light_indirect_energy = 1
	_node_flashlight.light_specular = 0.5

remotesync func _set_flashlight_visibility(vis:bool):
	_reset_flashlight()
	
	_node_flashlight.visible = vis
	
	if _node_flashlight.is_network_master():
		if vis:
			if $horror_flashlight_timer.is_stopped():
				$horror_flashlight_timer.start()
				flashlight_cancel_horror = false
			else:
				$horror_flashlight_timer.stop()
				$horror_flashlight_timer.start()
				flashlight_cancel_horror = false
		else:
			$horror_flashlight_timer.stop()
			flashlight_cancel_horror = true


remotesync func set_rotation(body_rotation, camera_rotation):
	player.Body.rotation_degrees = body_rotation
	_node_camera.rotation_degrees = camera_rotation


remotesync func _joy_change_by_body_rot_y(y):
	player.Body.rotation_degrees.y += y
	
remotesync func _joy_set_camera_rot_x(x):
	_node_camera.rotation_degrees.x = x
	
remotesync func _joy_smart_change_rotations(body_y,camera_x):
	if body_y != 0:
		player.Body.rotation_degrees.y += body_y
	if _node_camera.rotation_degrees.x != camera_x:
		_node_camera.rotation_degrees.x = camera_x

func _physics_process(delta):
	if disabled or not Networking.is_network_connected():
		return
	if player.Body.is_inside_tree() and player.Body.is_network_master() and not player.Destroyable.is_dead:
		var col:Node = _node_eye_raycast.get_collider()
		
		if col != null and (col.is_in_group(Globals.GROUP_BUYABLE) or col.is_in_group(Globals.GROUP_PLAYERS)):
			if col.is_in_group(Globals.GROUP_PLAYERS):
				if not col.get_node(Globals.GROUP_DESTROYABLE).is_dead:
					_interactable_selected = col
			else:
				_interactable_selected = col
		else:
			if col == null and col != _interactable_selected and _interactable_selected.is_in_group(Globals.GROUP_PLAYERS):
				_interactable_selected.get_node("Destroyable").rpc("Stop_Reviving")
			_interactable_selected = null
			
		var body_rot = (Input.get_action_strength("turn_left") - Input.get_action_strength("turn_right")) * gamepad_sensitivity_horizontal * delta
		var camera_rot = clamp(_node_camera.rotation_degrees.x - ((Input.get_action_strength("look_down") - Input.get_action_strength("look_up")) * gamepad_sensitivity_vertical * delta), -90, 90)
		
		if body_rot != 0 or camera_rot != 0:
			 rpc_unreliable("_joy_smart_change_rotations", body_rot, camera_rot)
		
		var direction = Vector2.ZERO
		
		if Input.is_action_pressed("move_right"):
			direction.y = 1
		if Input.is_action_pressed("move_left"):
			direction.y = -1
		if Input.is_action_pressed("move_back"):
			direction.x = -1
		if Input.is_action_pressed("move_forward"):
			direction.x = 1
		
		if Input.is_action_pressed("joy_move_right"):
			direction.y = abs(Input.get_action_strength("joy_move_right"))
		if Input.is_action_pressed("joy_move_left"):
			direction.y = -abs(Input.get_action_strength("joy_move_left"))
		if Input.is_action_pressed("joy_move_back"):
			direction.x = -abs(Input.get_action_strength("joy_move_back"))
		if Input.is_action_pressed("joy_move_forward"):
			direction.x = abs(Input.get_action_strength("joy_move_forward"))

		# Turning
#		direction = direction.normalized().rotated(-player.Body.rotation.y)
		direction = direction.rotated(-player.Body.rotation.y)

		var speed = player.Speed
		
		
		if player.Destroyable.is_bleeding_out:
			speed = Speed_When_Bleeding_Out
		elif is_sprinting:
			
			player.Stamina = max(player.Stamina - player.Stamina_Drain * delta, 0)
			
			if player.Stamina > 0:
				speed *= player.Sprint_Bonus

		if not is_sprinting:
			player.Stamina = min(player.Stamina + player.Stamina_Regen * delta, player.Max_Stamina)

		velocity.z = direction.y * speed
		velocity.x = direction.x * speed
		
		velocity.y -= Globals.gravity * weight * delta

		velocity = player.Body.move_and_slide(velocity, Vector3.UP, true)
#		velocity = player.Body.move_and_slide_with_snap(velocity, Vector3(0,1,0), Vector3.UP, true)
#		velocity = player.Body.move_and_slide_with_snap(velocity, player.Body.get_floor_normal(), Vector3.UP, true)
		rpc_unreliable("set_position", player.Body.global_transform.origin)


remotesync func set_position(new_position):
	player.Body.global_transform.origin = new_position


remotesync func set_visibility(val: bool):
	player.Body.visible = val


func _on_death():
	rpc("set_visibility", false)
	if trigger_pulled:
		weapon.trigger_released()
		trigger_pulled=false

	while player.Perks.size() > 0:
		player.remove_perk(0)
		

func _on_resurrect(new_health):
	rpc("set_visibility", true)

remotesync func set_gun(gun_index: int):
	if _node_weapon_location == null:
		return
	
	var g:Spatial = Globals.guns[gun_index].Scene.instance()
	g.set_network_master(get_network_master())
	g.actor = player.Body.get_path()

	while _node_weapon_location.get_child_count() > 0:
		_node_weapon_location.remove_child(_node_weapon_location.get_child(0))

	if gun_index < 0:
		return

	weapon = g
	_node_weapon_location.add_child(g)
	if is_network_master():
		g.set_display_nodes(get_node(Node_Path_Total_Ammo_Display).get_path(), get_node(Node_Path_Clip_Ammo_Display).get_path())
	if player.Body.is_network_master():
		_connect_weapon_signals()
		pass

func _interact(interactable: Spatial = _interactable_selected):
	if interactable != null:
		if interactable.is_in_group(Globals.GROUP_BUYABLE):
			if interactable.Price <= player.Points:
				if interactable.Product_Type == Globals.Product_Types.gun:
					if interactable.Product_ID == weapon.Weapon_Name:
						weapon.rpc("set_ammo",weapon.ammo_in_clip,min(weapon.max_total_ammo,weapon.total_ammo+interactable.Ammo_Amount))
						Globals.player_set_points(player.ID, player.Points - interactable.Price_Ammo)
					else:
						rpc("set_gun", Globals.get_gun_index_by_name(interactable.Product_ID))
						Globals.player_set_points(player.ID, player.Points - interactable.Price)
				elif interactable.Product_Type == Globals.Product_Types.perk:
					Globals.add_perk_to_player(player.ID, interactable.Product_ID)
					Globals.player_set_points(player.ID, player.Points - interactable.Price)
				elif interactable.Product_Type == Globals.Product_Types.barrier:
					interactable.interact(self)
					Globals.player_set_points(player.ID, player.Points - interactable.Price)
		elif interactable.is_in_group(Globals.GROUP_PLAYERS):
			if not interactable.get_node("Destroyable").is_dead:
				interactable.get_node("Destroyable").rpc("Start_Reviving")

func _connect_weapon_signals():
	if weapon != null:
		weapon.connect("on_hit", self, "_on_hit")
		weapon.connect("on_kill", self, "_on_kill")

func _on_hit(spatial_hit, spatial_from):
	if spatial_hit.is_in_group(Globals.GROUP_ENEMIES):
		Globals.player_set_points(player.ID, player.Points+10)

func _on_kill(spatial_hit, spatial_from):
	if spatial_hit.is_in_group(Globals.GROUP_ENEMIES):
		Globals.player_set_points(player.ID, player.Points + 100)

func _update_grenade_display():
	for i in range(0,_node_grenade_display.get_child_count()):
		if grenades > i:
			_node_grenade_display.get_child(i).show()
		else:
			_node_grenade_display.get_child(i).hide()

remotesync func _set_grenade_count(new_val: int):
	grenades = new_val
	_update_grenade_display()


func spawn_grenade():
	if grenades > 0:
		rpc("_set_grenade_count", grenades - 1)
		var _name = Globals.get_unique_name(Globals.node_spawnedin, player.ID+"_grenade_")
		rpc("_spawn_grenade_2", velocity, _name)


remotesync func _spawn_grenade_2(_body_vel: Vector3, _name: String):
	var id = max(get_tree().get_rpc_sender_id(),1)
	var g = _spawn_grenade_helper(id, _name)
	
	#TODO: Need to fix adding the player's velocity to grenade
	# Right now, moving backwards, overrides the grenades backward momentum
	# and i'm sure that all other velocities, incorrectly effects the grenade too 
	g.apply_central_impulse(_body_vel*g.mass) # Add player velocity to the grenade
	g.apply_central_impulse(g.transform.basis.x * 7) # Throw the grenade
	
	if Networking.is_server():
		g.trigger(id)


func _spawn_grenade_helper(id:int, _name: String):
	var g: RigidBody = Globals.pl_grenade.duplicate()
	g.name = _name
	g.set_network_master(id)
	Globals.node_spawnedin_synced.add_child(g)
	g.global_transform = _node_weapon_location.global_transform
	g.translate_object_local(Vector3(0,-0.2,-0.2))
	g.rotate_object_local(Vector3(0,0,1), deg2rad(20))
	return g


remotesync func new_round():
	var n = grenades
	if n < max_grenades:
		n += grenades_per_round
		if n > max_grenades:
			n = max_grenades
	if n != grenades:
		rpc("_set_grenade_count", n)

remotesync func _horror_flashlight_effects(r:int):
	if r > 70: # Flash on and off quickly
		_node_flashlight.visible = false
		yield(get_tree().create_timer(0.3),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = true
		yield(get_tree().create_timer(0.3),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = false
		yield(get_tree().create_timer(0.3),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = true
		_reset_flashlight()
	elif r > 40: # Flash on and off, then turn off for a bit
		_node_flashlight.visible = false
		yield(get_tree().create_timer(0.1),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = true
		_node_flashlight.light_energy = 0.5
		yield(get_tree().create_timer(0.1),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = false
		yield(get_tree().create_timer(1),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = true
		_node_flashlight.light_energy = 0.4
		yield(get_tree().create_timer(0.1),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = false
		yield(get_tree().create_timer(0.1),"timeout")
		if flashlight_cancel_horror: return
		
		_node_flashlight.visible = true
		_reset_flashlight()
		
	elif r > 20: # Worsen the projected lighting
		_node_flashlight.spot_angle_attenuation = 0.06
		yield(get_tree().create_timer(2),"timeout")
		if flashlight_cancel_horror: return
		_reset_flashlight()
		
	elif r > 10: # Worsen the projected lighting, another way
		_node_flashlight.light_energy = .3
		yield(get_tree().create_timer(2),"timeout")
		if flashlight_cancel_horror: return
		_reset_flashlight()
		
	elif r > 5: # Emit Horror, light absorbing anti-light
		_node_flashlight.light_negative = true
		_node_flashlight.spot_range = 250
		yield(get_tree().create_timer(2),"timeout")
		if flashlight_cancel_horror: return
		_reset_flashlight()
		
	elif r > 0: # Emit Redish Light
		_node_flashlight.light_color = flashlight_color_redish
		yield(get_tree().create_timer(2),"timeout")
		if flashlight_cancel_horror: return
		_reset_flashlight()
	
	if _node_flashlight.is_network_master():
		if flashlight_cancel_horror or not $horror_flashlight_timer.is_stopped(): return
		$horror_flashlight_timer.wait_time = randi() % 5  + 5
		$horror_flashlight_timer.start()

func _on_horror_flashlight_timer_timeout():
	rpc("_horror_flashlight_effects", randi() % 100)
	
	
